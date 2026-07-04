//
//  ThinkApp.swift
//  Think
//
//  Created by Ivan Terziev on 7/4/26.
//

import SwiftUI
import SwiftData

@main
struct ThinkApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var progress: ProgressStore
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system
    private let isUITesting: Bool

    init() {
        isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        if isUITesting, let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }
        _progress = State(initialValue: ProgressStore())
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(progress)
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(for: JournalEntry.self, inMemory: isUITesting)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // Slide the scheduled notification window forward.
                DailyQuoteNotifier.refreshSchedule()
            }
        }
    }
}
