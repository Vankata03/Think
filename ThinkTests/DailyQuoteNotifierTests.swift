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
        let quote = ContentLibrary.dailyQuote(for: now, calendar: calendar)
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
            let quote = ContentLibrary.dailyQuote(for: day, calendar: calendar)
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

    @Test func scheduledRequestsUseTheConfiguredCalendarAcrossTheDateLine() throws {
        for timeZoneID in ["Pacific/Kiritimati", "America/Adak"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try #require(TimeZone(identifier: timeZoneID))
            let now = try date(
                year: 2026,
                month: 7,
                day: 4,
                hour: 7,
                minute: 30,
                calendar: calendar
            )

            let request = try #require(DailyQuoteNotifier.scheduledRequests(
                startingAt: now,
                minutes: 8 * 60,
                calendar: calendar
            ).first)

            #expect(
                request.content.body
                    == ContentLibrary.dailyQuote(for: now, calendar: calendar).notificationText
            )
        }
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

    @Test func richRequestIncludesRenderedAttachment() async throws {
        let scheduledLine = try #require(try scheduledLineFixture())
        let preparedRequest = await DailyQuoteNotifier.prepareRichRequest(for: scheduledLine)
        defer { preparedRequest.removeTemporaryFiles() }

        let attachment = try #require(preparedRequest.request.content.attachments.first)
        #expect(attachment.identifier == "daily-quote-0-card")
        #expect(attachment.type == "public.jpeg")
        #expect(preparedRequest.request.content.body == scheduledLine.quote.notificationText)
    }

    @Test func attachmentFailureFallsBackToTextOnlyRequest() async throws {
        enum TestError: Error { case failed }
        let scheduledLine = try #require(try scheduledLineFixture())

        let preparedRequest = await DailyQuoteNotifier.prepareRichRequest(
            for: scheduledLine,
            attachmentBuilder: { _, _ in throw TestError.failed }
        )

        #expect(preparedRequest.request.content.attachments.isEmpty)
        #expect(preparedRequest.request.content.title == String(localized: "Today's line"))
        #expect(preparedRequest.request.content.body == scheduledLine.quote.notificationText)
    }

    @Test func renderFailureRetriesTextFallbackAfterInitialAddFailure() async throws {
        enum TestError: Error { case failed }
        let scheduledLine = try #require(try scheduledLineFixture())
        var addAttempts = 0

        await DailyQuoteNotifier.schedule(
            [scheduledLine],
            isCurrent: { true },
            addRequest: { request in
                addAttempts += 1
                #expect(request.content.attachments.isEmpty)
                if addAttempts == 1 {
                    throw TestError.failed
                }
            },
            richRequestBuilder: { scheduledLine in
                DailyQuoteNotifier.PreparedNotificationRequest(
                    request: DailyQuoteNotifier.notificationRequest(for: scheduledLine)
                )
            }
        )

        #expect(addAttempts == 2)
    }

    @Test func canceledRefreshDoesNotReAddFallbackAfterRichAddFailure() async throws {
        enum TestError: Error { case failed }
        let scheduledLine = try #require(try scheduledLineFixture())
        let preparedRequest = await DailyQuoteNotifier.prepareRichRequest(for: scheduledLine)
        _ = try #require(preparedRequest.request.content.attachments.first)
        var isCurrent = true
        var addedRequests: [UNNotificationRequest] = []

        await DailyQuoteNotifier.schedule(
            [scheduledLine],
            isCurrent: { isCurrent },
            addRequest: { request in
                addedRequests.append(request)
                if !request.content.attachments.isEmpty {
                    isCurrent = false
                    throw TestError.failed
                }
            },
            richRequestBuilder: { _ in preparedRequest }
        )

        #expect(addedRequests.count == 2)
        #expect(addedRequests.filter { $0.content.attachments.isEmpty }.count == 1)
    }

    @Test func canceledRefreshRemovesRequestAddedAfterSuspension() async throws {
        let scheduledLine = try #require(try scheduledLineFixture())
        let adder = SuspendedNotificationAdder()
        var isCurrent = true

        let schedulingTask = Task {
            await DailyQuoteNotifier.schedule(
                [scheduledLine],
                isCurrent: { isCurrent },
                addRequest: { request in
                    await adder.add(request)
                },
                removeRequests: { identifiers in
                    adder.removeRequests(withIdentifiers: identifiers)
                }
            )
        }

        await adder.waitUntilSuspended()
        isCurrent = false
        adder.resumeAdd()
        await schedulingTask.value

        #expect(adder.pendingIdentifiers.isEmpty)
        #expect(adder.removedIdentifiers == [scheduledLine.identifier])
    }

    private func scheduledLineFixture() throws -> DailyQuoteNotifier.ScheduledDailyLine? {
        let calendar = utcCalendar()
        let now = try date(year: 2026, month: 7, day: 4, hour: 7, minute: 30, calendar: calendar)
        return DailyQuoteNotifier.scheduledDailyLines(
            startingAt: now,
            minutes: 8 * 60,
            calendar: calendar
        ).first
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

@MainActor
private final class SuspendedNotificationAdder {
    private(set) var pendingIdentifiers: Set<String> = []
    private(set) var removedIdentifiers: [String] = []
    private var addContinuation: CheckedContinuation<Void, Never>?
    private var suspensionWaiters: [CheckedContinuation<Void, Never>] = []

    func add(_ request: UNNotificationRequest) async {
        await withCheckedContinuation { continuation in
            addContinuation = continuation
            let waiters = suspensionWaiters
            suspensionWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }
        pendingIdentifiers.insert(request.identifier)
    }

    func waitUntilSuspended() async {
        if addContinuation != nil { return }
        await withCheckedContinuation { continuation in
            if addContinuation != nil {
                continuation.resume()
            } else {
                suspensionWaiters.append(continuation)
            }
        }
    }

    func resumeAdd() {
        addContinuation?.resume()
        addContinuation = nil
    }

    func removeRequests(withIdentifiers identifiers: [String]) {
        pendingIdentifiers.subtract(identifiers)
        removedIdentifiers.append(contentsOf: identifiers)
    }
}
