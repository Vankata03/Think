//
//  FocusStageTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

/// The rules the Focus stage and its bottom accessory show
/// (design/focus.md sections 2, 5 and 6).
@MainActor
struct FocusStageTests {

    // MARK: - End asks first only after a minute of work

    @Test func endDoesNotAskBeforeAMinuteOfWork() {
        let clock = StageClock()
        let timer = makeTimer(clock: clock)

        timer.start()
        clock.now += 59

        #expect(!timer.endAsksFirst)
    }

    @Test func endAsksOnceAMinuteOfWorkIsDone() {
        let clock = StageClock()
        let timer = makeTimer(clock: clock)

        timer.start()
        clock.now += 60

        #expect(timer.endAsksFirst)
    }

    @Test func endStillAsksWhilePausedAfterAMinute() {
        let clock = StageClock()
        let timer = makeTimer(clock: clock)
        timer.start()
        clock.now += 90
        timer.pause()
        clock.now += 600

        #expect(timer.endAsksFirst)
    }

    @Test func timeSpentPausedIsNotWork() {
        let clock = StageClock()
        let timer = makeTimer(clock: clock)
        timer.start()
        clock.now += 30
        timer.pause()
        clock.now += 600

        #expect(!timer.endAsksFirst)

        timer.start()
        clock.now += 30

        #expect(timer.endAsksFirst)
    }

    @Test func endingKeepsTheWorkDoneAsPartialEffort() {
        let clock = StageClock()
        let timer = makeTimer(clock: clock)
        timer.start()
        clock.now += 120

        timer.reset()

        #expect(timer.isIdle)
        #expect(timer.lastSessionRecord?.isCompleted == false)
        #expect(timer.lastSessionRecord?.actualActiveSeconds == 120)
    }

    // MARK: - The done line during a break

    @Test func aBreakAfterFinishedWorkShowsTheSessionDone() {
        let clock = StageClock()
        let timer = makeTimer(clock: clock)
        timer.select(.custom(workMinutes: 30, restMinutes: 5))
        timer.start()
        clock.now += 30 * 60 + 1
        timer.resync()

        #expect(timer.phase == .rest)
        #expect(timer.sessionDoneMinutes == 30)
    }

    @Test func aBreakReachedBySkippingWorkShowsNoDoneLine() {
        let clock = StageClock()
        let timer = makeTimer(clock: clock)
        timer.start()
        clock.now += 120
        timer.skipPhase()

        #expect(timer.phase == .rest)
        #expect(timer.sessionDoneMinutes == nil)
    }

    @Test func workShowsNoDoneLine() {
        let clock = StageClock()
        let timer = makeTimer(clock: clock)
        timer.start()
        clock.now += 25 * 60 + 1
        timer.resync()
        timer.skipPhase()

        #expect(timer.phase == .work)
        #expect(timer.sessionDoneMinutes == nil)
    }

    // MARK: - The accessory's one line

    @Test func duringABreakTheLineReadsBreak() {
        #expect(FocusSessionLine.text(phase: .rest, intention: "Write the brief", journalLocked: false) == "Break")
        #expect(FocusSessionLine.text(phase: .rest, intention: nil, journalLocked: true) == "Break")
    }

    @Test func duringWorkTheLineIsTheIntentionWhileUnlocked() {
        #expect(FocusSessionLine.text(phase: .work, intention: "Write the brief", journalLocked: false) == "Write the brief")
    }

    @Test func duringWorkTheLineNeverShowsTheIntentionWhileLocked() {
        #expect(FocusSessionLine.text(phase: .work, intention: "Write the brief", journalLocked: true) == "Deep work")
    }

    @Test func withoutAnIntentionTheLineReadsDeepWork() {
        #expect(FocusSessionLine.text(phase: .work, intention: nil, journalLocked: false) == "Deep work")
    }

    @Test func theAccessibilityLabelFollowsTheSameLockCheck() {
        let locked = FocusSessionLine.accessibilityLabel(
            phase: .work, intention: "Write the brief", journalLocked: true, countdown: "12:30", isPaused: false)
        let unlocked = FocusSessionLine.accessibilityLabel(
            phase: .work, intention: "Write the brief", journalLocked: false, countdown: "12:30", isPaused: false)

        #expect(!locked.contains("Write the brief"))
        #expect(locked.contains("Deep work"))
        #expect(locked.contains("12:30"))
        #expect(unlocked.contains("Write the brief"))
    }

    @Test func theAccessibilityLabelSaysWhenTheSessionIsPaused() {
        let label = FocusSessionLine.accessibilityLabel(
            phase: .work, intention: nil, journalLocked: false, countdown: "12:30", isPaused: true)

        #expect(label.contains("Paused"))
    }

    // MARK: - Last session

    @Test func aCompletedSessionShowsItsLength() {
        let record = FocusSessionRecord(id: "a", completedAt: .now, durationMinutes: 25, actualActiveSeconds: 1500)
        #expect(record.lastSessionMinutes == 25)
    }

    @Test func anEndedSessionShowsTheWorkDone() {
        let record = FocusSessionRecord(id: "a", completedAt: .now, durationMinutes: 25,
                                        actualActiveSeconds: 7 * 60 + 40, isCompleted: false)
        #expect(record.lastSessionMinutes == 7)
    }

    @Test func anEndedSessionUnderAMinuteShowsOneMinute() {
        let record = FocusSessionRecord(id: "a", completedAt: .now, durationMinutes: 25,
                                        actualActiveSeconds: 20, isCompleted: false)
        #expect(record.lastSessionMinutes == 1)
    }

    private func makeTimer(clock: StageClock) -> PomodoroTimer {
        PomodoroTimer(systemSideEffectsEnabled: false, defaults: nil, deviceID: UUID(), now: { clock.now })
    }
}

@MainActor
private final class StageClock {
    var now = Date(timeIntervalSinceReferenceDate: 20_000)
}
