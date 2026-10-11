//
//  StreakMonth.swift
//  Think
//

import Foundation

/// One month of the streak sheet (`design/progress-settings.md` section 8).
struct StreakMonth {
    let grid: MonthGrid
    /// The linear form's *m*: every day of a past month, or the days up to
    /// and including today in the current month.
    let countedDays: Int
    /// The linear form's *n*: practice days in this month.
    let practisedCount: Int
    /// The month's practice days as dates and ranges, for VoiceOver's
    /// "Practised days" custom content: "1 to 5, 8, 9 and 17 to 28
    /// September". Nil when the month has none.
    let practisedDaysText: String?
    /// Previous stops at the month of the first practice day, or at the
    /// current month when there is none.
    let canShowPrevious: Bool
    /// Next stops at the current month.
    let canShowNext: Bool
    /// Always six rows of seven, blanks before day 1 and after the last
    /// day, so the grid's height never changes between months (`STK-1`).
    let weeks: [[Day?]]

    struct Day: Hashable {
        let date: Date
        let number: Int
        let isPractised: Bool
        let isToday: Bool
        let isFuture: Bool
        /// "28 September, practised, today"; "15 September".
        let accessibilityLabel: String
    }

    static let rowCount = 6

    /// Month and year for the pager: "September 2026".
    let title: String

    /// The linear form as VoiceOver reads it (section 8.4).
    var linearAccessibilityLabel: String {
        String(
            localized: "streak.linear.accessibility",
            defaultValue: "\(title), \(practisedCount) of \(countedDays) days practised")
    }

    init(containing date: Date, practiceDays: Set<Date>, now: Date = .now, calendar: Calendar = .current) {
        grid = MonthGrid(containing: date, calendar: calendar)
        title = grid.monthStart.formatted(
            Date.FormatStyle(locale: calendar.locale ?? .current, calendar: calendar, timeZone: calendar.timeZone)
                .month(.wide).year())
        let today = calendar.startOfDay(for: now)
        let currentMonth = MonthGrid(containing: now, calendar: calendar).monthStart
        let firstMonth = practiceDays.min().map { MonthGrid(containing: $0, calendar: calendar).monthStart }
        canShowPrevious = grid.monthStart > min(firstMonth ?? currentMonth, currentMonth)
        canShowNext = grid.monthStart < currentMonth
        countedDays = grid.days.count { calendar.startOfDay(for: $0) <= today }

        let dayFormat = Date.FormatStyle(date: .omitted, time: .omitted, locale: calendar.locale ?? .current, calendar: calendar, timeZone: calendar.timeZone)
            .day().month(.wide)
        let days: [Day?] = grid.days.map { date in
            let start = calendar.startOfDay(for: date)
            let isPractised = practiceDays.contains(start)
            let isToday = start == today
            let name = date.formatted(dayFormat)
            let label: String =
                switch (isPractised, isToday) {
                case (true, true): String(localized: "streak.day.practisedToday", defaultValue: "\(name), practised, today")
                case (true, false): String(localized: "streak.day.practised", defaultValue: "\(name), practised")
                case (false, true): String(localized: "streak.day.today", defaultValue: "\(name), today")
                case (false, false): name
                }
            return Day(
                date: start, number: calendar.component(.day, from: date), isPractised: isPractised,
                isToday: isToday, isFuture: start > today, accessibilityLabel: label)
        }
        let cells = Array(repeating: nil, count: grid.leadingBlanks) + days
        let padded = cells + Array(repeating: nil, count: max(0, Self.rowCount * 7 - cells.count))
        weeks = stride(from: 0, to: padded.count, by: 7).map { Array(padded[$0..<min($0 + 7, padded.count)]) }

        let practised = grid.days
            .filter { practiceDays.contains(calendar.startOfDay(for: $0)) }
            .map { calendar.component(.day, from: $0) }
        practisedCount = practised.count
        practisedDaysText = Self.rangesText(
            practised, month: calendar.component(.month, from: grid.monthStart), calendar: calendar)
    }

    /// Runs of three or more days read as a range; a pair stays two days.
    private static func rangesText(_ days: [Int], month: Int, calendar: Calendar) -> String? {
        guard !days.isEmpty else { return nil }
        var runs: [[Int]] = []
        for day in days {
            if let last = runs.last?.last, last + 1 == day {
                runs[runs.count - 1].append(day)
            } else {
                runs.append([day])
            }
        }
        let parts = runs.flatMap { run -> [String] in
            guard run.count >= 3, let first = run.first, let last = run.last else {
                return run.map { String($0) }
            }
            return [String(localized: "streak.range", defaultValue: "\(first) to \(last)")]
        }
        let list = parts.formatted(.list(type: .and).locale(calendar.locale ?? .current))
        let monthName = calendar.monthSymbols[month - 1]
        return String(localized: "streak.practisedDays", defaultValue: "\(list) \(monthName)")
    }
}
