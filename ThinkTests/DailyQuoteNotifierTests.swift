//
//  DailyQuoteNotifierTests.swift
//  ThinkTests
//

import Foundation
import Testing
import UserNotifications
@testable import Think

@MainActor
struct DailyQuoteNotifierTests {

    @Test func scheduledRequestsIncludeNextEightFutureDailyLines() throws {
        let calendar = utcCalendar()
        let now = try date(year: 2026, month: 7, day: 4, hour: 7, minute: 30, calendar: calendar)

        let requests = DailyQuoteNotifier.scheduledRequests(
            startingAt: now,
            minutes: 8 * 60,
            calendar: calendar
        )

        #expect(requests.count == 8)
        #expect(requests.first?.identifier == "daily-quote-0")
        #expect(requests.last?.identifier == "daily-quote-7")
        #expect(requests.first?.content.title == String(localized: "Today's line"))
        let quote = ContentLibrary.dailyQuote(for: now)
        #expect(requests.first?.content.body == quote.notificationText)
        let trigger = try #require(requests.first?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.year == 2026)
        #expect(trigger.dateComponents.month == 7)
        #expect(trigger.dateComponents.day == 4)
        #expect(trigger.dateComponents.hour == 8)
        #expect(trigger.dateComponents.minute == 0)
    }

    @Test func scheduledRequestsSkipTimesThatAlreadyPassedToday() throws {
        let calendar = utcCalendar()
        let now = try date(year: 2026, month: 7, day: 4, hour: 9, minute: 30, calendar: calendar)

        let requests = DailyQuoteNotifier.scheduledRequests(
            startingAt: now,
            minutes: 8 * 60,
            calendar: calendar
        )

        #expect(requests.count == 7)
        #expect(requests.first?.identifier == "daily-quote-1")
        let trigger = try #require(requests.first?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.day == 5)
        #expect(trigger.dateComponents.hour == 8)
        #expect(trigger.dateComponents.minute == 0)
    }

    @Test func scheduledRequestsUseCustomMinuteOffset() throws {
        let calendar = utcCalendar()
        let now = try date(year: 2026, month: 7, day: 4, hour: 12, minute: 0, calendar: calendar)

        let requests = DailyQuoteNotifier.scheduledRequests(
            startingAt: now,
            minutes: (13 * 60) + 15,
            calendar: calendar
        )

        #expect(requests.count == 8)
        let trigger = try #require(requests.first?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.day == 4)
        #expect(trigger.dateComponents.hour == 13)
        #expect(trigger.dateComponents.minute == 15)
    }

    @Test func scheduledRequestsUseTheQuoteForEachScheduledDay() throws {
        let calendar = utcCalendar()
        let now = try date(year: 2026, month: 7, day: 4, hour: 7, minute: 30, calendar: calendar)

        let requests = DailyQuoteNotifier.scheduledRequests(
            startingAt: now,
            minutes: 8 * 60,
            calendar: calendar
        )

        for (offset, request) in requests.enumerated() {
            let day = try #require(calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)))
            let quote = ContentLibrary.dailyQuote(for: day)
            #expect(request.content.body == quote.notificationText)
        }
    }

    @Test func scheduledRequestsExcludeTheExactCurrentFireTime() throws {
        let calendar = utcCalendar()
        let now = try date(year: 2026, month: 7, day: 4, hour: 8, minute: 0, calendar: calendar)

        let requests = DailyQuoteNotifier.scheduledRequests(
            startingAt: now,
            minutes: 8 * 60,
            calendar: calendar
        )

        #expect(requests.count == 7)
        #expect(requests.map(\.identifier) == (1..<8).map { "daily-quote-\($0)" })
    }

    @Test func scheduledRequestsUseTheConfiguredTimeZone() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let now = try date(year: 2026, month: 7, day: 4, hour: 7, minute: 30, calendar: calendar)

        let requests = DailyQuoteNotifier.scheduledRequests(
            startingAt: now,
            minutes: 8 * 60,
            calendar: calendar
        )

        let trigger = try #require(requests.first?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.year == 2026)
        #expect(trigger.dateComponents.month == 7)
        #expect(trigger.dateComponents.day == 4)
        #expect(trigger.dateComponents.hour == 8)
        #expect(trigger.dateComponents.minute == 0)
    }

    @Test func scheduledRequestsRollPastMidnightInTheCurrentTimeZone() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let now = try date(year: 2026, month: 7, day: 4, hour: 23, minute: 59, calendar: calendar)

        let requests = DailyQuoteNotifier.scheduledRequests(
            startingAt: now,
            minutes: 0,
            calendar: calendar
        )

        #expect(requests.count == 7)
        #expect(requests.first?.identifier == "daily-quote-1")
        let trigger = try #require(requests.first?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.day == 5)
        #expect(trigger.dateComponents.hour == 0)
        #expect(trigger.dateComponents.minute == 0)
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) throws -> Date {
        try #require(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }
}
