import Foundation
import SwiftData
import Testing
@testable import Think

@MainActor struct JournalRepositoryTests {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: JournalDataStore.schema, configurations: JournalDataStore.configuration(for: .inMemory))
    }
    @Test func failedInsertRetryPersistsExactlyOnce() throws {
        let container = try container()
        enum Failure: Error { case injected }
        var fail = true
        let repository = JournalRepository(modelContext: container.mainContext, storage: .inMemory, commitInterceptor: {
            if fail { throw Failure.injected }
        })
        let id = UUID()
        #expect(throws: Failure.self) { try repository.saveNote(text: "Kept draft", recordID: id) }
        #expect(try container.mainContext.fetchCount(FetchDescriptor<JournalEntry>()) == 0)
        #expect(!container.mainContext.hasChanges)
        fail = false
        let receipt = try repository.saveNote(text: "Kept draft", recordID: id)
        #expect(receipt.recordID == id)
        _ = try repository.saveNote(text: "Kept draft", recordID: id)
        #expect(try repository.entries().totalCount == 1)
        #expect(try repository.entry(id: id)?.text == "Kept draft")
    }
    @Test func snapshotsOutliveContextAndReopenedRepositoryReadsCommittedUpdate() throws {
        let container = try container()
        let repository = JournalRepository(modelContext: container.mainContext)
        let receipt = try repository.saveNote(text: "Before")
        let snapshot = try #require(try repository.entry(id: receipt.recordID))
        try repository.updateEntry(id: receipt.recordID, text: "After", mood: .steady)
        #expect(snapshot.text == "Before")
        let reopened = JournalRepository(modelContext: ModelContext(container))
        let refreshed = try #require(try reopened.entry(id: receipt.recordID))
        #expect(refreshed.text == "After" && refreshed.mood == Mood.steady.rawValue)
        #expect(refreshed.persistentModelID == receipt.persistentID)
    }
    @Test func failedUpdateAndDeleteLeavePersistedOriginal() throws {
        let container = try container()
        enum Failure: Error { case injected }
        var fail = false
        let repository = JournalRepository(modelContext: container.mainContext, commitInterceptor: { if fail { throw Failure.injected } })
        let receipt = try repository.saveNote(text: "Original")
        fail = true
        #expect(throws: Failure.self) { try repository.updateEntry(id: receipt.recordID, text: "Wrong", mood: .low) }
        #expect(throws: Failure.self) { try repository.deleteEntry(id: receipt.recordID) }
        #expect(try repository.entry(id: receipt.recordID)?.text == "Original")
        #expect(try repository.entry(id: receipt.recordID)?.mood == nil)
    }
    @Test func offlineDuplicatesAndLegacyRowsSurviveIdentityMigration() throws {
        let container = try container()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let day = CivilDay(date: date)
        for body in ["First device", "Second device"] {
            let entry = JournalEntry(date: date, prompt: "Old prompt", text: body, kind: JournalEntry.kindQuestion)
            entry.recordID = nil; entry.civilDay = nil; entry.timeZoneIdentifier = nil
            container.mainContext.insert(entry)
        }
        try container.mainContext.save()
        let repository = JournalRepository(modelContext: container.mainContext)
        try repository.ensureRecordIdentities()
        let selection = try #require(try repository.answer(for: day))
        #expect(selection.all.count == 2)
        #expect(selection.hasConflicts)
        #expect(selection.all.allSatisfy { $0.recordID != nil && $0.civilDay == nil })
        let before = selection.primary.recordID
        try repository.ensureRecordIdentities()
        #expect(try repository.answer(for: day)?.primary.recordID == before)
    }
    @Test func queryCombinesPromptKindMoodAndPagination() throws {
        let container = try container()
        let repository = JournalRepository(modelContext: container.mainContext)
        for index in 0..<7 {
            _ = try repository.saveAnswer(text: "Response \(index)", prompt: "A useful question", mood: .good)
        }
        _ = try repository.saveNote(text: "Useful note", mood: .low)
        let query = JournalRepository.EntryQuery(search: "useful", kind: JournalEntry.kindQuestion, mood: .tagged(.good))
        let page = try repository.entries(matching: query, page: .init(offset: 0, limit: 3))
        let next = try repository.entries(matching: query, page: .init(offset: page.nextOffset, limit: 3))
        #expect(page.totalCount == 7 && page.records.count == 3 && page.hasMore)
        #expect(Set(page.records.compactMap(\.recordID)).isDisjoint(with: next.records.compactMap(\.recordID)))
    }
    // MARK: Review fixes (P1-1, P2-2 … P2-5, P2-7, P2-9)

    @Test func resaveUnderSameIdentityUpdatesInPlaceWithoutDuplicating() throws {
        let container = try container()
        let repository = JournalRepository(modelContext: container.mainContext)
        let id = UUID()
        let completedAt = Date(timeIntervalSince1970: 1_750_000_000)
        _ = try repository.saveFocusNote(text: "a", intention: "Read", sessionID: "s1", completedAt: completedAt, recordID: id)
        let first = try #require(try repository.entry(id: id))
        #expect(first.updatedAt == nil)
        // Identical resave (retry after failed cleanup): no duplicate, no churn.
        _ = try repository.saveFocusNote(text: "a", intention: "Read", sessionID: "s1", completedAt: .now, recordID: id)
        #expect(try repository.entries().totalCount == 1)
        #expect(try repository.entry(id: id)?.updatedAt == nil)
        // Edited closing note under the existing identity persists the edit,
        // keeping the captured date, day and session link.
        _ = try repository.saveFocusNote(text: "b", intention: "Read more", sessionID: "s1", completedAt: .now, recordID: id)
        let edited = try #require(try repository.entry(id: id))
        #expect(edited.text == "b" && edited.prompt == "Read more" && edited.updatedAt != nil)
        #expect(edited.date == completedAt && edited.civilDay == first.civilDay && edited.sessionID == "s1")
        #expect(try repository.entries().totalCount == 1)
        #expect(try repository.sessionMetadata(sessionID: "s1")?.closingNoteRecordID == id)

        // Answers keep their original prompt (historical context); text and mood update.
        let answerID = UUID()
        let day = CivilDay(year: 2026, month: 9, day: 7, timeZoneIdentifier: "Europe/Sofia")
        _ = try repository.saveAnswer(text: "x", prompt: "Original question", mood: .low, day: day, recordID: answerID)
        _ = try repository.saveAnswer(text: "y", prompt: "Different prompt", mood: .good, day: .today(), recordID: answerID)
        let answer = try #require(try repository.entry(id: answerID))
        #expect(answer.text == "y" && answer.mood == Mood.good.rawValue && answer.prompt == "Original question")
        #expect(answer.civilDay == day.key && answer.timeZoneIdentifier == "Europe/Sofia")

        let retroID = UUID()
        _ = try repository.saveRetro(wentWell: "w1", improve: "", tomorrow: "", day: day, recordID: retroID)
        _ = try repository.saveRetro(wentWell: "w2", improve: "i", tomorrow: "", day: .today(), tomorrowIntention: "carry", recordID: retroID)
        let retro = try #require(try repository.retro(id: retroID))
        #expect(retro.wentWell == "w2" && retro.improve == "i" && retro.tomorrowIntention == "carry" && retro.civilDay == day.key)
        #expect(try repository.retros().totalCount == 1)
    }

    @Test func recoveredFocusDraftReusesClosingNoteAndKeepsOutcome() throws {
        let container = try container()
        let repository = JournalRepository(modelContext: container.mainContext)
        let noteA = try repository.saveFocusNote(text: "A", intention: "Plan", sessionID: "s2")
        try repository.upsertSessionMetadata(sessionID: "s2", intention: "Plan", outcome: .movedForward, energy: .steady, closingNoteRecordID: noteA.recordID)
        // Mirrors JournalEditor.saveFocusSession(): a focus draft with its own
        // id targets the session's existing closing note, then restores fields.
        let draft = JournalDraft(kind: .focus, context: .init(sessionID: "s2"))
        let metadata = try #require(try repository.sessionMetadata(sessionID: "s2"))
        let receipt = try repository.saveFocusNote(text: "B", intention: "Plan", sessionID: "s2", recordID: metadata.closingNoteRecordID ?? draft.id)
        try repository.upsertSessionMetadata(sessionID: "s2", intention: "Plan", outcome: .movedForward, energy: .steady, closingNoteRecordID: receipt.recordID)
        let focusRows = try repository.entries(matching: .init(kind: JournalEntry.kindFocus)).records.filter { $0.sessionID == "s2" }
        #expect(focusRows.count == 1 && focusRows.first?.recordID == noteA.recordID && focusRows.first?.text == "B")
        let refreshed = try #require(try repository.sessionMetadata(sessionID: "s2"))
        #expect(refreshed.outcome == FocusOutcome.movedForward.rawValue && refreshed.energy == EnergyLevel.steady.rawValue)
        #expect(refreshed.closingNoteRecordID == noteA.recordID)
        // Metadata-only recovery: no note text, fields still land.
        try repository.upsertSessionMetadata(sessionID: "s3", intention: "Only intention", outcome: .done, energy: nil, closingNoteRecordID: nil)
        #expect(try repository.sessionMetadata(sessionID: "s3")?.outcome == FocusOutcome.done.rawValue)
    }

    @Test func weeklyReviewEditsIntentionAndStaysOutOfWeeklySummary() throws {
        let container = try container()
        let repository = JournalRepository(modelContext: container.mainContext)
        var calendar = Calendar(identifier: .iso8601); calendar.timeZone = .current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)!.start
        let week = DateInterval(start: weekStart, end: calendar.date(byAdding: .day, value: 7, to: weekStart)!)
        let id = UUID()
        _ = try repository.saveWeeklyReview(text: "Good week", nextIntention: "a", weekStart: weekStart, recordID: id)
        let summary = try repository.activitySummary(in: week)
        #expect(summary.notes == 0 && summary.untaggedCount == 0 && summary.answers == 0)
        try repository.updateWeeklyReview(id: id, text: "Good week", nextIntention: "b")
        #expect(try repository.entry(id: id)?.nextIntention == "b")
        #expect(try repository.weeklyReview(weekStart: weekStart)?.primary.recordID == id)
        #expect(throws: JournalRepository.RepositoryError.self) { try repository.updateWeeklyReview(id: id, text: " ", nextIntention: nil) }
    }

    @Test func weeklyReviewKeepsCapturedWeekAcrossZoneChange() throws {
        let container = try container()
        let repository = JournalRepository(modelContext: container.mainContext)
        // Monday 2026-09-07 in Sofia is still Sunday evening in New York.
        let sofia = TimeZone(identifier: "Europe/Sofia")!
        let day = CivilDay(year: 2026, month: 9, day: 7, timeZoneIdentifier: sofia.identifier)
        let draft = JournalDraft(kind: .weeklyReview, context: .init(civilDay: day, periodKey: JournalIdentity.weekKey(for: day.start, timeZone: sofia)))
        #expect(JournalIdentity.weekKey(for: day.start, timeZone: TimeZone(identifier: "America/New_York")!) == "2026-W36")
        _ = try repository.saveWeeklyReview(text: "Week", nextIntention: nil, weekStart: draft.context.civilDay.start,
                                            timeZone: draft.context.civilDay.timeZone, recordID: draft.id)
        let stored = try #require(try repository.entry(id: draft.id))
        #expect(stored.periodKey == "2026-W37" && stored.periodKey == draft.context.periodKey)
        #expect(stored.civilDay == day.key && stored.timeZoneIdentifier == sofia.identifier)
    }

    @Test func retroUpdateRejectsFullyEmptyContent() throws {
        let container = try container()
        let repository = JournalRepository(modelContext: container.mainContext)
        let receipt = try repository.saveRetro(wentWell: "kept", improve: "", tomorrow: "")
        #expect(throws: JournalRepository.RepositoryError.self) {
            try repository.updateRetro(id: receipt.recordID, wentWell: " ", improve: "", tomorrow: "\n", mood: nil, tomorrowIntention: "  ")
        }
        #expect(try repository.retro(id: receipt.recordID)?.wentWell == "kept")
    }

    @Test func onlyExplicitIntentionCarriesForwardAndSessionNotesLink() throws {
        let container = try container()
        let repository = JournalRepository(modelContext: container.mainContext)
        let day = CivilDay.today()
        _ = try repository.saveRetro(wentWell: "", improve: "", tomorrow: "Unstructured prose", day: day.previous)
        #expect(try repository.carriedIntention(for: day) == nil)
        let receipt = try repository.saveFocusNote(text: "Moved it forward", intention: "Read", sessionID: "session-1")
        #expect(try repository.sessionMetadata(sessionID: "session-1")?.closingNoteRecordID == receipt.recordID)
        try repository.deleteAllJournalData()
        #expect(try repository.sessionMetadata(sessionID: "session-1") == nil)
    }
    @Test func recoveredNoteKeepsCapturedCivilDay() throws {
        let container = try container()
        let repository = JournalRepository(modelContext: container.mainContext, storage: .inMemory)
        let date = Date(timeIntervalSince1970: 1_789_337_000)
        let day = CivilDay(date: date, timeZone: TimeZone(identifier: "Pacific/Auckland")!)
        let receipt = try repository.saveNote(text: "Captured note", day: day, date: date)
        let entry = try #require(try repository.entry(id: receipt.recordID))
        #expect(entry.day.key == day.key)
        #expect(entry.day.timeZoneIdentifier == day.timeZoneIdentifier)
    }

}
