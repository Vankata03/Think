//
//  RootTabView.swift
//  Think
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var prototypeTab = 4

    var body: some View {
        // Throwaway Progress prototype: native five-tab chrome, open on Progress.
        TabView(selection: $prototypeTab) {
            Tab("Today", systemImage: "sun.max", value: 0) {
                TodayView()
            }
            .accessibilityIdentifier("Tab.Today")
            Tab("Paths", systemImage: "point.topleft.down.to.point.bottomright.curvepath", value: 1) {
                PathsView()
            }
            .accessibilityIdentifier("Tab.Paths")
            Tab("Focus", systemImage: "timer", value: 2) {
                FocusView()
            }
            .accessibilityIdentifier("Tab.Focus")
            Tab("Journal", systemImage: "book.closed", value: 3) {
                JournalView()
            }
            .accessibilityIdentifier("Tab.Journal")
            Tab("Progress", systemImage: "chart.bar", value: 4) {
                ProgressPrototypeView()
            }
            .accessibilityIdentifier("Tab.Progress")
        }
        .tint(colorScheme == .dark
              ? Color(red: 1, green: 212.0 / 255, blue: 51.0 / 255)
              : Color(red: 110.0 / 255, green: 92.0 / 255, blue: 5.0 / 255))
    }
}

#Preview {
    RootTabView()
        .environment(ProgressStore())
        .environment(PomodoroTimer())
        .environment(AppIntentRouter.shared)
        .modelContainer(for: [JournalEntry.self, DailyRetro.self], inMemory: true)
}
