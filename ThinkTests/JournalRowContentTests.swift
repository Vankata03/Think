import Foundation
import SwiftData
import Testing
@testable import Think

/// What the compact Journal row says (`design/journal.md` section 4).
@MainActor struct JournalRowContentTests {
    private let repository: JournalRepository
    private let date = Date(timeIntervalSince1970: 1_790_000_000)

    init() throws {
        let container = try ModelContainer(for: JournalDataStore.schema, configurations: JournalDataStore.configuration(for: .inMemory))
        repository = JournalRepository(modelContext: container.mainContext)
    }

    private func entry(_ receipt: JournalRepository.SaveReceipt) throws -> JournalRepository.EntrySnapshot {
        try #require(try repository.entry(id: receipt.recordID))
    }

    @Test func titleIsTheFirstSentenceAndTheRestFollowsTheTime() throws {
        let note = try entry(repository.saveNote(text: "Finish the chapter. Nobody is waiting for it.\nTwo hours before lunch.",
                                                 date: date))
        let content = JournalRowContent(note)

        #expect(content.kind == .note)
        #expect(content.title == "Finish the chapter.")
        #expect(content.rest == "Nobody is waiting for it. Two hours before lunch.")
        #expect(content.time == date.formatted(date: .omitted, time: .shortened))
    }

    @Test func aFirstLineEndsTheTitleAndOneSentenceLeavesNoRest() throws {
        let lines = JournalRowContent(try entry(repository.saveNote(text: "Groceries\nmilk, bread")))
        #expect(lines.title == "Groceries" && lines.rest == "milk, bread")

        let answer = JournalRowContent(try entry(repository.saveAnswer(text: "  Calling the bank  ", prompt: "What are you avoiding?")))
        #expect(answer.kind == .answer)
        #expect(answer.title == "Calling the bank" && answer.rest.isEmpty)
    }

    @Test func retroTitleIsItsFirstNonEmptyField() throws {
        let receipt = try repository.saveRetro(wentWell: "", improve: "Started late. Email first.", tomorrow: "Block 9 to 11.",
                                               tomorrowIntention: "No inbox before 11.")
        let retro = try #require(try repository.retro(id: receipt.recordID))
        let content = JournalRowContent(retro)

        #expect(content.kind == .retro)
        #expect(content.title == "Started late.")
        #expect(content.rest == "Email first. Block 9 to 11. No inbox before 11.")

        let moodOnly = try #require(try repository.retro(id: repository.saveRetro(wentWell: "", improve: "", tomorrow: "", mood: .flat).recordID))
        #expect(JournalRowContent(moodOnly).title == JournalRowContent.Kind.retro.name)
    }

    @Test func weeklyReviewIsTitledByItsWeekWithoutATime() throws {
        let weekStart = CivilDay(year: 2026, month: 9, day: 14).start
        let review = JournalRowContent(try entry(repository.saveWeeklyReview(text: "Five of seven days.", nextIntention: "Pack the practice.",
                                                                             weekStart: weekStart)))

        #expect(review.kind == .weeklyReview)
        #expect(review.title == String(localized: "Week of \(weekStart.formatted(.dateTime.day().month(.wide)))"))
        #expect(review.time == nil)
        #expect(review.rest == "Five of seven days. Pack the practice.")
    }

    @Test func moodAndThemeJoinMoodAndPrimaryThemeOnly() throws {
        let tagged = JournalRowContent(try entry(repository.saveNote(text: "Walk.", mood: .good,
                                                                     themes: ThemeSelection(primary: .health, secondary: .rest))))
        #expect(tagged.moodAndTheme == "\(Mood.good.label) · \(Theme.health.label)")

        let themeOnly = JournalRowContent(try entry(repository.saveFocusNote(text: "Draft.", intention: "Write", sessionID: "s",
                                                                           themes: ThemeSelection(primary: .making))))
        #expect(themeOnly.kind == .focusNote && themeOnly.moodAndTheme == Theme.making.label)

        #expect(JournalRowContent(try entry(repository.saveNote(text: "Plain."))).moodAndTheme == nil)
    }

    @Test func rowReadsAsOneSentenceOfItsParts() throws {
        let note = try entry(repository.saveNote(text: "Lunch with Maya. She said it again.", mood: .steady,
                                                 themes: ThemeSelection(primary: .people), date: date))
        let version = JournalRowContent(note, isOtherVersion: true)

        #expect(version.accessibilityLabel == [
            String(localized: "Note"), "Lunch with Maya.", date.formatted(date: .omitted, time: .shortened),
            String(localized: "Other version"), "She said it again.", Mood.steady.label, Theme.people.label,
        ].joined(separator: ", "))
        #expect(!JournalRowContent(note).accessibilityLabel.contains(String(localized: "Other version")))
    }
}
