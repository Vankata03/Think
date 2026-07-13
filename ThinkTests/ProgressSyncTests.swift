//
//  ProgressSyncTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

@MainActor
struct ProgressSyncTests {

    @Test func delayedFocusSessionUsesCompletionDayNotReceiveDay() {
        let calendar = Calendar(identifier: .gregorian)
        let store = ProgressStore(defaults: makeDefaults(), calendar: calendar)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now))!

        store.recordFocusSession(at: yesterday.addingTimeInterval(60 * 60))

        #expect(store.totalFocusSessions == 1)
        #expect(store.focusSessionsToday == 0)
        #expect(store.hasCompleted(yesterday))
        #expect(!store.completedTaskToday)
    }

    @Test func outOfOrderCompletionRecomputesContiguousStreak() {
        let calendar = Calendar(identifier: .gregorian)
        let store = ProgressStore(defaults: makeDefaults(), calendar: calendar)
        let today = calendar.startOfDay(for: .now)
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        store.recordFocusSession(at: today)
        store.recordFocusSession(at: twoDaysAgo)
        #expect(store.streak == 1)
        store.recordFocusSession(at: yesterday)

        #expect(store.streak == 3)
        #expect(store.lastCompletedDay == today)
        #expect(store.totalFocusSessions == 3)
    }

    @Test func snapshotSortsDaysAndRoundTripsEveryField() {
        let store = ProgressStore(defaults: makeDefaults())
        store.recordFocusSession()
        store.recordFocusSession(at: Date(timeIntervalSince1970: 500_000))
        store.recordFocusSession(at: Date(timeIntervalSince1970: 100_000))
        store.completePathStep()
        store.recordAppOpen()
        let snapshot = store.snapshot(
            appliedEventIDs: ["first", "second"],
            publishedAt: Date(timeIntervalSince1970: 7_000)
        )

        #expect(snapshot.completedDays == snapshot.completedDays.sorted())
        #expect(snapshot.completedDays.count == 3)
        #expect(snapshot.appliedEventIDs == ["first", "second"])
        #expect(snapshot.totalFocusSessions == 3)
        #expect(snapshot.pathCompletedDays == 1)
        #expect(snapshot.focusSessionDayCount == 1)
        #expect(snapshot.publishedAt == Date(timeIntervalSince1970: 7_000))
    }

    @Test func applyingSnapshotClearsAbsentOptionalFields() {
        let defaults = makeDefaults()
        let store = ProgressStore(defaults: defaults)
        store.recordFocusSession()
        store.completePathStep()
        store.recordAppOpen()

        let empty = ProgressSnapshot(
            streak: 0,
            lastCompletedDay: nil,
            completedDays: [],
            pathCompletedDays: 0,
            lastPathCompletionDay: nil,
            totalFocusSessions: 0,
            focusSessionDay: nil,
            focusSessionDayCount: 0,
            lastOpenDay: nil,
            appliedEventIDs: [],
            publishedAt: .now
        )
        store.apply(empty)

        #expect(store.lastCompletedDay == nil)
        #expect(store.lastPathCompletionDay == nil)
        #expect(store.totalFocusSessions == 0)
        #expect(store.completedDays.isEmpty)
        #expect(store.focusHistory.isEmpty)
        #expect(!store.openedToday)
        #expect(ProgressStore(defaults: defaults).lastCompletedDay == nil)
    }

    @Test func snapshotKeepsFocusHistoryPhoneLocal() throws {
        let now = Date.now
        let source = ProgressStore(defaults: makeDefaults(), now: { now })
        source.recordFocusSession(at: now, durationMinutes: 25, eventID: "session")
        let snapshot = source.snapshot(publishedAt: now)
        let destination = ProgressStore(defaults: makeDefaults(), now: { now })

        destination.apply(snapshot)

        let encoded = try #require(
            JSONSerialization.jsonObject(with: SyncCodec.encode(snapshot)) as? [String: Any]
        )
        #expect(encoded["focusHistory"] == nil)
        #expect(source.focusHistory.map(\.durationMinutes) == [25])
        #expect(destination.focusHistory.isEmpty)
        #expect(destination.totalFocusSessions == 1)
    }

    @Test func mutationCallbackFiresOnlyForSuccessfulLocalMutations() {
        let store = ProgressStore(defaults: makeDefaults())
        var mutations: [ProgressMutation] = []
        store.onMutation = { mutations.append($0) }

        store.markTodayComplete()
        store.markTodayComplete()
        store.recordAppOpen()
        store.recordAppOpen()
        store.completePathStep()
        store.completePathStep()
        store.recordFocusSession()
        store.reset()

        #expect(mutations.count == 5)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "ThinkTests.ProgressSync.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
