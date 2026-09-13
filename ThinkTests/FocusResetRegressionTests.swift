import Foundation
import Testing
@testable import Think

@MainActor
struct FocusResetRegressionTests {
    private func defaults() -> UserDefaults { UserDefaults(suiteName: "FocusResetTests.\(UUID())")! }

    @Test func pauseRelaunchAndEarlyStopMeasureActiveEffortOnly() {
        let d = defaults()
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let timer = PomodoroTimer(systemSideEffectsEnabled: false, defaults: d, now: { now })
        timer.start()
        let id = timer.currentSessionID
        now += 60
        timer.pause()
        now += 600
        let restored = PomodoroTimer(systemSideEffectsEnabled: false, defaults: d, now: { now })
        #expect(restored.currentSessionID == id)
        restored.start()
        now += 30
        restored.reset()
        #expect(restored.lastSessionRecord?.actualActiveSeconds == 90)
        #expect(restored.lastSessionRecord?.isCompleted == false)
        #expect(restored.lastSessionRecord?.id == id)
        restored.reset()
        #expect(restored.currentSessionID == nil)
    }

    @Test func resetRunningTimerClearsPrivateDataAndRejectsOldEpochAfterRelaunch() throws {
        let d = defaults()
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let timer = PomodoroTimer(systemSideEffectsEnabled: false, defaults: d, now: { now })
        timer.setIntention("Private intention")
        #expect(!timer.showIntentionInLiveActivity)
        timer.start()
        let stale = timer.syncState
        now += 60
        let boundary = SyncResetBoundary(date: now)
        var records: [FocusSessionRecord] = []
        timer.onSessionRecorded = { records.append($0) }
        timer.resetForDataDeletion(boundary: boundary)
        #expect(records.isEmpty)
        #expect(timer.intention == nil)
        #expect(timer.lastIntention == nil)
        #expect(timer.pendingFocusNote == nil)
        let restored = PomodoroTimer(systemSideEffectsEnabled: false, defaults: d, now: { now })
        #expect(!restored.isRunning)
        #expect(!restored.apply(stale))
        var futureStale = stale
        futureStale.resetBoundary = nil
        #expect(!restored.apply(futureStale))
        let wire = String(decoding: try SyncCodec.encode(stale), as: UTF8.self)
        #expect(!wire.contains("Private intention"))
    }

    @Test func resetRejectsLegacyAndDelayedWatchEventsEvenWhenTheyFinishLater() {
        let d = defaults()
        let ledger = FocusEventLedger(defaults: d)
        let boundary = SyncResetBoundary(date: Date(timeIntervalSince1970: 1_800_000_000))
        ledger.installResetBoundary(boundary)
        let future = boundary.date.addingTimeInterval(600)
        #expect(!ledger.accepts(FocusSessionEvent(endDate: future, durationMinutes: 25)))
        #expect(!ledger.accepts(FocusSessionEvent(id: UUID().uuidString, completedAt: future)))
        let fresh = FocusSessionEvent(id: UUID().uuidString, completedAt: future, durationMinutes: 25, resetBoundary: boundary)
        #expect(FocusEventLedger(defaults: d).accepts(fresh))
        #expect(!ledger.accepts(FocusSessionEvent(id: "invalid", completedAt: future, resetBoundary: boundary)))
    }

    @Test func oldStandardDefaultsCannotResurrectDeletedProgress() {
        let standard = defaults(), group = defaults()
        standard.set(100, forKey: "totalFocusSessions")
        SharedDefaults.setResetBoundary(SyncResetBoundary(date: .now), in: group)
        SharedDefaults.migrateProgressIfNeeded(from: standard, to: group)
        #expect(group.object(forKey: "totalFocusSessions") == nil)
    }
}
