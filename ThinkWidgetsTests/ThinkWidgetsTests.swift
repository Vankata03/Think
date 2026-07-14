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
struct StreakWidgetTests {

    @Test func storedPresentationReadsStreakAndDailyPracticeProgress() throws {
        let defaults = makeDefaults()
        let calendar = utcCalendar()
        let now = try date(year: 2026, month: 7, day: 13, hour: 12, calendar: calendar)
        defaults.set(7, forKey: "streak")
        defaults.set(now, forKey: "lastCompletedDay")
        defaults.set(now, forKey: "lastOpenDay")
        defaults.set(now, forKey: "lastQuestionAnswerDay")
        defaults.set(now, forKey: "focusSessionDay")
        defaults.set(1, forKey: "focusSessionDayCount")
        defaults.set(now, forKey: "lastPathCompletionDay")

        let presentation = StreakPresentation.stored(
            in: defaults,
            calendar: calendar,
            now: now
        )

        #expect(presentation.streak == 7)
        #expect(presentation.completedPracticeCount == 4)
        #expect(presentation.practiceProgress == 1)
        #expect(presentation.isTodayComplete)
    }

    @Test func focusOnlyCountsAsOneDailyPracticeSignal() throws {
        let defaults = makeDefaults()
        let calendar = utcCalendar()
        let now = try date(year: 2026, month: 7, day: 13, hour: 12, calendar: calendar)
        defaults.set(now, forKey: "lastCompletedDay")
        defaults.set(now, forKey: "focusSessionDay")
        defaults.set(1, forKey: "focusSessionDayCount")

        let presentation = StreakPresentation.stored(
            in: defaults,
            calendar: calendar,
            now: now
        )

        #expect(presentation.completedPracticeCount == 1)
        #expect(presentation.practiceProgress == 0.25)
    }

    @Test func timelineCoversNowAndNextTwoMidnights() throws {
        let defaults = makeDefaults()
        let calendar = utcCalendar()
        let now = try date(year: 2026, month: 7, day: 13, hour: 12, calendar: calendar)
        defaults.set(3, forKey: "streak")
        defaults.set(now, forKey: "lastCompletedDay")

        let entries = StreakWidgetTimelineFactory.entries(
            startingAt: now,
            calendar: calendar,
            defaults: defaults
        )

        #expect(entries.count == 3)
        #expect(entries[0].date == now)
        #expect(entries[0].presentation.streak == 3)
        #expect(entries[1].presentation.streak == 3)
        #expect(entries[2].presentation.streak == 0)
        #expect(entries.dropFirst().allSatisfy { $0.presentation.completedPracticeCount == 0 })
    }

    @Test func presentationCopyCoversFreshActiveAndCompleteStates() {
        #expect(StreakPresentation(streak: 0, completedPracticeCount: 0).streakText == "Begin today")
        #expect(StreakPresentation(streak: 1, completedPracticeCount: 1).streakText == "1-day streak")
        #expect(StreakPresentation(streak: 7, completedPracticeCount: 2).streakText == "7-day streak")
        #expect(StreakPresentation(streak: 7, completedPracticeCount: 3).todayText == "3/4 today")
        #expect(StreakPresentation(streak: 7, completedPracticeCount: 4).todayText == "Today complete")
    }

    @Test func viewBuildsForEverySupportedFamily() {
        let entry = StreakWidgetEntry(date: .now, presentation: .placeholder)

        _ = StreakWidgetView(entry: entry, familyOverride: .accessoryCircular).body
        _ = StreakWidgetView(entry: entry, familyOverride: .accessoryRectangular).body
        _ = StreakWidgetView(entry: entry, familyOverride: .systemSmall).body
    }

    @Test func configurationBuilds() {
        _ = StreakWidget().body
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "ThinkWidgetsTests.Streak.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
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
        calendar: Calendar
    ) throws -> Date {
        try #require(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        )))
    }
}

@MainActor
struct PomodoroLiveActivityPresentationTests {

    @Test func workPhaseUsesDeepWorkPresentation() {
        let now = Date.now
        let state = PomodoroActivityAttributes.ContentState(
            phase: .work,
            startDate: now,
            endDate: now.addingTimeInterval(25 * 60)
        )

        #expect(PomodoroLiveActivityPresentation.title(for: state) == "Deep work")
        #expect(PomodoroLiveActivityPresentation.symbol(for: state) == "brain.head.profile")
    }

    @Test func restPhaseUsesBreakPresentation() {
        let now = Date.now
        let state = PomodoroActivityAttributes.ContentState(
            phase: .rest,
            startDate: now,
            endDate: now.addingTimeInterval(5 * 60)
        )

        #expect(PomodoroLiveActivityPresentation.title(for: state) == "Break")
        #expect(PomodoroLiveActivityPresentation.symbol(for: state) == "cup.and.saucer")
    }

    @Test func activityContentStateRoundTripsThroughJSON() throws {
        let startDate = Date(timeIntervalSinceReferenceDate: 804_470_400)
        let state = PomodoroActivityAttributes.ContentState(
            phase: .work,
            startDate: startDate,
            endDate: startDate.addingTimeInterval(25 * 60),
            restEndDate: startDate.addingTimeInterval(30 * 60)
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

    @Test func startFocusControlConfigurationBuilds() {
        _ = StartFocusControl().body
    }

}
