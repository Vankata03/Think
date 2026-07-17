//
//  RootTabView.swift
//  Think
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(AppIntentRouter.self) private var appIntentRouter

    var body: some View {
        @Bindable var appIntentRouter = appIntentRouter

        TabView(selection: $appIntentRouter.selectedTab) {
            Tab("Today", systemImage: "sun.max", value: ThinkAppTab.today) {
                TodayView()
            }
            .accessibilityIdentifier("Tab.Today")
            Tab("Paths", systemImage: "point.topleft.down.to.point.bottomright.curvepath", value: ThinkAppTab.paths) {
                PathsView()
            }
            .accessibilityIdentifier("Tab.Paths")
            Tab("Focus", systemImage: "timer", value: ThinkAppTab.focus) {
                FocusView()
            }
            .accessibilityIdentifier("Tab.Focus")
            Tab("Profile", systemImage: "person", value: ThinkAppTab.profile) {
                ProfileView()
            }
            .accessibilityIdentifier("Tab.Profile")
        }
        .tint(.accentColor)
    }
}

#Preview {
    RootTabView()
        .environment(ProgressStore())
        .environment(PomodoroTimer())
        .environment(AppIntentRouter.shared)
        .modelContainer(for: [JournalEntry.self, DailyRetro.self], inMemory: true)
}
