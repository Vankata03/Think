//
//  RootTabView.swift
//  Think
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppIntentRouter.self) private var appIntentRouter
    @Environment(PomodoroTimer.self) private var timer

    /// PROTOTYPE: the accessory shows while a session is running or paused
    /// and another tab is selected.
    private var showsFocusAccessory: Bool {
        let inSession = timer.isRunning || timer.remainingSeconds != timer.phaseTotalSeconds || timer.phase == .rest
        return inSession && appIntentRouter.selectedTab != .focus
    }

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
                FocusPrototypeView()
            }
            .accessibilityIdentifier("Tab.Focus")
            Tab("Profile", systemImage: "person", value: ThinkAppTab.profile) {
                ProfileView()
            }
            .accessibilityIdentifier("Tab.Profile")
        }
        .tint(Color.accessibleAccent(for: colorScheme))
        .modifier(FocusAccessoryModifier(enabled: showsFocusAccessory))
    }
}

/// PROTOTYPE: `tabViewBottomAccessory(isEnabled:)` is iOS 26.1+; the app
/// targets 26.0, where the accessory cannot be hidden, so 26.0 goes without.
private struct FocusAccessoryModifier: ViewModifier {
    var enabled: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: enabled) { FocusAccessoryPrototype() }
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
