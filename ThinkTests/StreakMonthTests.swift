//
//  StreakMonthTests.swift
//  ThinkTests
//

import Foundation
import Testing

@testable import Think

/// One month of the streak sheet (`design/progress-settings.md` section 8):
/// the linear form's count, the practised-days text, the pager bounds and
/// each day's marker state.
struct StreakMonthTests {

    @Test func currentMonthCountsDaysUpToAndIncludingToday() {
        let month = StreakMonth(containing: date(9, 28), practiceDays: [], now: date(9, 28, hour: 21), calendar: calendar)

        #expect(month.countedDays == 28)
    }

    @Test func pastMonthCountsEveryDay() {
        let month = StreakMonth(containing: date(8, 10), practiceDays: [], now: date(9, 28), calendar: calendar)

        #expect(month.countedDays == 31)
    }

    /// The brief's own example (section 8.3): runs of three or more days
    /// collapse to a range, a pair stays two days.
    @Test func practisedDaysReadAsDatesAndRanges() {
        let days = [1, 2, 3, 4, 5, 8, 9, 11, 12, 13, 14] + Array(17...28)
        let completed = Set(days.map { calendar.startOfDay(for: date(9, $0)) })
            .union([calendar.startOfDay(for: date(8, 31)), calendar.startOfDay(for: date(10, 1))])

        let month = StreakMonth(containing: date(9, 15), practiceDays: completed, now: date(9, 28), calendar: calendar)

        #expect(month.practisedCount == 23)
        #expect(month.practisedDaysText == "1 to 5, 8, 9, 11 to 14 and 17 to 28 September")
    }

    /// Section 8.4: the linear form reads as one sentence.
    @Test func linearFormReadsMonthAndCount() {
        let completed = Set((8...28).map { calendar.startOfDay(for: date(9, $0)) })

        let month = StreakMonth(containing: date(9, 1), practiceDays: completed, now: date(9, 28), calendar: calendar)

        #expect(month.title == "September 2026")
        #expect(month.linearAccessibilityLabel == "September 2026, 21 of 28 days practised")
    }

    @Test func singlePractisedDayReadsAsOneDate() {
        let completed: Set<Date> = [calendar.startOfDay(for: date(8, 3))]

        let month = StreakMonth(containing: date(8, 1), practiceDays: completed, now: date(9, 28), calendar: calendar)

        #expect(month.practisedCount == 1)
        #expect(month.practisedDaysText == "3 August")
    }

    @Test func monthWithoutPractiseHasNoPractisedDaysText() {
        let month = StreakMonth(containing: date(9, 1), practiceDays: [], now: date(9, 28), calendar: calendar)

        #expect(month.practisedCount == 0)
        #expect(month.practisedDaysText == nil)
    }

    @Test func pagerRunsFromTheFirstPracticeMonthToTheCurrentMonth() {
        let completed: Set<Date> = [calendar.startOfDay(for: date(7, 20)), calendar.startOfDay(for: date(9, 2))]

        let first = StreakMonth(containing: date(7, 1), practiceDays: completed, now: date(9, 28), calendar: calendar)
        let middle = StreakMonth(containing: date(8, 1), practiceDays: completed, now: date(9, 28), calendar: calendar)
        let current = StreakMonth(containing: date(9, 1), practiceDays: completed, now: date(9, 28), calendar: calendar)

        #expect(!first.canShowPrevious && first.canShowNext)
        #expect(middle.canShowPrevious && middle.canShowNext)
        #expect(current.canShowPrevious && !current.canShowNext)
    }

    @Test func pagerStaysOnTheCurrentMonthWithoutPractice() {
        let month = StreakMonth(containing: date(9, 1), practiceDays: [], now: date(9, 28), calendar: calendar)

        #expect(!month.canShowPrevious)
        #expect(!month.canShowNext)
    }

    /// Six rows always, so paging between a five-row and a six-row month
    /// never resizes the sheet (`STK-1`). February 2027 starts on a Monday
    /// and fills four rows; August 2026 starts on a Saturday and needs six.
    @Test func everyMonthReservesSixWeeks() {
        let short = StreakMonth(containing: date(2, 1, year: 2027), practiceDays: [], now: date(9, 28), calendar: calendar)
        let long = StreakMonth(containing: date(8, 1), practiceDays: [], now: date(9, 28), calendar: calendar)

        #expect(short.weeks.count == 6)
        #expect(long.weeks.count == 6)
        #expect(short.weeks.allSatisfy { $0.count == 7 })
        #expect(short.weeks[0].first??.number == 1)
        #expect(long.weeks[0].prefix(5).allSatisfy { $0 == nil })
        #expect(long.weeks[5].first??.number == 31)
    }

    @Test func eachDayCarriesItsMarkerStateAndSpokenLabel() {
        let completed: Set<Date> = [27, 28].map { calendar.startOfDay(for: date(9, $0)) }.reduce(into: []) { $0.insert($1) }
        let month = StreakMonth(containing: date(9, 1), practiceDays: completed, now: date(9, 28, hour: 8), calendar: calendar)
        let days = month.weeks.flatMap { $0 }.compactMap { $0 }

        let today = days[27]
        #expect(today.isToday && today.isPractised && !today.isFuture)
        #expect(today.accessibilityLabel == "28 September, practised, today")
        #expect(days[26].isPractised && !days[26].isToday)
        #expect(days[26].accessibilityLabel == "27 September, practised")
        #expect(!days[14].isPractised && !days[14].isFuture)
        #expect(days[14].accessibilityLabel == "15 September")
        #expect(days[28].isFuture && !days[28].isPractised)
    }

    @Test func todayNotYetPractisedSaysToday() {
        let month = StreakMonth(containing: date(9, 1), practiceDays: [], now: date(9, 28), calendar: calendar)
        let today = month.weeks.flatMap { $0 }.compactMap { $0 }[27]

        #expect(today.isToday && !today.isPractised)
        #expect(today.accessibilityLabel == "28 September, today")
    }

    // MARK: - Helpers

    /// Gregorian, UTC, British English, Monday first: independent of the
    /// test machine.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_GB")
        calendar.firstWeekday = 2
        return calendar
    }

    /// A day at noon unless an hour is given, in 2026 unless a year is.
    private func date(_ month: Int, _ day: Int, year: Int = 2026, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
