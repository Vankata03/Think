//
//  FocusIntentionTests.swift
//  ThinkTests
//

import Foundation
import SwiftData
import Testing
@testable import Think

@MainActor
struct FocusIntentionTests {

    @Test func whitespaceOnlyIntentionIsTreatedAsAbsent() {
        #expect(PomodoroTimer.normalizedIntention(nil) == nil)
        #expect(PomodoroTimer.normalizedIntention("") == nil)
        #expect(PomodoroTimer.normalizedIntention("   \n ") == nil)
        #expect(PomodoroTimer.normalizedIntention("  Rewrite the sync codec  ") == "Rewrite the sync codec")
    }

    @Test func anOverLongIntentionIsRejected() {
        let atLimit = String(repeating: "a", count: PomodoroTimer.intentionMaxLength)
        let overLimit = String(repeating: "a", count: PomodoroTimer.intentionMaxLength + 1)

        #expect(PomodoroTimer.normalizedIntention(atLimit) == atLimit)
        #expect(PomodoroTimer.normalizedIntention(overLimit) == nil)
    }

    @Test func startingWithoutAnIntentionOffersNoNote() {
        let clock = TestClock(now: Date(timeIntervalSinceReferenceDate: 10_000))
        let timer = makeTimer(clock: clock)

        timer.start()
        clock.now = clock.now.addingTimeInterval(TimeInterval(25 * 60 + 1))
        timer.resync()

        #expect(timer.phase == .rest)
        #expect(timer.pendingFocusNote == nil)
    }

    @Test func aCompletedWorkPhaseWithAnIntentionAsksHowItWent() {
        let clock = TestClock(now: Date(timeIntervalSinceReferenceDate: 10_000))
        let timer = makeTimer(clock: clock)

        timer.setIntention("Rewrite the sync codec")
        timer.start()
        let workEnd = clock.now.addingTimeInterval(TimeInterval(25 * 60))
        clock.now = workEnd.addingTimeInterval(1)
        timer.resync()

        #expect(timer.pendingFocusNote?.intention == "Rewrite the sync codec")
        #expect(timer.pendingFocusNote?.completedAt == workEnd)
        // Cleared for the next session; the prompt carries the text now.
        #expect(timer.intention == nil)

        timer.clearPendingFocusNote()
        #expect(timer.pendingFocusNote == nil)
    }

    @Test func aPhaseThatEndedWhileTheAppWasAwayIsNotPromptedLater() {
        let clock = TestClock(now: Date(timeIntervalSinceReferenceDate: 10_000))
        let timer = makeTimer(clock: clock)

        timer.setIntention("Rewrite the sync codec")
        timer.start()
        // The app was suspended through the whole work phase and the
        // break, and only catches up hours later.
        clock.now = clock.now.addingTimeInterval(TimeInterval(3 * 60 * 60))
        timer.resync()

        #expect(timer.pendingFocusNote == nil)
        #expect(timer.intention == nil)
        // Still remembered as the last intention, so the next session can
        // reuse it in one tap.
        #expect(timer.lastIntention == "Rewrite the sync codec")
    }

    @Test func anUnansweredPromptIsDroppedOnceItGoesStale() {
        let clock = TestClock(now: Date(timeIntervalSinceReferenceDate: 10_000))
        let timer = makeTimer(clock: clock)

        timer.setIntention("Rewrite the sync codec")
        timer.start()
        let workEnd = clock.now.addingTimeInterval(TimeInterval(25 * 60))
        clock.now = workEnd.addingTimeInterval(1)
        timer.resync()
        #expect(timer.pendingFocusNote != nil)

        // Back on the Focus tab a few minutes later: still the same
        // working stretch, so the prompt stands.
        timer.discardStalePendingFocusNote(now: workEnd.addingTimeInterval(5 * 60))
        #expect(timer.pendingFocusNote != nil)

        timer.discardStalePendingFocusNote(now: workEnd.addingTimeInterval(60 * 60))
        #expect(timer.pendingFocusNote == nil)
    }

    @Test func theLastIntentionIsSuggestedOnlyOnItsOwnDay() {
        let clock = TestClock(now: Date(timeIntervalSinceReferenceDate: 10_000))
        let timer = makeTimer(clock: clock)

        timer.setIntention("Rewrite the sync codec")
        timer.start()
        let workEnd = clock.now.addingTimeInterval(TimeInterval(25 * 60))
        clock.now = workEnd.addingTimeInterval(1)
        timer.resync()

        #expect(timer.suggestedIntention(on: workEnd) == "Rewrite the sync codec")
        #expect(timer.suggestedIntention(on: workEnd.addingTimeInterval(24 * 60 * 60)) == nil)
    }

    @Test func aRunningTimerWithoutACompletionKeepsItsIntention() {
        let clock = TestClock(now: Date(timeIntervalSinceReferenceDate: 10_000))
        let timer = makeTimer(clock: clock)

        timer.setIntention("Rewrite the sync codec")
        timer.start()
        clock.now = clock.now.addingTimeInterval(60)
        timer.resync()
        // Pausing and skipping are not completions: the same task is
        // usually picked back up.
        timer.pause()
        timer.skipPhase()
        timer.reset()

        #expect(timer.intention == "Rewrite the sync codec")
        #expect(timer.pendingFocusNote == nil)
    }

    @Test func aFocusNoteIsOneJournalEntryOfItsOwnKind() throws {
        let container = try ModelContainer(
            for: JournalDataStore.schema,
            configurations: JournalDataStore.configuration(for: .inMemory)
        )
        let context = ModelContext(container)
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(
            JournalEntry(
                date: completedAt,
                prompt: "Rewrite the sync codec",
                text: "Slower than expected, but the codec is done.",
                kind: JournalEntry.kindFocus
            )
        )
        try context.save()

        let entries = try context.fetch(FetchDescriptor<JournalEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.kind == JournalEntry.kindFocus)
        #expect(entries.first?.date == completedAt)
        #expect(entries.first?.mood == nil)
    }

    @Test func theExportHeadsAFocusNoteWithItsIntention() {
        let entry = JournalEntry(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            prompt: "Rewrite the sync codec",
            text: "Slower than expected, but the codec is done.",
            kind: JournalEntry.kindFocus
        )

        let export = JournalExport(entries: [entry], retrospectives: [])
        let text = export.text(
            locale: Locale(identifier: "en_US"),
            timeZone: TimeZone(identifier: "UTC")!
        )

        #expect(text.contains("Intention: Rewrite the sync codec"))
        #expect(text.contains("After the session:\nSlower than expected, but the codec is done."))
        // Not filed as a plain note.
        #expect(!text.contains("Note:\n"))
    }

    private func makeTimer(clock: TestClock) -> PomodoroTimer {
        PomodoroTimer(
            systemSideEffectsEnabled: false,
            defaults: nil,
            now: { clock.now }
        )
    }
}

@MainActor
private final class TestClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
