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

private struct SevenDayReviewPromptModifier: ViewModifier {
    let progress: ProgressStore
    let isEnabled: Bool

    @AppStorage(SevenDayReviewPromptPolicy.storageKey) private var hasRequested = false

    func body(content: Content) -> some View {
        content
            .onChange(of: progress.hasEarned(.seven)) { previouslyEarned, isEarned in
                guard SevenDayReviewPromptPolicy.shouldRequest(
                    previouslyEarned: previouslyEarned,
                    isEarned: isEarned,
                    hasRequested: hasRequested,
                    isEnabled: isEnabled
                ) else { return }

                hasRequested = true
                Task {
                    do {
                        try await Task.sleep(for: .seconds(2))
                    } catch {
                        return
                    }
                    await AppReviewRequester.request()
                }
            }
    }
}

@main
struct ThinkApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var progress: ProgressStore
    @State private var timer: PomodoroTimer
    @State private var syncCoordinator: SyncCoordinator
    @State private var mindfulMinutes: MindfulMinutesStore
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.dark
    @AppStorage(Onboarding.completedKey) private var completedOnboarding = false
    private let isUITesting: Bool

    init() {
        isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        Self.prepareApplicationSupportDirectory()
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
            .environment(\.haptics, .live)
            .modifier(SevenDayReviewPromptModifier(progress: progress, isEnabled: !isUITesting))
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
        .modelContainer(for: [JournalEntry.self, DailyRetro.self], inMemory: isUITesting)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                timer.resync()
                progress.recordAppOpen()
                // Slide the scheduled notification window forward.
                DailyQuoteNotifier.refreshSchedule()
                Task {
                    await mindfulMinutes.drainPendingSessions()
                }
            }
        }
    }
}
