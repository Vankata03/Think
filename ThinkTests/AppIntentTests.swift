//
//  AppIntentTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

@MainActor
struct AppIntentTests {
    @Test func focusHandlerStartsClassicThroughTimerMutationPath() {
        let timer = PomodoroTimer(systemSideEffectsEnabled: false)
        let handler = FocusSessionIntentHandler(timer: timer)
        var publishedStates: [TimerSyncState] = []
        timer.onStateChange = { publishedStates.append($0) }

        let outcome = handler.start(preset: .classic)

        #expect(outcome == .started)
        #expect(timer.isRunning)
        #expect(timer.preset == .classic)
        #expect(timer.phase == .work)
        #expect(publishedStates.count == 1)
        #expect(publishedStates.last?.isRunning == true)
        timer.reset()
    }

    @Test func focusHandlerSelectsLongPresetBeforeStarting() {
        let timer = PomodoroTimer(systemSideEffectsEnabled: false)
        let handler = FocusSessionIntentHandler(timer: timer)
        var publishedStates: [TimerSyncState] = []
        timer.onStateChange = { publishedStates.append($0) }

        let outcome = handler.start(preset: .long)

        #expect(outcome == .started)
        #expect(timer.isRunning)
        #expect(timer.preset == .long)
        #expect(timer.phase == .work)
        #expect(publishedStates.count == 2)
        #expect(publishedStates.first?.isRunning == false)
        #expect(publishedStates.last?.isRunning == true)
        timer.reset()
    }

    @Test func focusHandlerDoesNotRestartRunningSession() {
        let timer = PomodoroTimer(systemSideEffectsEnabled: false)
        let handler = FocusSessionIntentHandler(timer: timer)
        timer.start()
        let before = timer.syncState

        let outcome = handler.start(preset: .long)

        #expect(outcome == .alreadyRunning)
        #expect(timer.syncState == before)
        timer.reset()
    }

    @Test func showDailyLineRouterSelectsToday() {
        let router = AppIntentRouter()
        router.selectedTab = .focus

        router.showDailyLine()

        #expect(router.selectedTab == .today)
    }

    @Test func focusPresetMinutesComeFromTimerPresets() {
        #expect(FocusSessionPreset.classic.workMinutes == PomodoroTimer.Preset.classic.workMinutes)
        #expect(FocusSessionPreset.long.workMinutes == PomodoroTimer.Preset.long.workMinutes)
    }

    @Test func customPresetIsNotEligibleForFixedPresetDonation() {
        let custom = PomodoroTimer.Preset.custom(workMinutes: 73, restMinutes: 17)

        #expect(FocusSessionPreset(custom) == nil)
    }

    @Test func currentStreakReadsStoredProgressWithoutCreatingAStore() throws {
        let suiteName = "ThinkTests.AppIntentStreak.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 13,
            hour: 12
        )))
        defaults.set(7, forKey: "streak")
        defaults.set(calendar.startOfDay(for: now), forKey: "lastCompletedDay")

        let streak = CheckStreakIntent.currentStreak(in: defaults, calendar: calendar, now: now)

        #expect(streak == 7)
    }

    @Test func streakDialogCoversZeroOneAndMultipleDays() {
        #expect(
            String(localized: CheckStreakIntent.dialogResource(for: 0))
                == "Your streak is ready to begin."
        )
        #expect(
            String(localized: CheckStreakIntent.dialogResource(for: 1))
                == "Your current streak is 1 day."
        )
        #expect(
            String(localized: CheckStreakIntent.dialogResource(for: 7))
                == "Your current streak is 7 days."
        )
    }

    @Test func appShortcutsExposeAllThreeActions() {
        #expect(ThinkAppShortcuts.appShortcuts.count == 3)
    }
}
