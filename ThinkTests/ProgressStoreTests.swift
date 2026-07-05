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
