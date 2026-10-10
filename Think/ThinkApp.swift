//
//  ThinkApp.swift
//  Think
//
//  Created by Ivan Terziev on 7/4/26.
//

import SwiftUI
import SwiftData
import Foundation
import AppIntents
import WidgetKit

nonisolated enum SevenDayReviewPromptPolicy {
    static let storageKey = "hasRequestedReviewAfterSevenDayStreak"

    static func shouldRequest(
        previouslyEarned: Bool,
        isEarned: Bool,
        hasRequested: Bool,
        isEnabled: Bool
    ) -> Bool {
        isEnabled && !previouslyEarned && isEarned && !hasRequested
    }
}

@main
struct ThinkApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var progress: ProgressStore
    @State private var timer: PomodoroTimer
    @State private var syncCoordinator: SyncCoordinator
    @State private var mindfulMinutes: MindfulMinutesStore
    @State private var cloudBackup: CloudBackupState
    @State private var journalLock: JournalLock
    @State private var favorites: FavoritesStore
    @State private var journalRepository: JournalRepository
    @State private var journalDrafts: JournalDraftStore
    @State private var dataReset: AppDataResetCoordinator
    @State private var practicePreferences: PracticePreferencesStore
    @State private var privacyShield = AppPrivacyShield()
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.defaultChoice
    @AppStorage(Onboarding.completedKey) private var completedOnboarding = false
    private let isUITesting: Bool
    private let journalContainer: ModelContainer

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        self.isUITesting = isUITesting
        Self.prepareApplicationSupportDirectory()
        let journalStore = Self.makeJournalStore(isUITesting: isUITesting)
        journalContainer = journalStore.container
        _cloudBackup = State(initialValue: CloudBackupState(storage: journalStore.storage))
        let appGroupDefaults = SharedDefaults.appGroup()
        if isUITesting, let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
            appGroupDefaults.removeObject(forKey: SharedDefaults.pomodoroTimerStateKey)
        }
        Appearance.seedDefault(in: .standard)
        let arguments = ProcessInfo.processInfo.arguments
        if isUITesting && arguments.contains("-ui-journal-locked") {
            UserDefaults.standard.set(true, forKey: JournalLock.enabledKey)
        }
        let authenticator: any JournalAuthenticator
        if isUITesting {
            if arguments.contains("-ui-auth-fail-once") {
                authenticator = UITestJournalAuthenticator(succeeds: true, failuresFirst: 1)
            } else if arguments.contains("-ui-auth-success") || arguments.contains("-ui-auth-failure") {
                authenticator = UITestJournalAuthenticator(succeeds: arguments.contains("-ui-auth-success"))
            } else {
                authenticator = UnavailableJournalAuthenticator()
            }
        } else {
            authenticator = DeviceOwnerJournalAuthenticator()
        }
        let journalLock = JournalLock(authenticator: authenticator)
        _journalLock = State(initialValue: journalLock)
        var draftDirectory = isUITesting
            ? FileManager.default.temporaryDirectory.appending(path: "ThinkUITestDrafts", directoryHint: .isDirectory)
            : nil
        if isUITesting && arguments.contains("-ui-fail-drafts") {
            let blocked = FileManager.default.temporaryDirectory.appendingPathComponent("ThinkUITestBlockedDrafts")
            try? FileManager.default.removeItem(at: blocked)
            try? Data().write(to: blocked)
            draftDirectory = blocked
        }
        let drafts = JournalDraftStore(directory: draftDirectory)
        if isUITesting && !arguments.contains("-ui-preserve-drafts") && !arguments.contains("-ui-fail-drafts") { try? drafts.deleteAll() }
        let repository = JournalRepository(modelContext: journalStore.container.mainContext, storage: journalStore.storage,
            commitInterceptor: {
                if isUITesting && arguments.contains("-ui-fail-save") { throw UITestJournalFailure.save }
            })
        _journalDrafts = State(initialValue: drafts)
        _journalRepository = State(initialValue: repository)
        var seededAnswerID: UUID?
        if isUITesting && arguments.contains("-ui-seed-journal") {
            seededAnswerID = try? repository.saveAnswer(text: "PRIVATE AUDIT ANSWER", practiceID: ContentLibrary.dailyPractice().id, prompt: "PRIVATE AUDIT PROMPT").recordID
            _ = try? repository.saveRetro(wentWell: "PRIVATE AUDIT RETRO", improve: "PRIVATE AUDIT IMPROVE", tomorrow: "PRIVATE AUDIT TOMORROW")
        }
        if isUITesting && arguments.contains("-ui-seed-answer") {
            // Today's answer alone, so Today opens on the move.
            _ = try? repository.saveAnswer(text: "PRIVATE AUDIT ANSWER", practiceID: ContentLibrary.dailyPractice().id, prompt: "PRIVATE AUDIT PROMPT")
        }
        if isUITesting && arguments.contains("-ui-seed-journal-scroll") {
            // Enough entries to require scrolling even on the largest CI phone.
            for index in 0..<12 {
                _ = try? repository.saveNote(text: "SCROLL AUDIT NOTE \(index)")
            }
        }
        if isUITesting && arguments.contains("-ui-seed-journal-list") {
            // Every row shape of the Journal list (`design/journal.md`
            // section 4): each kind, moods, themes, a second version of
            // today's answer and an unsaved draft.
            let now = Date.now
            let today = CivilDay.today()
            _ = try? repository.saveAnswer(text: "Probably nothing different, which is the honest answer.",
                                           practiceID: ContentLibrary.dailyPractice().id, prompt: "PRIVATE AUDIT PROMPT",
                                           mood: .flat, date: today.start.addingTimeInterval(60))
            _ = try? repository.saveNote(text: "Lunch with Maya. She said the thing about owning the calendar again.",
                                         mood: .steady, themes: ThemeSelection(primary: .people), date: now.addingTimeInterval(-60))
            let yesterday = today.previous
            _ = try? repository.saveRetro(wentWell: "Shipped the draft before dinner.", improve: "Started late; the morning went to email.",
                                          tomorrow: "Block 9 to 11 before opening anything.", mood: .good,
                                          themes: ThemeSelection(primary: .work, secondary: .making), day: yesterday,
                                          date: yesterday.start.addingTimeInterval(21 * 3_600))
            let twoDaysAgo = today.adding(days: -2)
            _ = try? repository.saveFocusNote(text: "Got the opening scene down; the middle still drags.", intention: "Write chapter 3",
                                              sessionID: "audit-list-session", completedAt: twoDaysAgo.start.addingTimeInterval(14 * 3_600),
                                              themes: ThemeSelection(primary: .making))
            _ = try? repository.saveWeeklyReview(text: "Five of seven days. Plan the practice before the trip.",
                                                 nextIntention: "Pack the practice.", weekStart: today.adding(days: -6).start)
            var draft = JournalDraft(kind: .note)
            draft.text = "Half a thought about the weekend"
            try? drafts.save(draft)
        }
        let progressDefaults: UserDefaults
        if isUITesting, let bundleIdentifier = Bundle.main.bundleIdentifier {
            let suiteName = "\(bundleIdentifier).ui-tests"
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            defaults.removePersistentDomain(forName: suiteName)
            progressDefaults = defaults
        } else {
            progressDefaults = appGroupDefaults
        }
        let progressStore = ProgressStore(defaults: progressDefaults)
        if isUITesting && arguments.contains("-ui-seed-ledger"), let seededAnswerID {
            // What the editor records on save, so a locked Today knows the
            // seeded answer exists without reading it.
            progressStore.recordActivity(.answer, id: seededAnswerID.uuidString)
        }
        if isUITesting && arguments.contains("-ui-seed-focus") {
            let sessionID = "audit-focus-session"
            progressStore.recordFocusSession(durationMinutes: 25, eventID: sessionID, actualActiveSeconds: 1500)
            let receipt = try? repository.saveFocusNote(text: "Original focus note", intention: "Audit intention", sessionID: sessionID)
            try? repository.upsertSessionMetadata(sessionID: sessionID, intention: "Audit intention", closingNoteRecordID: receipt?.recordID, completedAt: .now)
        }
        if isUITesting && arguments.contains("-ui-seed-progress") {
            // Every Progress section populated: a 7-day streak and ten
            // sessions (two medals), a path step, partial effort, and an
            // intention on the newest completed session.
            let now = Date.now
            for day in 0..<7 {
                let date = Calendar.current.date(byAdding: .day, value: -day, to: now) ?? now
                progressStore.recordFocusSession(
                    at: date.addingTimeInterval(-60), durationMinutes: 25, eventID: "audit-progress-day-\(day)",
                    actualActiveSeconds: 1_500)
            }
            for index in 0..<3 {
                progressStore.recordFocusSession(
                    at: now.addingTimeInterval(Double(-3_600 * (index + 2))), durationMinutes: 50,
                    eventID: "audit-progress-extra-\(index)", actualActiveSeconds: nil)
            }
            progressStore.recordPartialFocusSession(FocusSessionRecord(
                id: "audit-progress-partial", completedAt: now.addingTimeInterval(-30), durationMinutes: 25,
                actualActiveSeconds: 420, isCompleted: false))
            _ = progressStore.completePathStep(
                pathID: PathLibrary.deepFocus.id, totalSteps: PathLibrary.deepFocus.steps.count, at: now)
            try? repository.upsertSessionMetadata(
                sessionID: "audit-progress-day-0", intention: "Draft the Progress audit", completedAt: now)
        }
        // Same isolated suite as progress under UI tests, so a favorited
        // line never leaks between runs.
        let favorites = FavoritesStore(defaults: progressDefaults)
        _favorites = State(initialValue: favorites)
        let practicePreferences = PracticePreferencesStore(defaults: progressDefaults)
        _practicePreferences = State(initialValue: practicePreferences)
        let timer = PomodoroTimer(
            systemSideEffectsEnabled: !isUITesting,
            defaults: isUITesting ? nil : appGroupDefaults,
            deviceID: isUITesting ? UUID() : SharedDefaults.syncDeviceID(in: appGroupDefaults)
        )
        let ledgerDefaults = isUITesting ? progressDefaults : appGroupDefaults
        let ledger = FocusEventLedger(defaults: ledgerDefaults)
        let mindfulHealthClient: any MindfulHealthClient = isUITesting
            ? UnavailableMindfulHealthClient()
            : HealthKitMindfulHealthClient()
        let mindfulMinutes = MindfulMinutesStore(
            defaults: UserDefaults.standard,
            client: mindfulHealthClient
        )
        let transport: any SyncTransport
        if isUITesting {
            transport = NoopSyncTransport()
        } else {
            transport = WCSessionTransport()
        }
        let completionSideEffect: @MainActor @Sendable () -> Void
        if isUITesting {
            completionSideEffect = { @MainActor @Sendable in }
        } else {
            completionSideEffect = { @MainActor @Sendable in
                Haptics.live.play(.success)
            }
        }
        let coordinator = SyncCoordinator(
            role: .phone,
            timer: timer,
            progress: progressStore,
            ledger: ledger,
            transport: transport,
            progressMutationSideEffect: {
                WidgetCenter.shared.reloadTimelines(ofKind: StreakPresentation.widgetKind)
            },
            completionSideEffect: completionSideEffect,
            focusSessionSideEffect: { endDate, durationMinutes in
                mindfulMinutes.enqueueCompletedSession(
                    endedAt: endDate,
                    durationMinutes: durationMinutes
                )
                Task {
                    await mindfulMinutes.drainPendingSessions()
                }
            }
        )
        _progress = State(initialValue: progressStore)
        _timer = State(initialValue: timer)
        _syncCoordinator = State(initialValue: coordinator)
        _mindfulMinutes = State(initialValue: mindfulMinutes)
        _dataReset = State(initialValue: AppDataResetCoordinator(
            journal: repository, drafts: drafts, sync: coordinator,
            mindfulMinutes: mindfulMinutes, favorites: favorites, lock: journalLock,
            preferences: practicePreferences
        ))
        let appIntentRouter = AppIntentRouter.shared
        AppDependencyManager.shared.add(dependency: FocusSessionIntentHandler(timer: timer))
        AppDependencyManager.shared.add(dependency: appIntentRouter)
        coordinator.activate()
        Task {
            await mindfulMinutes.drainPendingSessions()
        }
    }

    /// Opens the journal store. When every on-disk candidate fails the app
    /// still launches, on a throwaway store — but as
    /// `.emergencyInMemory`, so the Settings iCloud row states outright that the
    /// session is not being saved rather than letting the user write into
    /// a store that disappears on quit.
    private static func makeJournalStore(isUITesting: Bool) -> JournalDataStore.Result {
        do {
            return try JournalDataStore.makeContainer(isUITesting: isUITesting)
        } catch {
            let onDiskError = error
            do {
                let container = try ModelContainer(
                    for: JournalDataStore.schema,
                    configurations: JournalDataStore.configuration(for: .emergencyInMemory)
                )
                return JournalDataStore.Result(container: container, storage: .emergencyInMemory)
            } catch {
                fatalError(
                    """
                    Unable to open the journal store.
                    On-disk: \(onDiskError)
                    In-memory: \(error)
                    """
                )
            }
        }
    }

    private static func prepareApplicationSupportDirectory() {
        guard let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return
        }

        try? FileManager.default.createDirectory(
            at: applicationSupportURL,
            withIntermediateDirectories: true
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isUITesting || completedOnboarding {
                    RootTabView()
                } else {
                    OnboardingView()
                }
            }
            .id(dataReset.generation)
            .environment(progress)
            .environment(timer)
            .environment(syncCoordinator)
            .environment(AppIntentRouter.shared)
            .environment(mindfulMinutes)
            .environment(cloudBackup)
            .environment(journalLock)
            .environment(favorites)
            .environment(journalRepository)
            .environment(journalDrafts)
            .environment(dataReset)
            .environment(practicePreferences)
            .environment(\.haptics, .live)
            .task {
                try? journalRepository.ensureRecordIdentities()
                cloudBackup.startObservingMirroringEvents()
                await cloudBackup.refresh()
            }
            .modifier(AchievementUnlockModifier(progress: progress, isEnabled: !isUITesting))
            .preferredColorScheme(appearance.colorScheme)
            .animation(.easeInOut(duration: 0.3), value: completedOnboarding)
            .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
                DailyQuoteNotifier.refreshSchedule()
                RetroReminder.refreshSchedule()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                DailyQuoteNotifier.refreshSchedule()
                RetroReminder.refreshSchedule()
            }
        }
        .modelContainer(journalContainer)
        .onChange(of: scenePhase) { _, phase in
            // Owned by the app, not by JournalView: the lock has to keep
            // its grace period while the journal is off screen.
            journalLock.scenePhaseChanged(to: phase)
            // UI tests cannot wait out the relock grace period.
            if isUITesting && phase == .background && ProcessInfo.processInfo.arguments.contains("-ui-relock-on-background") {
                journalLock.lock()
            }
            privacyShield.scenePhaseChanged(to: phase)
            if phase == .active {
                timer.resync()
                progress.recordAppOpen()
                // Slide the scheduled notification window forward.
                DailyQuoteNotifier.refreshSchedule()
                Task {
                    await mindfulMinutes.drainPendingSessions()
                }
                Task {
                    // The account can change while the app sits in the
                    // background.
                    await cloudBackup.refresh()
                }
            }
        }
    }
}

@MainActor
private final class UITestJournalAuthenticator: JournalAuthenticator {
    let availability = JournalLockAvailability.passcodeOnly
    let succeeds: Bool
    /// Attempts that fail before `succeeds` applies, to exercise retry.
    private var failuresFirst: Int
    init(succeeds: Bool, failuresFirst: Int = 0) { self.succeeds = succeeds; self.failuresFirst = failuresFirst }
    func authenticate(reason: String) async -> Bool {
        guard failuresFirst == 0 else { failuresFirst -= 1; return false }
        return succeeds
    }
}

private enum UITestJournalFailure: Error { case save }
