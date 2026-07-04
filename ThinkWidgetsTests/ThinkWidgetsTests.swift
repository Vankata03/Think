//
//  ThinkWidgetsTests.swift
//  ThinkWidgetsTests
//

import Foundation
import Testing
import WidgetKit
@testable import ThinkWidgetsExtension

@MainActor
struct DailyQuoteTimelineTests {

    @Test func entriesCoverTodayAndTheNextSixDays() throws {
        let calendar = utcCalendar()
        let now = try date(year: 2026, month: 7, day: 4, hour: 15, minute: 30, calendar: calendar)

        let entries = DailyQuoteTimelineFactory.entries(startingAt: now, calendar: calendar)

        #expect(entries.count == 7)
        #expect(entries.first?.date == now)

        for (offset, entry) in entries.enumerated() {
            let day = try #require(calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)))
            let expectedDate = offset == 0 ? now : day
            #expect(entry.date == expectedDate)
            #expect(entry.quote == ContentLibrary.dailyQuote(for: day))
        }
    }

    @Test func dailyQuoteWidgetViewBodyBuildsForSampleEntry() {
        let entry = QuoteEntry(date: .now, quote: ContentLibrary.dailyQuote())
        let view = DailyQuoteWidgetView(entry: entry, familyOverride: .systemSmall)

        _ = view.body
    }

    @Test func dailyQuoteWidgetConfigurationBuilds() {
        _ = DailyQuoteWidget().body
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
struct PomodoroLiveActivityPresentationTests {

    @Test func workPhaseUsesDeepWorkPresentation() {
        let state = PomodoroActivityAttributes.ContentState(phase: .work, endDate: .now)

        #expect(PomodoroLiveActivityPresentation.title(for: state) == "Deep work")
        #expect(PomodoroLiveActivityPresentation.symbol(for: state) == "brain.head.profile")
    }

    @Test func restPhaseUsesBreakPresentation() {
        let state = PomodoroActivityAttributes.ContentState(phase: .rest, endDate: .now)

        #expect(PomodoroLiveActivityPresentation.title(for: state) == "Break")
        #expect(PomodoroLiveActivityPresentation.symbol(for: state) == "cup.and.saucer")
    }

    @Test func activityContentStateRoundTripsThroughJSON() throws {
        let state = PomodoroActivityAttributes.ContentState(
            phase: .work,
            endDate: Date(timeIntervalSinceReferenceDate: 804_470_400)
        )

        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PomodoroActivityAttributes.ContentState.self, from: encoded)

        #expect(decoded == state)
    }

    @Test func liveActivityConfigurationBuilds() {
        _ = PomodoroLiveActivity().body
    }
}

@MainActor
struct ThinkWidgetsBundleTests {

    @Test func widgetBundleBodyBuilds() {
        _ = ThinkWidgetsBundle().body
    }
}
