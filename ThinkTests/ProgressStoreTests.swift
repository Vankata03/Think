//
//  ProgressStoreTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

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

    @Test func focusHistoryStartsEmptyWithoutFabricatingFromAggregateCounters() {
        let defaults = makeDefaults()
        defaults.set(42, forKey: "totalFocusSessions")
        defaults.set(3, forKey: "focusSessionDayCount")

        let store = ProgressStore(defaults: defaults)

        #expect(store.focusHistory.isEmpty)
        #expect(store.focusHistoryByDay.isEmpty)
        #expect(defaults.data(forKey: "focusHistory") != nil)
    }

    @Test func focusHistoryStoresDateAndDurationInCalendarDayBuckets() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(SyncDateCoding.date(from: "2026-07-13T12:00:00.000Z"))
        let first = try #require(SyncDateCoding.date(from: "2026-07-12T09:00:00.000Z"))
        let second = try #require(SyncDateCoding.date(from: "2026-07-12T14:00:00.000Z"))
        let store = ProgressStore(defaults: makeDefaults(), calendar: calendar, now: { now })

        store.recordFocusSession(at: first, durationMinutes: 25, eventID: "first")
        store.recordFocusSession(at: second, durationMinutes: 50, eventID: "second")

        let day = calendar.startOfDay(for: first)
        #expect(store.focusHistoryByDay[day]?.map(\.durationMinutes) == [25, 50])
        #expect(store.focusHistory.map(\.completedAt) == [first, second])
        #expect(store.focusHistory.map(\.durationMinutes) == [25, 50])
    }

    @Test func focusHistoryPersistsAndDropsEntriesOutsideRollingYear() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let defaults = makeDefaults()
        let now = try #require(SyncDateCoding.date(from: "2026-07-13T12:00:00.000Z"))
        let retained = try #require(calendar.date(byAdding: .day, value: -364, to: now))
        let expired = try #require(calendar.date(byAdding: .day, value: -365, to: now))
        let store = ProgressStore(defaults: defaults, calendar: calendar, now: { now })

        store.recordFocusSession(at: retained, durationMinutes: 25, eventID: "retained")
        store.recordFocusSession(at: expired, durationMinutes: 50, eventID: "expired")

        #expect(store.focusHistory.map(\.id) == ["retained"])
        let reloaded = ProgressStore(defaults: defaults, calendar: calendar, now: { now })
        #expect(reloaded.focusHistory.map(\.id) == ["retained"])
    }

    @Test func focusSessionQueriesUseHalfOpenIntervals() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let day = try #require(SyncDateCoding.date(from: "2026-07-12T00:00:00.000Z"))
        let nextDay = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        let store = ProgressStore(defaults: makeDefaults(), calendar: calendar, now: { nextDay })
        store.recordFocusSession(at: day, durationMinutes: 25, eventID: "start")
        store.recordFocusSession(at: nextDay, durationMinutes: 50, eventID: "end")

        let sessions = store.focusSessions(in: DateInterval(start: day, end: nextDay))

        #expect(sessions.map(\.id) == ["start"])
    }

    @Test func unknownDurationUpdatesCountersWithoutInventingHistory() {
        let store = ProgressStore(defaults: makeDefaults())

        store.recordFocusSession(durationMinutes: nil, eventID: "legacy")

        #expect(store.totalFocusSessions == 1)
        #expect(store.focusHistory.isEmpty)
    }

    @Test func pathStepCanOnlyBeCompletedOncePerDay() {
        let store = ProgressStore(defaults: makeDefaults())

        store.completePathStep()
        store.completePathStep()

        #expect(store.pathCompletedDays == 1)
        #expect(!store.canCompletePathStepToday)
        #expect(store.completedTaskToday)
    }

    @Test func completedPathStepTodayOnlyReflectsTodaysCompletion() {
        let defaults = makeDefaults()
        defaults.set(3, forKey: "pathCompletedDays")
        defaults.set(Calendar.current.date(byAdding: .day, value: -1, to: Date.now), forKey: "lastPathCompletionDay")
        let store = ProgressStore(defaults: defaults)

        #expect(!store.completedPathStepToday)

        store.completePathStep()

        #expect(store.completedPathStepToday)
    }

    @Test func markingTodayCompleteRecordsDayInHistory() {
        let defaults = makeDefaults()
        let store = ProgressStore(defaults: defaults)

        store.markTodayComplete()

        #expect(store.hasCompleted(.now))
        #expect(!store.hasCompleted(Calendar.current.date(byAdding: .day, value: -1, to: .now)!))

        // History survives a reload from the same defaults.
        let reloaded = ProgressStore(defaults: defaults)
        #expect(reloaded.hasCompleted(.now))
    }

    @Test func missingHistoryBackfillsFromCurrentStreak() {
        let defaults = makeDefaults()
        let calendar = Calendar.current
        defaults.set(3, forKey: "streak")
        defaults.set(calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now)), forKey: "lastCompletedDay")

        let store = ProgressStore(defaults: defaults)

        #expect(!store.hasCompleted(.now))
        for offset in 1...3 {
            let day = calendar.date(byAdding: .day, value: -offset, to: .now)!
            #expect(store.hasCompleted(day))
        }
        #expect(!store.hasCompleted(calendar.date(byAdding: .day, value: -4, to: .now)!))
    }

    @Test func emptyHistoryBackfillIsPersistedAndNotRepeated() {
        let defaults = makeDefaults()
        _ = ProgressStore(defaults: defaults)

        // The (empty) backfill result is stored, so a streak written later
        // by another process is not re-synthesized into history.
        #expect(defaults.array(forKey: "completedDays") != nil)
    }

    @Test func recordingAppOpenCountsForTodayButNotTheStreak() {
        let defaults = makeDefaults()
        let store = ProgressStore(defaults: defaults)

        #expect(!store.openedToday)

        store.recordAppOpen()
        store.recordAppOpen()

        #expect(store.openedToday)
        #expect(store.displayedStreak == 0)
        #expect(!store.completedTaskToday)

        let reloaded = ProgressStore(defaults: defaults)
        #expect(reloaded.openedToday)
    }

    @Test func dailyPracticeProgressCountsFourIndependentSignals() {
        let defaults = makeDefaults()
        let store = ProgressStore(defaults: defaults)

        store.recordAppOpen()
        #expect(store.dailyPracticeProgressCount == 1)

        store.recordDailyQuestionAnswer()
        #expect(store.dailyPracticeProgressCount == 2)
        #expect(store.answeredDailyQuestionToday)

        store.recordFocusSession()
        #expect(store.dailyPracticeProgressCount == 3)

        store.completePathStep()
        #expect(store.dailyPracticeProgressCount == 4)
        #expect(ProgressStore.storedDailyPracticeProgressCount(in: defaults) == 4)
    }

    @Test func focusSessionDoesNotDoubleCountGenericDayCompletion() {
        let defaults = makeDefaults()
        let store = ProgressStore(defaults: defaults)

        store.recordFocusSession()

        #expect(store.completedTaskToday)
        #expect(store.dailyPracticeProgressCount == 1)
        #expect(ProgressStore.storedDailyPracticeProgressCount(in: defaults) == 1)
    }

    @Test func appOpenFromAnEarlierDayDoesNotCountToday() {
        let defaults = makeDefaults()
        defaults.set(Calendar.current.date(byAdding: .day, value: -1, to: Date.now), forKey: "lastOpenDay")
        let store = ProgressStore(defaults: defaults)

        #expect(!store.openedToday)
    }

    @Test func sharedDefaultsUsesConfiguredAppGroupName() {
        #expect(SharedDefaults.appGroupSuiteName == "group.com.ivanterziev.Think")
    }

    @Test func sharedDefaultsReturnsNamedSuiteWhenAvailable() {
        let suiteName = "ThinkTests.SharedDefaults.\(UUID().uuidString)"
        let fallback = makeDefaults()
        let defaults = SharedDefaults.make(suiteName: suiteName, fallback: fallback)

        defaults.set(42, forKey: "probe")

        #expect(defaults.integer(forKey: "probe") == 42)
        #expect(defaults !== fallback)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func sharedDefaultsFallsBackWhenSuiteCannotBeOpened() {
        let fallback = makeDefaults()
        let defaults = SharedDefaults.make(suiteName: "", fallback: fallback)

        #expect(defaults === fallback)
    }

    @Test func storedDisplayedStreakMatchesLiveStoreAndExpiresAfterYesterday() {
        let defaults = makeDefaults()
        let store = ProgressStore(defaults: defaults)

        #expect(ProgressStore.storedDisplayedStreak(in: defaults) == 0)

        store.markTodayComplete()

        #expect(ProgressStore.storedDisplayedStreak(in: defaults) == store.displayedStreak)

        let inTwoDays = Calendar.current.date(byAdding: .day, value: 2, to: .now)!
        #expect(ProgressStore.storedDisplayedStreak(in: defaults, now: inTwoDays) == 0)
    }

    @Test func resetClearsProgressAndPersistedHistory() {
        let defaults = makeDefaults()
        let store = ProgressStore(defaults: defaults)

        store.recordFocusSession()
        store.completePathStep()
        store.recordDailyQuestionAnswer()
        #expect(store.totalFocusSessions == 1)
        #expect(store.pathCompletedDays == 1)

        store.reset()

        #expect(store.displayedStreak == 0)
        #expect(store.totalFocusSessions == 0)
        #expect(store.pathCompletedDays == 0)
        #expect(store.completedDays.isEmpty)
        #expect(store.focusHistory.isEmpty)
        #expect(!store.openedToday)
        #expect(!store.answeredDailyQuestionToday)

        let reloaded = ProgressStore(defaults: defaults)
        #expect(reloaded.totalFocusSessions == 0)
        #expect(reloaded.pathCompletedDays == 0)
        #expect(reloaded.completedDays.isEmpty)
        #expect(reloaded.focusHistory.isEmpty)
    }

    @Test func migrationCopiesLegacyProgress() {
        let source = makeDefaults()
        let destination = makeDefaults()
        source.set(7, forKey: "pathCompletedDays")
        source.set(3, forKey: "streak")

        SharedDefaults.migrateProgressIfNeeded(from: source, to: destination)

        #expect(destination.integer(forKey: "pathCompletedDays") == 7)
        #expect(destination.integer(forKey: "streak") == 3)

        // A repeated migration must not clobber newer destination values.
        source.set(1, forKey: "pathCompletedDays")
        destination.set(9, forKey: "pathCompletedDays")
        SharedDefaults.migrateProgressIfNeeded(from: source, to: destination)

        #expect(destination.integer(forKey: "pathCompletedDays") == 9)
    }

    @Test func migrationPicksUpKeysAddedAfterFirstRun() {
        let source = makeDefaults()
        let destination = makeDefaults()
        source.set(3, forKey: "streak")
        SharedDefaults.migrateProgressIfNeeded(from: source, to: destination)

        // A key that only gains a legacy value later still migrates.
        source.set(11, forKey: "totalFocusSessions")
        SharedDefaults.migrateProgressIfNeeded(from: source, to: destination)

        #expect(destination.integer(forKey: "totalFocusSessions") == 11)
    }

    @Test func migrationCopiesCompletedDayHistoryAndLastOpenDay() {
        let source = makeDefaults()
        let destination = makeDefaults()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        source.set([today, yesterday], forKey: "completedDays")
        source.set(today, forKey: "lastOpenDay")

        SharedDefaults.migrateProgressIfNeeded(from: source, to: destination)

        let migrated = ProgressStore(defaults: destination)
        #expect(migrated.hasCompleted(today))
        #expect(migrated.hasCompleted(yesterday))
        #expect(migrated.openedToday)
    }

    @Test func migrationDoesNotOverwriteExistingDestinationValues() {
        let source = makeDefaults()
        let destination = makeDefaults()
        source.set(7, forKey: "pathCompletedDays")
        destination.set(12, forKey: "pathCompletedDays")

        SharedDefaults.migrateProgressIfNeeded(from: source, to: destination)

        #expect(destination.integer(forKey: "pathCompletedDays") == 12)
    }

    @Test func migrationSkipsWhenSourceAndDestinationAreSameStore() {
        let defaults = makeDefaults()
        defaults.set(5, forKey: "pathCompletedDays")

        SharedDefaults.migrateProgressIfNeeded(from: defaults, to: defaults)

        #expect(defaults.integer(forKey: "pathCompletedDays") == 5)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "ThinkTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
