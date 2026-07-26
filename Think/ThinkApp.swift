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
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.dark
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
        // UI tests must never reach LocalAuthentication: a system
        // authentication sheet is outside the app's element tree.
        _journalLock = State(
            initialValue: JournalLock(
                authenticator: isUITesting
                    ? UnavailableJournalAuthenticator()
                    : DeviceOwnerJournalAuthenticator()
            )
        )
        let appGroupDefaults = SharedDefaults.appGroup()
        if isUITesting, let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
            appGroupDefaults.removeObject(forKey: SharedDefaults.pomodoroTimerStateKey)
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
        // Same isolated suite as progress under UI tests, so a favorited
        // line never leaks between runs.
        _favorites = State(initialValue: FavoritesStore(defaults: progressDefaults))
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
    /// `.emergencyInMemory`, so the Profile row states outright that the
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
            .environment(progress)
            .environment(timer)
            .environment(syncCoordinator)
            .environment(AppIntentRouter.shared)
            .environment(mindfulMinutes)
            .environment(cloudBackup)
            .environment(journalLock)
            .environment(favorites)
            .environment(\.haptics, .live)
            .task {
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
