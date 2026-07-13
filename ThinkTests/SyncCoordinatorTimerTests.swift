//
//  SyncCoordinatorTimerTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

@MainActor
struct SyncCoordinatorTimerTests {

    @Test func phoneStartAndWatchPauseConvergeThroughMockTransport() {
        let now = Date(timeIntervalSince1970: 10_000)
        let (phoneTransport, watchTransport) = MockSyncTransport.paired()
        let phoneTimer = timer(deviceID: "11111111-1111-1111-1111-111111111111", now: now)
        let watchTimer = timer(deviceID: "22222222-2222-2222-2222-222222222222", now: now)
        let phoneProgress = ProgressStore(defaults: makeDefaults())
        let watchProgress = ProgressStore(defaults: makeDefaults())
        let phone = coordinator(
            role: .phone,
            timer: phoneTimer,
            progress: phoneProgress,
            transport: phoneTransport
        )
        let watch = coordinator(
            role: .watch,
            timer: watchTimer,
            progress: watchProgress,
            transport: watchTransport
        )
        phone.activate()
        watch.activate()

        phoneTimer.start()

        #expect(watchTimer.isRunning)
        #expect(watchTimer.phase == .work)
        #expect(watchTimer.syncState.endDate == phoneTimer.syncState.endDate)

        watchTimer.pause()

        #expect(!phoneTimer.isRunning)
        #expect(!watchTimer.isRunning)
        #expect(phoneTimer.currentRevision == watchTimer.currentRevision)
    }

    @Test func unreachableTimerContextConvergesToLatestStateAfterFlush() {
        let now = Date(timeIntervalSince1970: 11_000)
        let (phoneTransport, watchTransport) = MockSyncTransport.paired()
        let phoneTimer = timer(deviceID: "11111111-1111-1111-1111-111111111111", now: now)
        let watchTimer = timer(deviceID: "22222222-2222-2222-2222-222222222222", now: now)
        let phone = coordinator(
            role: .phone,
            timer: phoneTimer,
            progress: ProgressStore(defaults: makeDefaults()),
            transport: phoneTransport
        )
        let watch = coordinator(
            role: .watch,
            timer: watchTimer,
            progress: ProgressStore(defaults: makeDefaults()),
            transport: watchTransport
        )
        phone.activate()
        watch.activate()

        phoneTransport.setReachable(false)
        phoneTimer.start()
        phoneTimer.pause()
        phoneTimer.start()

        #expect(!watchTimer.isRunning)
        phoneTransport.setReachable(true)

        #expect(watchTimer.isRunning)
        #expect(watchTimer.syncState.endDate == phoneTimer.syncState.endDate)
        #expect(watchTimer.currentRevision == phoneTimer.currentRevision)
    }

    @Test func duplicateMessageAndContextApplyOnlyTheNewRevision() throws {
        let now = Date(timeIntervalSince1970: 12_000)
        let (phoneTransport, watchTransport) = MockSyncTransport.paired()
        let phoneTimer = timer(deviceID: "11111111-1111-1111-1111-111111111111", now: now)
        let watchTimer = timer(deviceID: "22222222-2222-2222-2222-222222222222", now: now)
        let phone = coordinator(
            role: .phone,
            timer: phoneTimer,
            progress: ProgressStore(defaults: makeDefaults()),
            transport: phoneTransport
        )
        let watch = coordinator(
            role: .watch,
            timer: watchTimer,
            progress: ProgressStore(defaults: makeDefaults()),
            transport: watchTransport
        )
        phone.activate()
        watch.activate()
        phoneTimer.start()
        let remoteState = phoneTimer.syncState
        let remoteData = try SyncCodec.encode(remoteState)
        let before = watchTimer.currentRevision

        phoneTransport.sendMessage(SyncTransportPayload(timer: remoteData))
        try phoneTransport.updateApplicationContext(SyncTransportPayload(timer: remoteData))

        #expect(watchTimer.currentRevision == before)
        #expect(watchTimer.currentRevision == remoteState.revision)
    }

    @Test func workRolloverPublishesOneCompletionAcrossBothDevices() {
        var now = Date(timeIntervalSince1970: 13_000)
        let (phoneTransport, watchTransport) = MockSyncTransport.paired()
        let phoneTimer = PomodoroTimer(
            systemSideEffectsEnabled: false,
            deviceID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            now: { now }
        )
        let watchTimer = PomodoroTimer(
            systemSideEffectsEnabled: false,
            deviceID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            now: { now }
        )
        let phoneProgress = ProgressStore(defaults: makeDefaults())
        let watchProgress = ProgressStore(defaults: makeDefaults())
        let phone = coordinator(
            role: .phone,
            timer: phoneTimer,
            progress: phoneProgress,
            transport: phoneTransport
        )
        let watch = coordinator(
            role: .watch,
            timer: watchTimer,
            progress: watchProgress,
            transport: watchTransport
        )
        phone.activate()
        watch.activate()
        let preset = PomodoroTimer.Preset(workMinutes: 0, restMinutes: 5)
        phoneTimer.select(preset)
        phoneTransport.setReachable(false)
        phoneTimer.start()
        watchTimer.start()

        phoneTimer.resync()
        watchTimer.resync()
        now = now.addingTimeInterval(1)
        phoneTransport.setReachable(true)

        #expect(phoneProgress.totalFocusSessions == 1)
        #expect(watchProgress.totalFocusSessions == 1)
        #expect(phoneProgress.totalFocusSessions == watchProgress.totalFocusSessions)
    }

    private func coordinator(
        role: SyncCoordinator.Role,
        timer: PomodoroTimer,
        progress: ProgressStore,
        transport: MockSyncTransport
    ) -> SyncCoordinator {
        SyncCoordinator(
            role: role,
            timer: timer,
            progress: progress,
            ledger: FocusEventLedger(defaults: makeDefaults()),
            transport: transport
        )
    }

    private func timer(deviceID: String, now: Date) -> PomodoroTimer {
        PomodoroTimer(
            systemSideEffectsEnabled: false,
            deviceID: UUID(uuidString: deviceID)!,
            now: { now }
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "ThinkTests.SyncCoordinatorTimer.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
