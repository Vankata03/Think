//
//  ThinkTests.swift
//  ThinkTests
//

import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import Think

@MainActor
struct ContentLibraryTests {

    @Test func dailyQuoteUsesStableDayRotation() {
        let firstDay = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let secondDay = Calendar.current.date(byAdding: .day, value: 1, to: firstDay)!
        let firstIndex = Int(firstDay.timeIntervalSince1970 / 86_400) % ContentLibrary.quotes.count
        let secondIndex = Int(secondDay.timeIntervalSince1970 / 86_400) % ContentLibrary.quotes.count

        #expect(ContentLibrary.dailyQuote(for: firstDay) == ContentLibrary.quotes[firstIndex])
        #expect(ContentLibrary.dailyQuote(for: secondDay) == ContentLibrary.quotes[secondIndex])
        #expect(secondIndex == (firstIndex + 1) % ContentLibrary.quotes.count)
    }

    @Test func dailyQuestionUsesStableDayRotation() {
        let firstDay = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let secondDay = Calendar.current.date(byAdding: .day, value: 1, to: firstDay)!
        let firstIndex = Int(firstDay.timeIntervalSince1970 / 86_400) % ContentLibrary.questions.count
        let secondIndex = Int(secondDay.timeIntervalSince1970 / 86_400) % ContentLibrary.questions.count

        #expect(ContentLibrary.dailyQuestion(for: firstDay) == ContentLibrary.questions[firstIndex])
        #expect(ContentLibrary.dailyQuestion(for: secondDay) == ContentLibrary.questions[secondIndex])
        #expect(secondIndex == (firstIndex + 1) % ContentLibrary.questions.count)
    }

    @Test func quotesHaveStableUniqueIdentifiers() {
        let ids = Set(ContentLibrary.quotes.map(\.id))

        #expect(ids.count == ContentLibrary.quotes.count)
        #expect(ContentLibrary.quotes.allSatisfy { !$0.text.isEmpty && !$0.author.isEmpty })
    }
}

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
        #expect(requests.first?.content.title == "Today's line")
        let quote = ContentLibrary.dailyQuote(for: now)
        #expect(requests.first?.content.body == "\(quote.text) — \(quote.author)")
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
            #expect(request.content.body == "\(quote.text) — \(quote.author)")
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
struct PathLibraryTests {

    @Test func deepFocusPathIsCompleteAndSequential() {
        let path = PathLibrary.deepFocus

        #expect(path.isAvailable)
        #expect(path.steps.count == 21)
        #expect(path.steps.map(\.id) == Array(1...21))
        #expect(path.steps.allSatisfy { !$0.title.isEmpty && !$0.lesson.isEmpty && !$0.task.isEmpty })
    }

    @Test func futurePathsAreLockedUntilContentShips() {
        let lockedPaths = PathLibrary.all.filter { !$0.isAvailable }

        #expect(lockedPaths.count == 3)
        #expect(lockedPaths.allSatisfy { $0.steps.isEmpty })
    }

    @Test func pathModelsRoundTripThroughJSON() throws {
        let encoded = try JSONEncoder().encode(PathLibrary.deepFocus)
        let decoded = try JSONDecoder().decode(ThinkingPath.self, from: encoded)

        #expect(decoded == PathLibrary.deepFocus)
    }
}

@MainActor
struct CardStyleTests {

    @Test func cardStylesHaveUniqueIdentifiersAndFreeOptions() {
        let styles = CardStyle.all
        let ids = Set(styles.map(\.id))

        #expect(ids.count == styles.count)
        #expect(styles.filter { !$0.isPro }.count == 2)
        #expect(styles.filter { $0.isPro }.count == 2)
    }
}

@MainActor
struct JournalEntryTests {

    @Test func questionEntryStoresPromptTextAndKind() {
        let entry = JournalEntry(prompt: "What matters?", text: "Focus.", kind: JournalEntry.kindQuestion)

        #expect(entry.prompt == "What matters?")
        #expect(entry.text == "Focus.")
        #expect(entry.kind == JournalEntry.kindQuestion)
    }

    @Test func journalEntriesPersistInInMemorySwiftDataContainer() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: JournalEntry.self, configurations: configuration)
        let context = ModelContext(container)
        let entry = JournalEntry(prompt: "", text: "A private note.", kind: JournalEntry.kindNote)

        context.insert(entry)
        try context.save()

        let descriptor = FetchDescriptor<JournalEntry>()
        let entries = try context.fetch(descriptor)
        #expect(entries.map(\.text) == ["A private note."])
        #expect(entries.map(\.kind) == [JournalEntry.kindNote])
    }
}

@MainActor
struct ProgressStoreTests {

    @Test func newStoreStartsWithNoVisibleProgress() {
        let store = ProgressStore(defaults: makeDefaults())

        #expect(store.displayedStreak == 0)
        #expect(store.focusSessionsToday == 0)
        #expect(store.totalFocusSessions == 0)
        #expect(store.pathCompletedDays == 0)
        #expect(!store.completedTaskToday)
    }

    @Test func markingTodayCompleteStartsAStreakAndDoesNotDoubleCount() {
        let store = ProgressStore(defaults: makeDefaults())

        store.markTodayComplete()
        store.markTodayComplete()

        #expect(store.displayedStreak == 1)
        #expect(store.completedTaskToday)
    }

    @Test func yesterdayCompletionExtendsStreak() {
        let defaults = makeDefaults()
        defaults.set(3, forKey: "streak")
        defaults.set(Calendar.current.date(byAdding: .day, value: -1, to: Date.now), forKey: "lastCompletedDay")
        let store = ProgressStore(defaults: defaults)

        store.markTodayComplete()

        #expect(store.displayedStreak == 4)
    }

    @Test func oldCompletionDoesNotDisplayAsActiveStreak() {
        let defaults = makeDefaults()
        defaults.set(7, forKey: "streak")
        defaults.set(Calendar.current.date(byAdding: .day, value: -3, to: Date.now), forKey: "lastCompletedDay")
        let store = ProgressStore(defaults: defaults)

        #expect(store.displayedStreak == 0)
    }

    @Test func focusSessionRecordsSessionAndMarksDayComplete() {
        let store = ProgressStore(defaults: makeDefaults())

        store.recordFocusSession()
        store.recordFocusSession()

        #expect(store.focusSessionsToday == 2)
        #expect(store.totalFocusSessions == 2)
        #expect(store.completedTaskToday)
        #expect(store.displayedStreak == 1)
    }

    @Test func pathStepCanOnlyBeCompletedOncePerDay() {
        let store = ProgressStore(defaults: makeDefaults())

        store.completePathStep()
        store.completePathStep()

        #expect(store.pathCompletedDays == 1)
        #expect(!store.canCompletePathStepToday)
        #expect(store.completedTaskToday)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "ThinkTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

@MainActor
struct PomodoroTimerTests {

    @Test func timerStartsInClassicWorkPhase() {
        let timer = PomodoroTimer()

        #expect(timer.preset == .classic)
        #expect(timer.phase == .work)
        #expect(timer.remainingSeconds == 25 * 60)
        #expect(!timer.isRunning)
        #expect(timer.remainingLabel == "25:00")
    }

    @Test func selectingPresetResetsWorkDuration() {
        let timer = PomodoroTimer()

        timer.select(.long)

        #expect(timer.preset == .long)
        #expect(timer.phase == .work)
        #expect(timer.remainingSeconds == 50 * 60)
        #expect(timer.progress == 0)
    }

    @Test func skippingWorkMovesToRestWithoutRecordingSession() {
        let timer = PomodoroTimer()
        var completedWorkSessions = 0
        timer.onWorkSessionComplete = { completedWorkSessions += 1 }

        timer.skipPhase()

        #expect(timer.phase == .rest)
        #expect(timer.remainingSeconds == 5 * 60)
        #expect(completedWorkSessions == 0)
    }

    @Test func resetReturnsToCurrentPresetWorkPhase() {
        let timer = PomodoroTimer()

        timer.select(.long)
        timer.skipPhase()
        timer.reset()

        #expect(timer.phase == .work)
        #expect(timer.remainingSeconds == 50 * 60)
        #expect(!timer.isRunning)
    }

    @Test func presetLabelShowsWorkAndRestDurations() {
        let preset = PomodoroTimer.Preset(workMinutes: 90, restMinutes: 20)

        #expect(preset.label == "90 / 20")
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

    @Test func completingWorkPhaseMovesToBreakAndRecordsOneSession() {
        let timer = PomodoroTimer(systemSideEffectsEnabled: false)
        let preset = PomodoroTimer.Preset(workMinutes: 0, restMinutes: 5)
        var completedWorkSessions = 0
        timer.onWorkSessionComplete = { completedWorkSessions += 1 }

        timer.select(preset)
        timer.start()
        timer.resync()
        timer.resync()

        #expect(timer.isRunning)
        #expect(timer.phase == .rest)
        #expect((1...(5 * 60)).contains(timer.remainingSeconds))
        #expect(completedWorkSessions == 1)

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
        timer.onWorkSessionComplete = { completedWorkSessions += 1 }

        timer.select(preset)
        timer.start()
        timer.resync()

        #expect(!timer.isRunning)
        #expect(timer.phase == .work)
        #expect(timer.remainingSeconds == 0)
        #expect(completedWorkSessions == 1)
    }
}
