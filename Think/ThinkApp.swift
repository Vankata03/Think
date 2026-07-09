//
//  ThinkApp.swift
//  Think
//
//  Created by Ivan Terziev on 7/4/26.
//

import SwiftUI
import SwiftData
import Foundation

@main
struct ThinkApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var progress: ProgressStore
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.dark
    @AppStorage(Onboarding.completedKey) private var completedOnboarding = false
    private let isUITesting: Bool

    init() {
        isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        Self.prepareApplicationSupportDirectory()
        if isUITesting, let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }
        let progressDefaults: UserDefaults
        if isUITesting, let bundleIdentifier = Bundle.main.bundleIdentifier {
            let suiteName = "\(bundleIdentifier).ui-tests"
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            defaults.removePersistentDomain(forName: suiteName)
            progressDefaults = defaults
        } else {
            progressDefaults = SharedDefaults.appGroup()
        }
        _progress = State(initialValue: ProgressStore(defaults: progressDefaults))
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
            .environment(\.haptics, .live)
            .preferredColorScheme(appearance.colorScheme)
            .animation(.easeInOut(duration: 0.3), value: completedOnboarding)
        }
        .modelContainer(for: [JournalEntry.self, DailyRetro.self], inMemory: isUITesting)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                progress.recordAppOpen()
                // Slide the scheduled notification window forward.
                DailyQuoteNotifier.refreshSchedule()
            }
        }
    }
}
