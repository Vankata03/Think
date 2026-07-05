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
            Tab("Paths", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                PathsView()
            }
            Tab("Focus", systemImage: "timer") {
                FocusView()
            }
            Tab("Profile", systemImage: "person") {
                ProfileView()
            }
        }
        .tint(.accentColor)
    }
}

#Preview {
    RootTabView()
        .environment(ProgressStore())
        .modelContainer(for: [JournalEntry.self, DailyRetro.self], inMemory: true)
}
