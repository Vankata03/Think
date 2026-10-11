//
//  WatchPathStepTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

@MainActor
struct WatchPathStepTests {
    private let deepFocus = PathLibrary.deepFocus

    @Test func namesStepOneOpenBeforeAnyCompletion() throws {
        let calendar = try sofia()
        let now = try date(calendar, day: 10, hour: 9)
        let store = ProgressStore(defaults: makeDefaults(), calendar: calendar, now: { now })

        let step = try #require(WatchPathStep(progress: store, now: now))

        #expect(step.number == 1)
        #expect(step.step.title == deepFocus.steps[0].title)
        #expect(step.opensAt == nil)
    }

    @Test func nextStepAfterA2330CompletionOpensAtSixTheNextDay() throws {
        let calendar = try sofia()
        let lateEvening = try date(calendar, day: 10, hour: 23, minute: 30)
        let store = ProgressStore(defaults: makeDefaults(), calendar: calendar, now: { lateEvening })
        #expect(store.completePathStep(pathID: deepFocus.id, totalSteps: deepFocus.steps.count, at: lateEvening))
        let six = try date(calendar, day: 11, hour: 6)

        let sameNight = try #require(WatchPathStep(progress: store, now: lateEvening))
        #expect(sameNight.number == 2)
        #expect(sameNight.opensAt == six)
        #expect(sameNight.opensTomorrow)

        let beforeSix = try #require(WatchPathStep(progress: store, now: six.addingTimeInterval(-60)))
        #expect(beforeSix.opensAt == six)
        #expect(!beforeSix.opensTomorrow)

        let atSix = try #require(WatchPathStep(progress: store, now: six))
        #expect(atSix.number == 2)
        #expect(atSix.opensAt == nil)
    }

    @Test func undatedLegacyProgressFromAnOlderPhoneStillWaitsForSix() throws {
        let calendar = try sofia()
        let lateEvening = try date(calendar, day: 10, hour: 23, minute: 30)
        let watch = ProgressStore(defaults: makeDefaults(), calendar: calendar, now: { lateEvening })
        watch.apply(
            ProgressSnapshot(
                streak: 1, lastCompletedDay: lateEvening, practiceDays: [lateEvening],
                pathCompletedDays: 3, lastPathCompletionDay: lateEvening,
                totalFocusSessions: 0, focusSessionDay: nil, focusSessionDayCount: 0,
                lastOpenDay: nil, appliedEventIDs: [], publishedAt: lateEvening))

        let step = try #require(WatchPathStep(progress: watch, now: lateEvening))

        #expect(step.number == 4)
        #expect(step.opensAt == (try date(calendar, day: 11, hour: 6)))
    }

    @Test func finishedRunHasNoStep() throws {
        let calendar = try sofia()
        var now = try date(calendar, day: 1, hour: 9)
        let store = ProgressStore(defaults: makeDefaults(), calendar: calendar, now: { now })
        for _ in deepFocus.steps {
            #expect(store.completePathStep(pathID: deepFocus.id, totalSteps: deepFocus.steps.count, at: now))
            now = try #require(calendar.date(byAdding: .day, value: 1, to: now))
        }

        #expect(WatchPathStep(progress: store, now: now) == nil)
    }

    private func sofia() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Sofia"))
        return calendar
    }

    private func date(_ calendar: Calendar, day: Int, hour: Int, minute: Int = 0) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour, minute: minute)))
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "ThinkTests.WatchPathStep.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
