//
//  RootTabView.swift
//  Think
//

import SwiftData
import SwiftUI

/// The five tabs of design-system section 13.8.
struct RootTabView: View {
    @Environment(AppIntentRouter.self) private var appIntentRouter

    var body: some View {
        @Bindable var appIntentRouter = appIntentRouter

        TabView(selection: $appIntentRouter.selectedTab) {
            Tab("Today", systemImage: ThinkSymbol.today, value: ThinkAppTab.today) {
                TodayView()
            }
            .accessibilityIdentifier("Tab.Today")
            Tab("Paths", systemImage: ThinkSymbol.path, value: ThinkAppTab.paths) {
                PathsView()
            }
            .accessibilityIdentifier("Tab.Paths")
            Tab("Focus", systemImage: ThinkSymbol.focus, value: ThinkAppTab.focus) {
                FocusView()
            }
            .accessibilityIdentifier("Tab.Focus")
            Tab("Journal", systemImage: ThinkSymbol.journal, value: ThinkAppTab.journal) {
                NavigationStack {
                    JournalView()
                }
            }
            .accessibilityIdentifier("Tab.Journal")
            Tab("Progress", systemImage: ThinkSymbol.progress, value: ThinkAppTab.progress) {
                ProgressTabView()
            }
            .accessibilityIdentifier("Tab.Progress")
        }
        .tint(ThinkColor.accentInk)
    }
}

#Preview {
    RootTabView()
        .environment(ProgressStore())
        .environment(PomodoroTimer())
        .environment(AppIntentRouter.shared)
        .modelContainer(for: [JournalEntry.self, DailyRetro.self], inMemory: true)
}
