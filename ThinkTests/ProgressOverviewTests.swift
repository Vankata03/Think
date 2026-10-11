//
//  ProgressOverviewTests.swift
//  ThinkTests
//

import Foundation
import Testing

@testable import Think

/// What the Progress tab reads from `ProgressStore`
/// (`design/progress-settings.md` sections 1 and 2).
@MainActor
struct ProgressOverviewTests {

    @Test func newStoreShowsZeroEverywhere() {
        let overview = ProgressOverview(progress: makeStore(), now: time(day: 0, hour: 9), calendar: isoCalendar)

        #expect(overview.practiceDays == 0)
        #expect(overview.completedPathSteps == 0)
        #expect(overview.completedFocusSessions == 0)
        #expect(overview.week.practiceDays == 0)
        #expect(overview.week.completedSessions == 0)
        #expect(overview.recentSessions.isEmpty)
        #expect(overview.highlightedAchievements.isEmpty)
    }

    @Test func allTimeCountsLeavePartialEffortOut() {
        let store = makeStore()
        store.recordFocusSession(at: time(day: -10, hour: 9), durationMinutes: 25, eventID: "a")
        store.recordFocusSession(at: time(day: 0, hour: 9), durationMinutes: 25, eventID: "b")
        store.recordPartialFocusSession(
            FocusSessionRecord(
                id: "partial", completedAt: time(day: 0, hour: 11), durationMinutes: 25,
                actualActiveSeconds: 300, isCompleted: false))
        _ = store.completePathStep(pathID: PathLibrary.deepFocus.id, totalSteps: 21, at: time(day: -3, hour: 9))
        _ = store.completePathStep(pathID: PathLibrary.deepFocus.id, totalSteps: 21, at: time(day: -2, hour: 9))

        let overview = ProgressOverview(progress: store, now: time(day: 0, hour: 12), calendar: isoCalendar)

        // Days -10, -3, -2 and 0; the partial session adds no day.
        #expect(overview.practiceDays == 4)
        #expect(overview.completedPathSteps == 2)
        #expect(overview.completedFocusSessions == 2)
    }

    @Test func weekChartRunsMondayToSundayAndCountsOnlyCompletedSessions() {
        let store = makeStore()
        store.recordFocusSession(at: time(day: -5, hour: 9), durationMinutes: 25, eventID: "previous-sunday")
        store.recordFocusSession(at: time(day: -4, hour: 9), durationMinutes: 25, eventID: "monday-1")
        store.recordFocusSession(at: time(day: -4, hour: 10), durationMinutes: 25, eventID: "monday-2")
        store.recordPartialFocusSession(
            FocusSessionRecord(
                id: "monday-partial", completedAt: time(day: -4, hour: 11), durationMinutes: 25,
                actualActiveSeconds: 300, isCompleted: false))
        store.recordFocusSession(at: time(day: 2, hour: 9), durationMinutes: 25, eventID: "sunday")

        let overview = ProgressOverview(progress: store, now: time(day: 0, hour: 12), calendar: isoCalendar)

        // Friday 2027-01-15 sits in the week of Monday the 11th.
        #expect(overview.week.days.map(\.date) == (-4...2).map { time(day: $0, hour: 0) })
        #expect(overview.week.days.map(\.completedSessions) == [2, 0, 0, 0, 0, 0, 1])
        #expect(overview.week.practiceDays == 2)
    }

    @Test func weeksStartOnMondayInEveryLocale() {
        #expect(ProgressOverview.weekCalendar.firstWeekday == 2)
    }

    @Test func recentSessionsAreTheTwoNewestIncludingPartialEffort() {
        let store = makeStore()
        store.recordFocusSession(at: time(day: -1, hour: 9), durationMinutes: 25, eventID: "older")
        store.recordFocusSession(at: time(day: 0, hour: 9), durationMinutes: 25, eventID: "completed")
        store.recordPartialFocusSession(
            FocusSessionRecord(
                id: "partial", completedAt: time(day: 0, hour: 11), durationMinutes: 25,
                actualActiveSeconds: 300, isCompleted: false))

        let overview = ProgressOverview(progress: store, now: time(day: 0, hour: 12), calendar: isoCalendar)

        #expect(overview.recentSessions.map(\.id) == ["partial", "completed"])
    }

    @Test func highlightedMedalsAreTheHighestEarnedInEachGroup() {
        let store = makeStore()
        // Seven days in a row earns the 7-day streak; ten sessions earn Focus 1 and 10.
        for day in -6...0 {
            store.recordFocusSession(at: time(day: day, hour: 9), durationMinutes: 25, eventID: "day\(day)")
        }
        for index in 0..<3 {
            store.recordFocusSession(at: time(day: 0, hour: 10 + index), durationMinutes: 25, eventID: "extra\(index)")
        }

        let overview = ProgressOverview(progress: store, now: time(day: 0, hour: 12), calendar: isoCalendar)

        #expect(overview.highlightedAchievements == [.streak(.seven), .focus(10)])
    }

    // MARK: - Helpers

    private func makeStore() -> ProgressStore {
        let suiteName = "ThinkTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return ProgressStore(defaults: defaults, calendar: isoCalendar, now: { time(day: 0, hour: 12) })
    }

    /// Monday-first and UTC, so the week does not depend on the test machine.
    private var isoCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    /// A time on a day counted from Friday 2027-01-15 00:00 UTC.
    private func time(day: Int, hour: Int, minute: Int = 0) -> Date {
        Date(timeIntervalSince1970: 1_799_971_200 + Double(day * 86_400 + hour * 3_600 + minute * 60))
    }
}
