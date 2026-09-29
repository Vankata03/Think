//
//  RootTabView.swift
//  Think
//

import SwiftUI
import SwiftData

/// The five tabs of design-system section 13.8. The Journal tab shows the
/// existing journal until the Journal list build replaces it; the fifth tab
/// keeps Profile until the Progress build renames and replaces it.
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
            Tab("Profile", systemImage: ThinkSymbol.progress, value: ThinkAppTab.profile) {
                ProfileView()
            }
            .accessibilityIdentifier("Tab.Profile")
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
