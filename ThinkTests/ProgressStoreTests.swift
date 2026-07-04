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

    private func makeDefaults() -> UserDefaults {
        let suiteName = "ThinkTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
