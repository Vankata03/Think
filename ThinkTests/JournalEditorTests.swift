import Foundation
import SwiftData
import Testing
@testable import Think

/// The editor's two seams: `JournalRepository.save(_:)`, which commits a
/// draft of any kind, and `JournalDraft.editing(_:)`, which reopens a
/// stored record through Edit.
@MainActor struct JournalEditorTests {
    private func repository() throws -> JournalRepository {
        let container = try ModelContainer(for: JournalDataStore.schema, configurations: JournalDataStore.configuration(for: .inMemory))
        return JournalRepository(modelContext: container.mainContext, storage: .inMemory)
    }
    private let day = CivilDay(year: 2026, month: 9, day: 26, timeZoneIdentifier: "Europe/Sofia")

    @Test func aNewNoteSavesWithMoodAndThemesAndReopensThroughEdit() throws {
        let repository = try repository()
        var draft = JournalDraft(kind: .note, context: .init(civilDay: day))
        draft.text = "Long walk after work"
        draft.mood = Mood.steady.rawValue
        draft.themes = ThemeSelection(primary: .health, secondary: .rest)
        let receipt = try #require(try repository.save(draft))

        let stored = try #require(try repository.entry(id: receipt.recordID))
        #expect(stored.kind == JournalEntry.kindNote && stored.text == "Long walk after work" && stored.civilDay == day.key)
        var editing = try #require(JournalDraft.editing(stored))
        #expect(editing.kind == .note && editing.mood == "steady")
        #expect(editing.themes == ThemeSelection(primary: .health, secondary: .rest))

        editing.text = "Long walk after work, then dinner"
        editing.mood = nil
        editing.themes.toggle(.health)
        _ = try repository.save(editing)
        let edited = try #require(try repository.entry(id: receipt.recordID))
        #expect(edited.text == "Long walk after work, then dinner" && edited.mood == nil)
        #expect(edited.themes == ThemeSelection(primary: .rest))
        #expect(try repository.entries().totalCount == 1)
    }

    @Test func aNewAnswerKeepsTheDaysQuestionAsItsPromptAndEditsInPlace() throws {
        let repository = try repository()
        var draft = JournalDraft(kind: .answer, context: .init(civilDay: day, practiceID: "practice.001", promptSnapshot: "What did you notice today?"))
        draft.text = "The light at six"
        draft.themes = ThemeSelection(primary: .making)
        let receipt = try #require(try repository.save(draft))

        let stored = try #require(try repository.answer(for: day)?.primary)
        #expect(stored.recordID == receipt.recordID && stored.prompt == "What did you notice today?")
        var editing = try #require(JournalDraft.editing(stored))
        #expect(editing.kind == .answer && editing.context.promptSnapshot == "What did you notice today?")
        #expect(editing.themes == ThemeSelection(primary: .making))

        editing.text = "The light at six, again"
        editing.mood = Mood.good.rawValue
        editing.themes.toggle(.people)
        _ = try repository.save(editing)
        let edited = try #require(try repository.entry(id: receipt.recordID))
        #expect(edited.text == "The light at six, again" && edited.mood == "good" && edited.prompt == "What did you notice today?")
        #expect(edited.themes == ThemeSelection(primary: .making, secondary: .people))
    }

    @Test func aNewRetroSavesItsFieldsIntentionMoodAndThemesAndEditsInPlace() throws {
        let repository = try repository()
        var draft = JournalDraft(kind: .retro, context: .init(civilDay: day))
        draft.fields = ["wentWell": "Finished the draft", "improve": "", "tomorrow": "Call Ana"]
        draft.tomorrowIntention = "Start early"
        draft.mood = Mood.sharp.rawValue
        draft.themes = ThemeSelection(primary: .work)
        let receipt = try #require(try repository.save(draft))

        let stored = try #require(try repository.retro(id: receipt.recordID))
        #expect(stored.wentWell == "Finished the draft" && stored.tomorrow == "Call Ana" && stored.tomorrowIntention == "Start early")
        var editing = try #require(JournalDraft.editing(stored))
        #expect(editing.kind == .retro && editing.mood == "sharp" && editing.themes == ThemeSelection(primary: .work))

        editing.fields["improve"] = "Fewer tabs"
        editing.themes.toggle(.home)
        _ = try repository.save(editing)
        let edited = try #require(try repository.retro(id: receipt.recordID))
        #expect(edited.improve == "Fewer tabs" && edited.wentWell == "Finished the draft")
        #expect(edited.themes == ThemeSelection(primary: .work, secondary: .home))
        #expect(try repository.retros().totalCount == 1)
    }

    @Test func aFocusNoteEditsAsAPlainNoteAndLeavesTheSessionAlone() throws {
        let repository = try repository()
        let note = try repository.saveFocusNote(text: "Got the outline done", intention: "Outline chapter two", sessionID: "s1")
        try repository.upsertSessionMetadata(sessionID: "s1", intention: "Outline chapter two", outcome: .done, energy: .high,
                                             closingNoteRecordID: note.recordID)

        let stored = try #require(try repository.entry(id: note.recordID))
        var editing = try #require(JournalDraft.editing(stored))
        #expect(editing.kind == .focus && editing.context.promptSnapshot == "Outline chapter two")
        editing.text = "Got the outline and the first scene done"
        editing.mood = Mood.good.rawValue
        editing.themes = ThemeSelection(primary: .making)
        _ = try repository.save(editing)

        let edited = try #require(try repository.entry(id: note.recordID))
        #expect(edited.text == "Got the outline and the first scene done" && edited.prompt == "Outline chapter two")
        #expect(edited.mood == "good" && edited.themes == ThemeSelection(primary: .making))
        let session = try #require(try repository.sessionMetadata(sessionID: "s1"))
        #expect(session.outcome == FocusOutcome.done.rawValue && session.energy == EnergyLevel.high.rawValue)
    }

    @Test func aRecoveredSessionDraftKeepsItsMoodAndThemes() throws {
        let repository = try repository()
        var draft = JournalDraft(kind: .focus, context: .init(civilDay: day, promptSnapshot: "Plan the week", sessionID: "s2"))
        draft.text = "Planned Monday and Tuesday"
        draft.outcome = FocusOutcome.movedForward.rawValue
        draft.mood = Mood.flat.rawValue
        draft.themes = ThemeSelection(primary: .work)
        let receipt = try #require(try repository.save(draft))

        let stored = try #require(try repository.entry(id: receipt.recordID))
        #expect(stored.kind == JournalEntry.kindFocus && stored.prompt == "Plan the week")
        #expect(stored.mood == "flat" && stored.themes == ThemeSelection(primary: .work))
        #expect(try repository.sessionMetadata(sessionID: "s2")?.outcome == FocusOutcome.movedForward.rawValue)
    }

    @Test func somethingToSave() {
        var note = JournalDraft(kind: .note)
        #expect(!note.hasSomethingToSave)
        note.mood = Mood.low.rawValue
        note.themes = ThemeSelection(primary: .rest)
        #expect(!note.hasSomethingToSave)
        note.text = "  \n"
        #expect(!note.hasSomethingToSave)
        note.text = "A line"
        #expect(note.hasSomethingToSave)

        var retro = JournalDraft(kind: .retro)
        #expect(!retro.hasSomethingToSave)
        retro.mood = Mood.low.rawValue
        #expect(retro.hasSomethingToSave)

        var review = JournalDraft(kind: .weeklyReview)
        review.tomorrowIntention = "Rest more"
        #expect(review.hasSomethingToSave)

        // A session draft can always be saved: it may carry only an outcome.
        #expect(JournalDraft(kind: .focus, context: .init(sessionID: "s3")).hasSomethingToSave)
    }
}

/// What Today hands the editor when the person taps "Write answer" or
/// "Begin retro".
@MainActor struct JournalEditorOpeningTests {
    private let day = CivilDay(year: 2026, month: 9, day: 26, timeZoneIdentifier: "Europe/Sofia")
    private func repository() throws -> JournalRepository {
        let container = try ModelContainer(for: JournalDataStore.schema, configurations: JournalDataStore.configuration(for: .inMemory))
        return JournalRepository(modelContext: container.mainContext, storage: .inMemory)
    }
    private func drafts() -> JournalDraftStore {
        JournalDraftStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    @Test func aFirstRetroOfTheDayStartsBlankWithTheDaysPractice() throws {
        let opened = try JournalEditorOpening.retro(day: day, practiceID: "practice.004", prompt: "Q", locked: false,
                                                repository: try repository(), drafts: drafts())
        #expect(opened.draft.kind == .retro && opened.draft.context.editingRecordID == nil)
        #expect(opened.draft.context.civilDay == day && opened.draft.context.practiceID == "practice.004")
        #expect(opened.notice == nil)
    }

    @Test func anUnsavedRetroSurvivesRelaunchAndIsResumed() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var draft = JournalDraft(kind: .retro, context: .init(civilDay: day))
        draft.fields = ["wentWell": "Half written"]
        draft.themes = ThemeSelection(primary: .people)
        try JournalDraftStore(directory: directory).save(draft)

        let opened = try JournalEditorOpening.retro(day: day, practiceID: "p", prompt: "Q", locked: false,
                                                repository: try repository(), drafts: JournalDraftStore(directory: directory))
        #expect(opened.draft.id == draft.id && opened.draft.fields["wentWell"] == "Half written")
        #expect(opened.draft.themes == ThemeSelection(primary: .people))
    }

    @Test func aWrittenRetroOpensForEditInPlace() throws {
        let repository = try repository()
        let receipt = try repository.saveRetro(wentWell: "Done", improve: "", tomorrow: "", themes: ThemeSelection(primary: .rest), day: day)
        let opened = try JournalEditorOpening.retro(day: day, practiceID: "p", prompt: "Q", locked: false,
                                                repository: repository, drafts: drafts())
        #expect(opened.draft.context.editingRecordID == receipt.recordID)
        #expect(opened.draft.fields["wentWell"] == "Done" && opened.draft.themes == ThemeSelection(primary: .rest))
    }

    @Test func anUnsavedEditOfTheWrittenRetroIsResumed() throws {
        let repository = try repository()
        let store = drafts()
        let receipt = try repository.saveRetro(wentWell: "Done", improve: "", tomorrow: "", day: day)
        let stored = try #require(try repository.retro(id: receipt.recordID))
        var pending = try #require(JournalDraft.editing(stored))
        pending.fields["improve"] = "Unsaved change"
        try store.save(pending)

        let opened = try JournalEditorOpening.retro(day: day, practiceID: "p", prompt: "Q", locked: false,
                                                repository: repository, drafts: store)
        #expect(opened.draft.id == pending.id && opened.draft.fields["improve"] == "Unsaved change")
    }

    @Test func aLockedJournalOpensABlankRetroWithoutReadingAnything() throws {
        let repository = try repository()
        let store = drafts()
        _ = try repository.saveRetro(wentWell: "Private", improve: "", tomorrow: "", day: day)
        var pending = JournalDraft(kind: .retro, context: .init(civilDay: day))
        pending.fields = ["wentWell": "Private draft"]
        try store.save(pending)

        let opened = try JournalEditorOpening.retro(day: day, practiceID: "p", prompt: "Q", locked: true,
                                                repository: repository, drafts: store)
        #expect(opened.draft.id != pending.id && !opened.draft.containsPrivateContent)
    }

    @Test func unreadableDraftsStillOpenTheWrittenRetroWithANotice() throws {
        let repository = try repository()
        let receipt = try repository.saveRetro(wentWell: "Done", improve: "", tomorrow: "", day: day)
        // A file where the draft folder should be: listing the drafts fails.
        let location = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("not a directory".utf8).write(to: location)
        defer { try? FileManager.default.removeItem(at: location) }

        let opened = try JournalEditorOpening.retro(day: day, practiceID: "p", prompt: "Q", locked: false,
                                                    repository: repository, drafts: JournalDraftStore(directory: location))
        #expect(opened.draft.context.editingRecordID == receipt.recordID)
        #expect(opened.notice != nil)
    }

    @Test func anUnsavedAnswerSurvivesRelaunchAndIsResumed() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var draft = JournalDraft(kind: .answer, context: .init(civilDay: day, practiceID: "practice.004", promptSnapshot: "Q"))
        draft.text = "Half an answer"
        try JournalDraftStore(directory: directory).save(draft)

        let store = JournalDraftStore(directory: directory)
        let opened = JournalEditorOpening.answer(day: day, practiceID: "practice.004", prompt: "Q", locked: false, drafts: store)
        #expect(opened.draft.id == draft.id && opened.draft.text == "Half an answer")
        let locked = JournalEditorOpening.answer(day: day, practiceID: "practice.004", prompt: "Q", locked: true, drafts: store)
        #expect(locked.draft.id != draft.id && locked.draft.context.promptSnapshot == "Q")
    }
}
