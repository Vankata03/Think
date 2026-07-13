//
//  RootTabView.swift
//  Think
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(AppIntentRouter.self) private var appIntentRouter
    @Environment(ProgressStore.self) private var progress
    @Environment(\.scenePhase) private var scenePhase
    @State private var milestoneOffer: StreakMilestone?

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
        .onAppear(perform: presentPendingMilestone)
        .onChange(of: progress.pendingStreakMilestone) {
            presentPendingMilestone()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                presentPendingMilestone()
            }
        }
        .sheet(item: $milestoneOffer, onDismiss: presentPendingMilestone) { milestone in
            StreakShareSheet(month: .now, milestone: milestone)
                .onAppear {
                    progress.markStreakMilestoneHandled(milestone)
                }
        }
    }

    private func presentPendingMilestone() {
        guard milestoneOffer == nil else { return }
        milestoneOffer = progress.pendingStreakMilestone
    }
}

#Preview {
    RootTabView()
        .environment(ProgressStore())
        .environment(PomodoroTimer())
        .environment(AppIntentRouter.shared)
        .modelContainer(for: [JournalEntry.self, DailyRetro.self], inMemory: true)
}
