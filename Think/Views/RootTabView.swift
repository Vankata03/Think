//
//  RootTabView.swift
//  Think
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var prototypeTab = 3

    var body: some View {
        // Throwaway Journal prototype (#78): five-tab chrome, open on Journal.
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
                JournalPrototypeView()
            }
            .accessibilityIdentifier("Tab.Journal")
            Tab("Progress", systemImage: "chart.bar", value: 4) {
                ProfileView()
            }
            .accessibilityIdentifier("Tab.Progress")
        }
        .tint(Color.accessibleAccent(for: colorScheme))
    }
}

#Preview {
    RootTabView()
        .environment(ProgressStore())
        .environment(PomodoroTimer())
        .environment(AppIntentRouter.shared)
        .modelContainer(for: [JournalEntry.self, DailyRetro.self], inMemory: true)
}
