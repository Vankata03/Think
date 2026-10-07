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
    @Environment(PomodoroTimer.self) private var timer

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
                FocusStageView()
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
        .modifier(FocusSessionAccessorySlot(
            isEnabled: !timer.isIdle && appIntentRouter.selectedTab != .focus
        ))
    }
}

/// The tab bar's one accessory: a session running or paused while another
/// tab is selected (design-system 13.2, focus.md section 6). Hiding an
/// accessory needs iOS 26.1; on 26.0 there is none, and the Live Activity
/// carries the session.
private struct FocusSessionAccessorySlot: ViewModifier {
    var isEnabled: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: isEnabled) {
                FocusSessionAccessory()
            }
        } else {
            content
        }
    }
}

#Preview {
    RootTabView()
        .environment(ProgressStore())
        .environment(PomodoroTimer())
        .environment(AppIntentRouter.shared)
        .modelContainer(for: [JournalEntry.self, DailyRetro.self], inMemory: true)
}
