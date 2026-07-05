//
//  ThinkWatchApp.swift
//  ThinkWatchApp
//

import SwiftUI

@main
struct ThinkWatchApp: App {
    @State private var progress = ProgressStore(defaults: SharedDefaults.appGroup())

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(progress)
        }
    }
}
