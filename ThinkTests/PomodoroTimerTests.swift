//
//  PomodoroTimerTests.swift
//  ThinkTests
//

import Testing
@testable import Think

@MainActor
struct PomodoroTimerTests {

    @Test func timerStartsInClassicWorkPhase() {
        let timer = PomodoroTimer()

        #expect(timer.preset == .classic)
        #expect(timer.phase == .work)
        #expect(timer.remainingSeconds == 25 * 60)
        #expect(!timer.isRunning)
        #expect(timer.remainingLabel == "25:00")
    }

    @Test func selectingPresetResetsWorkDuration() {
        let timer = PomodoroTimer()

        timer.select(.long)

        #expect(timer.preset == .long)
        #expect(timer.phase == .work)
        #expect(timer.remainingSeconds == 50 * 60)
        #expect(timer.progress == 0)
    }

    @Test func skippingWorkMovesToRestWithoutRecordingSession() {
        let timer = PomodoroTimer()
        var completedWorkSessions = 0
        timer.onWorkSessionComplete = { completedWorkSessions += 1 }

        timer.skipPhase()

        #expect(timer.phase == .rest)
        #expect(timer.remainingSeconds == 5 * 60)
        #expect(completedWorkSessions == 0)
    }

    @Test func resetReturnsToCurrentPresetWorkPhase() {
        let timer = PomodoroTimer()

        timer.select(.long)
        timer.skipPhase()
        timer.reset()

        #expect(timer.phase == .work)
        #expect(timer.remainingSeconds == 50 * 60)
        #expect(!timer.isRunning)
    }

    @Test func presetLabelShowsWorkAndRestDurations() {
        let preset = PomodoroTimer.Preset(workMinutes: 90, restMinutes: 20)

        #expect(preset.label == "90 / 20")
    }

    @Test func startAndPausePreserveRemainingWorkTime() {
        let timer = PomodoroTimer(systemSideEffectsEnabled: false)

        timer.start()
        #expect(timer.isRunning)
        #expect(timer.phase == .work)
        #expect(timer.remainingSeconds == 25 * 60)

        timer.pause()
        #expect(!timer.isRunning)
        #expect(timer.phase == .work)
        #expect((1...(25 * 60)).contains(timer.remainingSeconds))
    }

    @Test func toggleStartsAndPausesTimer() {
        let timer = PomodoroTimer(systemSideEffectsEnabled: false)

        timer.toggle()
        #expect(timer.isRunning)

        timer.toggle()
        #expect(!timer.isRunning)
        #expect(timer.phase == .work)
        #expect((1...(25 * 60)).contains(timer.remainingSeconds))
    }

    @Test func selectingPresetWhileRunningStopsAndResetsTimer() {
        let timer = PomodoroTimer(systemSideEffectsEnabled: false)

        timer.start()
        timer.select(.long)

        #expect(!timer.isRunning)
        #expect(timer.preset == .long)
        #expect(timer.phase == .work)
        #expect(timer.remainingSeconds == 50 * 60)
        #expect(timer.progress == 0)
    }

    @Test func completingWorkPhaseMovesToBreakAndRecordsOneSession() {
        let timer = PomodoroTimer(systemSideEffectsEnabled: false)
        let preset = PomodoroTimer.Preset(workMinutes: 0, restMinutes: 5)
        var completedWorkSessions = 0
        timer.onWorkSessionComplete = { completedWorkSessions += 1 }

        timer.select(preset)
        timer.start()
        timer.resync()
        timer.resync()

        #expect(timer.isRunning)
        #expect(timer.phase == .rest)
        #expect((1...(5 * 60)).contains(timer.remainingSeconds))
        #expect(completedWorkSessions == 1)

        timer.reset()
    }

    @Test func completingBreakPhaseStopsAtNextWorkSession() {
        let timer = PomodoroTimer(systemSideEffectsEnabled: false)
        let preset = PomodoroTimer.Preset(workMinutes: 1, restMinutes: 0)

        timer.select(preset)
        timer.skipPhase()
        timer.start()
        timer.resync()

        #expect(!timer.isRunning)
        #expect(timer.phase == .work)
        #expect(timer.remainingSeconds == 60)
    }

    @Test func skippingRunningWorkPhaseStartsBreakTimer() {
        let timer = PomodoroTimer(systemSideEffectsEnabled: false)
        let preset = PomodoroTimer.Preset(workMinutes: 1, restMinutes: 5)

        timer.select(preset)
        timer.start()
        timer.skipPhase()

        #expect(timer.isRunning)
        #expect(timer.phase == .rest)
        #expect(timer.remainingSeconds == 5 * 60)

        timer.reset()
    }

    @Test func skippingPausedBreakReturnsToWorkWithoutStartingTimer() {
        let timer = PomodoroTimer(systemSideEffectsEnabled: false)
        let preset = PomodoroTimer.Preset(workMinutes: 1, restMinutes: 5)

        timer.select(preset)
        timer.skipPhase()
        timer.skipPhase()

        #expect(!timer.isRunning)
        #expect(timer.phase == .work)
        #expect(timer.remainingSeconds == 60)
    }

    @Test func zeroLengthWorkAndBreakCompleteInOneResync() {
        let timer = PomodoroTimer(systemSideEffectsEnabled: false)
        let preset = PomodoroTimer.Preset(workMinutes: 0, restMinutes: 0)
        var completedWorkSessions = 0
        timer.onWorkSessionComplete = { completedWorkSessions += 1 }

        timer.select(preset)
        timer.start()
        timer.resync()

        #expect(!timer.isRunning)
        #expect(timer.phase == .work)
        #expect(timer.remainingSeconds == 0)
        #expect(completedWorkSessions == 1)
    }
}
