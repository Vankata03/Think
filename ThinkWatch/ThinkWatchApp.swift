//
//  ThinkWatchApp.swift
//  ThinkWatchApp
//

import SwiftUI
import WidgetKit

@main
struct ThinkWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var progress: ProgressStore
    @State private var timer: PomodoroTimer
    @State private var syncCoordinator: SyncCoordinator

    init() {
        let defaults = SharedDefaults.appGroup()
        let progress = ProgressStore(defaults: defaults)
        let timer = PomodoroTimer(
            systemSideEffectsEnabled: false,
            defaults: defaults,
            deviceID: SharedDefaults.syncDeviceID(in: defaults)
        )
        let coordinator = SyncCoordinator(
            role: .watch,
            timer: timer,
            progress: progress,
            ledger: FocusEventLedger(defaults: defaults),
            transport: WCSessionTransport(),
            reloadComplication: { WidgetCenter.shared.reloadAllTimelines() }
        )
        _progress = State(initialValue: progress)
        _timer = State(initialValue: timer)
        _syncCoordinator = State(initialValue: coordinator)
        coordinator.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(progress)
                .environment(timer)
                .environment(syncCoordinator)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                timer.resync()
            }
        }
    }
}
