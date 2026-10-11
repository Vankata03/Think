import Foundation
import SwiftData
import Testing

@testable import Think

/// What the read detail says for each kind (`design/journal.md` section 5).
@MainActor struct JournalDetailContentTests {
    private let repository: JournalRepository
    private let date = Date(timeIntervalSince1970: 1_790_000_000)

    init() throws {
        let container = try ModelContainer(for: JournalDataStore.schema, configurations: JournalDataStore.configuration(for: .inMemory))
        repository = JournalRepository(modelContext: container.mainContext)
    }

    private func entry(_ receipt: JournalRepository.SaveReceipt) throws -> JournalRepository.EntrySnapshot {
        try #require(try repository.entry(id: receipt.recordID))
    }

    private func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }

    @Test func answerShowsItsQuestionTextAndEveryTag() throws {
        let answer = try entry(
            repository.saveAnswer(
                text: "Calling the bank.", prompt: "What are you avoiding?", mood: .low,
                themes: ThemeSelection(primary: .money, secondary: .home),
                day: CivilDay(date: date), date: date))
        let content = JournalDetailContent(answer)

        #expect(content.title == "Answer")
        #expect(content.day == JournalTimeline.fullDate(CivilDay(date: date)))
        #expect(content.prompt == .init(text: "What are you avoiding?", style: .question))
        #expect(content.fields == [.init(heading: nil, text: "Calling the bank.")])
        #expect(content.written == "Written \(time(date))")
        #expect(content.tags == "Low · Money · Home")
        #expect(content.deleteTitle == "Delete this entry?")
    }

    @Test func noteHasNoPromptAndNoTagsWhenUntagged() throws {
        let content = JournalDetailContent(try entry(repository.saveNote(text: "Groceries", date: date)))

        #expect(content.title == "Note")
        #expect(content.prompt == nil)
        #expect(content.tags == nil)
    }

    /// A focus note's prompt is its session intention, which cannot be
    /// edited, so it reads as secondary rather than a question.
    @Test func focusNotePromptIsItsIntention() throws {
        let content = JournalDetailContent(
            try entry(
                repository.saveFocusNote(
                    text: "Got the scene down.", intention: "Write chapter 3",
                    sessionID: "s1", completedAt: date)))

        #expect(content.title == "Focus note")
        #expect(content.prompt == .init(text: "Write chapter 3", style: .intention))
    }

    /// A weekly review is titled by its week and adds "Next week". It has
    /// no moment of writing, so no "Written" time and no separate day line.
    @Test func weeklyReviewShowsItsWeekAndNextWeek() throws {
        let weekStart = CivilDay(year: 2026, month: 9, day: 14).start
        let review = try entry(
            repository.saveWeeklyReview(
                text: "Five of seven days.", nextIntention: "Pack the practice.",
                weekStart: weekStart))
        let content = JournalDetailContent(review)

        #expect(content.title == "Weekly review")
        #expect(content.day == nil)
        #expect(content.prompt == .init(text: "Week of \(weekStart.formatted(.dateTime.day().month(.wide)))", style: .question))
        #expect(content.fields == [.init(heading: nil, text: "Five of seven days."), .init(heading: "Next week", text: "Pack the practice.")])
        #expect(content.written == nil)
    }

    /// A retro shows each answered prompt over its answer, then the
    /// intention for tomorrow; its delete copy names the retro.
    @Test func retroShowsItsAnsweredPromptsThenTheIntention() throws {
        let receipt = try repository.saveRetro(
            wentWell: "Shipped the draft.", improve: "", tomorrow: "Block 9 to 11.", mood: .good,
            date: date, tomorrowIntention: "No inbox before 11.")
        let content = JournalDetailContent(try #require(try repository.retro(id: receipt.recordID)))

        #expect(content.title == "Retro")
        #expect(content.prompt == nil)
        #expect(
            content.fields == [
                .init(heading: "What went well?", text: "Shipped the draft."),
                .init(heading: "Ideas & tomorrow", text: "Block 9 to 11."),
                .init(heading: "Intention for tomorrow", text: "No inbox before 11."),
            ])
        #expect(content.written == "Written \(time(date))")
        #expect(content.tags == "Good")
        #expect(content.deleteTitle == "Delete this retro?")
    }

    /// An edit adds its time; an edit on a later day carries its date too.
    @Test func anEditAddsItsTime() throws {
        let receipt = try repository.saveNote(text: "First draft", date: date)
        try repository.updateEntry(id: receipt.recordID, text: "Second draft", mood: nil)
        let note = try entry(receipt)
        let edited = try #require(note.updatedAt)

        #expect(
            JournalDetailContent(note).written
                == "Written \(time(date)) · Edited \(edited.formatted(date: .abbreviated, time: .shortened))")
    }
}
