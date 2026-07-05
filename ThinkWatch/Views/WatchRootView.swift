//
//  WatchRootView.swift
//  ThinkWatchApp
//

import SwiftUI

struct WatchRootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                WatchTodayView()
            }
            .tag(0)

            NavigationStack {
                WatchFocusView()
            }
            .tag(1)
        }
        .tabViewStyle(.verticalPage)
    }
}

#Preview {
    WatchRootView()
        .environment(ProgressStore(defaults: .standard))
}
