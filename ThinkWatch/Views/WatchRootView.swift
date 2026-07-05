//
//  WatchRootView.swift
//  ThinkWatchApp
//

import SwiftUI

struct WatchRootView: View {
    var body: some View {
        TabView {
            Text("Today")
                .tag(0)
            Text("Focus")
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
    }
}

#Preview {
    WatchRootView()
        .environment(ProgressStore(defaults: .standard))
}
