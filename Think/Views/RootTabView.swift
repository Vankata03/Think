//
//  RootTabView.swift
//  Think
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max") {
                TodayView()
            }
            .accessibilityIdentifier("Tab.Today")
            Tab("Paths", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                PathsView()
            }
            .accessibilityIdentifier("Tab.Paths")
            Tab("Focus", systemImage: "timer") {
                FocusView()
            }
            .accessibilityIdentifier("Tab.Focus")
            Tab("Profile", systemImage: "person") {
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
        .modelContainer(for: [JournalEntry.self, DailyRetro.self], inMemory: true)
}
