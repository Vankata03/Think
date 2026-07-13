//
//  PomodoroTimerSyncTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

@MainActor
struct PomodoroTimerSyncTests {

    @Test func localSemanticMutationsPublishExactlyOnce() {
        let timer = PomodoroTimer(
            systemSideEffectsEnabled: false,
            deviceID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            now: { Date(timeIntervalSince1970: 1_000) }
        )
        var states: [TimerSyncState] = []
        timer.onStateChange = { states.append($0) }

        timer.select(.long)
        timer.start()
        timer.pause()
        timer.reset()
        timer.skipPhase()

        #expect(states.count == 5)
        #expect(states.map(\.phase) == ["deep work", "deep work", "deep work", "deep work", "break"])
        #expect(states.allSatisfy { $0.revision.deviceID.uuidString == "11111111-1111-1111-1111-111111111111" })
    }

    @Test func tickOnlyResyncDoesNotPublish() {
        var now = Date(timeIntervalSince1970: 1_000)
        let timer = PomodoroTimer(systemSideEffectsEnabled: false, now: { now })
        var states = 0
        timer.onStateChange = { _ in states += 1 }

        timer.start()
        now = now.addingTimeInterval(10)
        timer.resync()

        #expect(states == 1)
        #expect(timer.remainingSeconds <= 25 * 60 - 10)
        timer.reset()
    }

    @Test func workRolloverPublishesOriginalCompletionDateOnce() {
        let now = Date(timeIntervalSince1970: 1_000)
        let timer = PomodoroTimer(systemSideEffectsEnabled: false, now: { now })
        var completionDates: [Date] = []
        var states: [TimerSyncState] = []
        timer.onWorkSessionComplete = { completionDates.append($0) }
        timer.onStateChange = { states.append($0) }

        timer.select(.init(workMinutes: 0, restMinutes: 5))
        timer.start()
        timer.resync()
        timer.resync()

        #expect(completionDates == [now])
        #expect(states.count == 3)
        #expect(states.last?.phase == PomodoroTimer.Phase.rest.rawValue)
        timer.reset()
    }

    @Test func remoteApplyChangesStateWithoutEchoing() {
        let now = Date(timeIntervalSince1970: 2_000)
        let timer = PomodoroTimer(systemSideEffectsEnabled: false, now: { now })
        var states = 0
        timer.onStateChange = { _ in states += 1 }
        let remoteRevision = Revision(
            date: now.addingTimeInterval(10),
            deviceID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        )
        let remote = TimerSyncState(
            workMinutes: 50,
            restMinutes: 10,
            phase: PomodoroTimer.Phase.rest.rawValue,
            isRunning: false,
            endDate: nil,
            remainingSeconds: 600,
            revision: remoteRevision
        )

        #expect(timer.apply(remote))
        #expect(timer.preset == .long)
        #expect(timer.phase == .rest)
        #expect(timer.remainingSeconds == 600)
        #expect(states == 0)
        #expect(!timer.apply(remote))
    }

    @Test func staleRemoteStateIsRejected() {
        let date = Date(timeIntervalSince1970: 3_000)
        let deviceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let timer = PomodoroTimer(systemSideEffectsEnabled: false, deviceID: deviceID, now: { date })
        timer.start()
        let before = timer.syncState
        let stale = TimerSyncState(
            workMinutes: 50,
            restMinutes: 10,
            phase: PomodoroTimer.Phase.rest.rawValue,
            isRunning: false,
            endDate: nil,
            remainingSeconds: 600,
            revision: Revision(date: date.addingTimeInterval(-1), deviceID: deviceID)
        )

        #expect(!timer.apply(stale))
        #expect(timer.syncState == before)
        timer.reset()
    }

    @Test func expiredRemoteWorkStateRecordsCompletionWithoutEcho() {
        let endDate = Date(timeIntervalSince1970: 4_000)
        var completions: [Date] = []
        var states = 0
        let timer = PomodoroTimer(systemSideEffectsEnabled: false, now: { endDate })
        timer.onWorkSessionComplete = { completions.append($0) }
        timer.onStateChange = { _ in states += 1 }
        let remote = TimerSyncState(
            workMinutes: 0,
            restMinutes: 5,
            phase: PomodoroTimer.Phase.work.rawValue,
            isRunning: true,
            endDate: endDate.addingTimeInterval(-1),
            remainingSeconds: 0,
            revision: Revision(
                date: endDate.addingTimeInterval(-2),
                deviceID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
            )
        )

        #expect(timer.apply(remote))
        #expect(completions == [remote.endDate])
        #expect(states == 0)
        #expect(timer.phase == .rest)
        timer.reset()
    }

    @Test func invalidRemoteStateLeavesTimerUntouched() {
        let timer = PomodoroTimer(systemSideEffectsEnabled: false)
        let before = timer.syncState
        let invalid = TimerSyncState(
            workMinutes: -1,
            restMinutes: 5,
            phase: PomodoroTimer.Phase.work.rawValue,
            isRunning: false,
            endDate: nil,
            remainingSeconds: 1,
            revision: Revision(date: .now.addingTimeInterval(10), deviceID: UUID())
        )

        #expect(!timer.apply(invalid))
        #expect(timer.syncState == before)
    }

    @Test func revisionSurvivesTimerReconstruction() {
        let suiteName = "ThinkTests.PomodoroTimerRevision.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let deviceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let now = Date(timeIntervalSince1970: 5_000)

        let first = PomodoroTimer(systemSideEffectsEnabled: false, defaults: defaults, deviceID: deviceID, now: { now })
        first.start()
        let revision = first.currentRevision

        let restored = PomodoroTimer(systemSideEffectsEnabled: false, defaults: defaults, deviceID: deviceID, now: { now })

        #expect(restored.currentRevision == revision)
        #expect(restored.isRunning)
        first.reset()
        restored.reset()
    }
}
