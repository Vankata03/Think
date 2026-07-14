//
//  PomodoroTimerTests.swift
//  ThinkTests
//

import Testing
import Foundation
@testable import Think

@MainActor
struct PomodoroTimerTests {

    @Test func timerStartsInClassicWorkPhase() {
        let timer = PomodoroTimer(systemSideEffectsEnabled: false)

        #expect(timer.preset == .classic)
        #expect(timer.phase == .work)
        #expect(timer.remainingSeconds == 25 * 60)
        #expect(!timer.isRunning)
        #expect(timer.remainingLabel == "25:00")
    }

    @Test func selectingPresetResetsWorkDuration() {
        let timer = PomodoroTimer(systemSideEffectsEnabled: false)

        timer.select(.long)

        #expect(timer.preset == .long)
        #expect(timer.phase == .work)
        #expect(timer.remainingSeconds == 50 * 60)
        #expect(timer.progress == 0)
    }

    @Test func skippingWorkMovesToRestWithoutRecordingSession() {
        let timer = PomodoroTimer(systemSideEffectsEnabled: false)
        var completedWorkSessions = 0
        timer.onWorkSessionComplete = { _ in completedWorkSessions += 1 }

        timer.skipPhase()

        #expect(timer.phase == .rest)
        #expect(timer.remainingSeconds == 5 * 60)
        #expect(completedWorkSessions == 0)
        #expect(timer.automaticTransitionCount == 0)
    }

    @Test func resetReturnsToCurrentPresetWorkPhase() {
        let timer = PomodoroTimer(systemSideEffectsEnabled: false)

        timer.select(.long)
        timer.skipPhase()
        timer.reset()

        #expect(timer.phase == .work)
        #expect(timer.remainingSeconds == 50 * 60)
        #expect(!timer.isRunning)
        #expect(timer.automaticTransitionCount == 0)
    }

    @Test func presetLabelShowsWorkAndRestDurations() {
        let preset = PomodoroTimer.Preset(workMinutes: 90, restMinutes: 20)

        #expect(preset.label == "90 / 20")
    }

    @Test func customPresetPersistsAcrossTimerReconstruction() {
        let suiteName = "ThinkTests.PomodoroCustomPreset.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let firstTimer = PomodoroTimer(systemSideEffectsEnabled: false, defaults: defaults)

        #expect(firstTimer.selectCustom(workMinutes: 73, restMinutes: 17))
        firstTimer.select(.classic)

        let restoredTimer = PomodoroTimer(systemSideEffectsEnabled: false, defaults: defaults)

        #expect(restoredTimer.customPreset.workMinutes == 73)
        #expect(restoredTimer.customPreset.restMinutes == 17)
        #expect(restoredTimer.preset == .classic)
    }

    @Test func activeCustomPresetMatchingClassicPersistsAcrossTimerReconstruction() {
        let suiteName = "ThinkTests.PomodoroCustomPresetKind.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let firstTimer = PomodoroTimer(systemSideEffectsEnabled: false, defaults: defaults)

        #expect(firstTimer.selectCustom(workMinutes: 25, restMinutes: 5))

        let restoredTimer = PomodoroTimer(systemSideEffectsEnabled: false, defaults: defaults)

        #expect(restoredTimer.preset.isCustom)
        #expect(restoredTimer.customPreset.workMinutes == 25)
        #expect(restoredTimer.customPreset.restMinutes == 5)
    }

    @Test func customPresetRejectsDurationsOutsideSupportedRanges() {
        let timer = PomodoroTimer(systemSideEffectsEnabled: false)

        #expect(!timer.selectCustom(workMinutes: 4, restMinutes: 5))
        #expect(!timer.selectCustom(workMinutes: 25, restMinutes: 31))
        #expect(timer.preset == .classic)
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

    @Test func runningTimerRestoresAfterCreatingANewTimer() {
        let suiteName = "ThinkTests.PomodoroTimer.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstTimer = PomodoroTimer(systemSideEffectsEnabled: false, defaults: defaults)
        firstTimer.select(.long)
        firstTimer.skipPhase()
        firstTimer.start()

        let restoredTimer = PomodoroTimer(systemSideEffectsEnabled: false, defaults: defaults)

        #expect(restoredTimer.isRunning)
        #expect(restoredTimer.preset == .long)
        #expect(restoredTimer.phase == .rest)
        #expect((1...(10 * 60)).contains(restoredTimer.remainingSeconds))

        firstTimer.reset()
        restoredTimer.reset()
    }

    @Test func resetPersistsAnInactiveTimer() {
        let suiteName = "ThinkTests.PomodoroTimer.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let timer = PomodoroTimer(systemSideEffectsEnabled: false, defaults: defaults)
        timer.select(.long)
        timer.start()
        timer.reset()

        let restoredTimer = PomodoroTimer(systemSideEffectsEnabled: false, defaults: defaults)

        #expect(!restoredTimer.isRunning)
        #expect(restoredTimer.phase == .work)
        #expect(restoredTimer.preset == .long)
        #expect(restoredTimer.remainingSeconds == 50 * 60)
    }

    @Test func completingWorkPhaseMovesToBreakAndRecordsOneSession() {
        let timer = PomodoroTimer(systemSideEffectsEnabled: false)
        let preset = PomodoroTimer.Preset(workMinutes: 0, restMinutes: 5)
        var completedWorkSessions = 0
        timer.onWorkSessionComplete = { _ in completedWorkSessions += 1 }

        timer.select(preset)
        timer.start()
        timer.resync()
        timer.resync()

        #expect(timer.isRunning)
        #expect(timer.phase == .rest)
        #expect((1...(5 * 60)).contains(timer.remainingSeconds))
        #expect(completedWorkSessions == 1)
        #expect(timer.automaticTransitionCount == 1)

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
        #expect(timer.automaticTransitionCount == 1)
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
        timer.onWorkSessionComplete = { _ in completedWorkSessions += 1 }

        timer.select(preset)
        timer.start()
        timer.resync()

        #expect(!timer.isRunning)
        #expect(timer.phase == .work)
        #expect(timer.remainingSeconds == 0)
        #expect(completedWorkSessions == 1)
    }
}
