import Foundation
import Testing
@testable import Think

@MainActor
struct PracticeProgressTests {
    private let day = Date(timeIntervalSince1970: 1_800_000_000)
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func defaults() -> UserDefaults { UserDefaults(suiteName: "PracticeProgressTests.\(UUID())")! }

    @Test func meaningfulUnionAndMoveReversalPreserveOtherEvidence() {
        let d = defaults()
        let store = ProgressStore(defaults: d, calendar: calendar, now: { day })
        store.recordAppOpen()
        #expect(store.dailyPracticeProgressCount == 0)
        store.setMoveCompleted(true, practiceID: "one", at: day)
        #expect(store.completedTaskToday)
        store.setMoveCompleted(false, practiceID: "one", at: day)
        #expect(!store.completedTaskToday)
        #expect(store.recordActivity(.answer, id: "answer", at: day))
        #expect(!store.recordActivity(.answer, id: "answer", at: day))
        store.setMoveCompleted(true, practiceID: "one", at: day)
        store.setMoveCompleted(false, practiceID: "one", at: day)
        #expect(store.activities(on: day) == [.answer])
        #expect(store.completedTaskToday)
        #expect(ProgressStore(defaults: d, calendar: calendar, now: { day }).activities(on: day) == [.answer])
    }

    @Test func independentRunsRepeatWithoutLosingAchievementsOrInventingDates() {
        let d = defaults()
        d.set(21, forKey: "pathCompletedDays")
        let store = ProgressStore(defaults: d, calendar: calendar, now: { day })
        #expect(store.completedPathCount == 1)
        #expect(store.activeRun(for: PathLibrary.deepFocus.id)?.completions.isEmpty == true)
        #expect(store.completedDays.isEmpty)
        _ = store.startNewRun(pathID: PathLibrary.deepFocus.id, totalSteps: 21, at: day)
        #expect(store.completePathStep(pathID: PathLibrary.deepFocus.id, totalSteps: 21, at: day))
        #expect(!store.completePathStep(pathID: PathLibrary.deepFocus.id, totalSteps: 21, at: day))
        #expect(store.completePathStep(pathID: "clear-thinking", totalSteps: 7, at: day))
        #expect(store.completedPathCount == 1)
        let loaded = ProgressStore(defaults: d, calendar: calendar, now: { day })
        #expect(loaded.runs(for: PathLibrary.deepFocus.id).count == 2)
        #expect(loaded.activeRun(for: "clear-thinking")?.completedSteps == 1)
        // Explicit repeat creates a different run, so its first step can be done today.
        _ = loaded.startNewRun(pathID: "clear-thinking", totalSteps: 7, at: day)
        #expect(loaded.completePathStep(pathID: "clear-thinking", totalSteps: 7, at: day))
    }

    @Test func pathsUnlockInOrderAndStayUnlockedAfterRestartAndReload() {
        let d = defaults()
        let store = ProgressStore(defaults: d, calendar: calendar, now: { day })
        #expect(store.isPathUnlocked("deep-focus"))
        #expect(!store.isPathUnlocked("clear-thinking"))
        #expect(!store.completePathStep(pathID: "clear-thinking", totalSteps: 7, at: day))
        #expect(store.activeRun(for: "clear-thinking") == nil)
        for offset in 0..<21 {
            #expect(store.completePathStep(pathID: "deep-focus", totalSteps: 21,
                                          at: day.addingTimeInterval(Double(offset) * 86_400)))
            #expect(store.isPathUnlocked("clear-thinking") == (offset == 20))
        }
        _ = store.startNewRun(pathID: "deep-focus", totalSteps: 21, at: day)
        let reloaded = ProgressStore(defaults: d, calendar: calendar, now: { day })
        #expect(reloaded.isPathUnlocked("clear-thinking"))
        #expect(reloaded.completePathStep(pathID: "clear-thinking", totalSteps: 7, at: day))
        #expect(!reloaded.isPathUnlocked("discipline"))
        #expect(!reloaded.isPathUnlocked("unknown"))
    }

    @Test func focusIdentityIsIdempotentBeyondHistoryRetentionAndPathLinkage() {
        let d = defaults()
        let store = ProgressStore(defaults: d, calendar: calendar, now: { day })
        let id = UUID().uuidString
        store.recordFocusSession(at: day, durationMinutes: 25, eventID: id, actualActiveSeconds: 1_500)
        store.recordFocusSession(at: day, durationMinutes: 25, eventID: id, actualActiveSeconds: 1_500)
        _ = store.completePathStep(pathID: "a", totalSteps: 2, at: day)
        #expect(store.totalFocusSessions == 1)
        #expect(store.completedDays.count == 1)
        let future = day.addingTimeInterval(400 * 86_400)
        let loaded = ProgressStore(defaults: d, calendar: calendar, now: { future })
        loaded.recordFocusSession(at: day, durationMinutes: 25, eventID: id)
        #expect(loaded.focusHistory.isEmpty)
        #expect(loaded.totalFocusSessions == 1)
    }

    @Test func weeklySummarySeparatesPlannedCompletedAndPartialActualEffort() {
        let store = ProgressStore(defaults: defaults(), calendar: calendar, now: { day })
        store.recordFocusSession(at: day, durationMinutes: 25, eventID: "legacy")
        store.recordFocusSession(at: day, durationMinutes: 5, eventID: "new", actualActiveSeconds: 300)
        store.recordPartialFocusSession(FocusSessionRecord(id: "partial", completedAt: day,
            durationMinutes: 25, actualActiveSeconds: 70, isCompleted: false))
        let summary = store.weeklySummary(containing: day, calendar: calendar)
        #expect(summary.practiceDays == 1)
        #expect(summary.completedSessions == 2)
        #expect(summary.completedMinutes == 30)
        #expect(summary.completedActiveSeconds == 300)
        #expect(summary.partialActiveSeconds == 70)
        #expect(summary.unknownActualDurationSessions == 1)
    }

    @Test func legacySessionDecoderLeavesActualDurationUnknown() throws {
        let data = Data(#"{"id":"old","completedAt":"2026-09-11T12:00:00.000Z","durationMinutes":25}"#.utf8)
        let value = try SyncCodec.decode(FocusSessionRecord.self, from: data)
        #expect(value.actualActiveSeconds == nil)
        #expect(value.isCompleted)
    }
}
