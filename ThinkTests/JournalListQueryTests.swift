import Foundation
import SwiftData
import Testing
@testable import Think

/// The Journal list's filters and search (`design/journal.md` sections 2,
/// 3 and 6), run through the repository against an in-memory store so the
/// filters execute as SwiftData predicates.
@MainActor struct JournalListQueryTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(for: JournalDataStore.schema, configurations: JournalDataStore.configuration(for: .inMemory))
    }

    private func repository() throws -> JournalRepository {
        JournalRepository(modelContext: container.mainContext)
    }

    private func texts(_ repository: JournalRepository, _ query: JournalRepository.EntryQuery) throws -> Set<String> {
        Set(try repository.entries(matching: query).records.map(\.text))
    }

    private func retroTexts(_ repository: JournalRepository, _ query: JournalRepository.RetroQuery) throws -> Set<String> {
        Set(try repository.retros(matching: query).records.map(\.wentWell))
    }

    @Test func themeFilterMatchesEitherField() throws {
        let repository = try repository()
        _ = try repository.saveNote(text: "Primary", themes: ThemeSelection(primary: .health, secondary: .work))
        _ = try repository.saveNote(text: "Secondary", themes: ThemeSelection(primary: .home, secondary: .health))
        _ = try repository.saveNote(text: "Other", themes: ThemeSelection(primary: .rest))
        _ = try repository.saveNote(text: "Untagged")
        _ = try repository.saveRetro(wentWell: "Retro primary", improve: "", tomorrow: "", themes: ThemeSelection(primary: .health))
        _ = try repository.saveRetro(wentWell: "Retro secondary", improve: "", tomorrow: "",
                                     themes: ThemeSelection(primary: .money, secondary: .health))
        _ = try repository.saveRetro(wentWell: "Retro untagged", improve: "", tomorrow: "")

        #expect(try texts(repository, .init(theme: .health)) == ["Primary", "Secondary"])
        #expect(try retroTexts(repository, .init(theme: .health)) == ["Retro primary", "Retro secondary"])
    }

    @Test func noMoodMatchesUntaggedAndUnknownMoods() throws {
        let repository = try repository()
        _ = try repository.saveNote(text: "Good", mood: .good)
        _ = try repository.saveNote(text: "Untagged")
        let future = try repository.saveNote(text: "Future mood")
        _ = try repository.saveRetro(wentWell: "Retro low", improve: "", tomorrow: "", mood: .low)
        _ = try repository.saveRetro(wentWell: "Retro untagged", improve: "", tomorrow: "")
        let context = ModelContext(container)
        let stored = try context.fetch(FetchDescriptor<JournalEntry>()).first { $0.recordID == future.recordID }
        stored?.mood = "ecstatic"
        try context.save()

        #expect(try texts(repository, .init(mood: .untagged)) == ["Untagged", "Future mood"])
        #expect(try texts(repository, .init(mood: .tagged(.good))) == ["Good"])
        #expect(try retroTexts(repository, .init(mood: .untagged)) == ["Retro untagged"])
        #expect(try retroTexts(repository, .init(mood: .tagged(.low))) == ["Retro low"])
    }

    @Test func kindFilterMatchesOneKind() throws {
        let repository = try repository()
        _ = try repository.saveAnswer(text: "Answer", prompt: "Question")
        _ = try repository.saveNote(text: "Note")
        _ = try repository.saveFocusNote(text: "Focus", intention: "Write", sessionID: "session")
        _ = try repository.saveWeeklyReview(text: "Weekly", nextIntention: nil, weekStart: .now)

        #expect(try texts(repository, .init(kind: JournalEntry.kindQuestion)) == ["Answer"])
        #expect(try texts(repository, .init(kind: JournalEntry.kindNote)) == ["Note"])
        #expect(try texts(repository, .init(kind: JournalEntry.kindFocus)) == ["Focus"])
        #expect(try texts(repository, .init(kind: JournalEntry.kindWeeklyReview)) == ["Weekly"])
        #expect(try texts(repository, .init()) == ["Answer", "Note", "Focus", "Weekly"])
    }

    @Test func dateFilterKeepsRecordsInsideTheRange() throws {
        let repository = try repository()
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let today = CivilDay(date: now)
        _ = try repository.saveNote(text: "Today", date: now)
        _ = try repository.saveNote(text: "Six days ago", date: today.adding(days: -6).start.addingTimeInterval(60))
        _ = try repository.saveNote(text: "Eight days ago", date: today.adding(days: -8).start)
        _ = try repository.saveRetro(wentWell: "Retro today", improve: "", tomorrow: "", day: today, date: now)
        _ = try repository.saveRetro(wentWell: "Retro old", improve: "", tomorrow: "", day: today.adding(days: -8),
                                     date: today.adding(days: -8).start)
        let week = DateInterval(start: today.adding(days: -6).start, end: today.next.start)

        #expect(try texts(repository, .init(dateRange: today.interval)) == ["Today"])
        #expect(try texts(repository, .init(dateRange: week)) == ["Today", "Six days ago"])
        #expect(try retroTexts(repository, .init(dateRange: week)) == ["Retro today"])
    }

    @Test func eachFilterCombinesWithSearch() throws {
        let repository = try repository()
        let now = Date.now
        _ = try repository.saveAnswer(text: "Walked by the river", prompt: "Question", mood: .good,
                                      themes: ThemeSelection(primary: .health))
        _ = try repository.saveNote(text: "River notes", mood: .low, themes: ThemeSelection(primary: .work, secondary: .health))
        _ = try repository.saveNote(text: "Mountain notes", mood: .good, themes: ThemeSelection(primary: .health))
        _ = try repository.saveNote(text: "Old river", date: CivilDay(date: now).adding(days: -40).start)
        _ = try repository.saveRetro(wentWell: "River swim", improve: "", tomorrow: "", mood: .good,
                                     themes: ThemeSelection(primary: .rest, secondary: .health))
        _ = try repository.saveRetro(wentWell: "Quiet day", improve: "", tomorrow: "", mood: .good)
        let today = CivilDay(date: now).interval

        #expect(try texts(repository, .init(search: "river", kind: JournalEntry.kindNote)) == ["River notes", "Old river"])
        #expect(try texts(repository, .init(search: "river", mood: .tagged(.good))) == ["Walked by the river"])
        #expect(try texts(repository, .init(search: "river", mood: .untagged)) == ["Old river"])
        #expect(try texts(repository, .init(search: "river", theme: .health)) == ["Walked by the river", "River notes"])
        #expect(try texts(repository, .init(search: "river", dateRange: today)) == ["Walked by the river", "River notes"])
        #expect(try retroTexts(repository, .init(search: "river", mood: .tagged(.good), theme: .health)) == ["River swim"])
        #expect(try retroTexts(repository, .init(search: "river", dateRange: today)) == ["River swim"])
    }

    @Test func filteredPagesContinueWhereThePreviousEnded() throws {
        let repository = try repository()
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        for index in 0..<7 {
            _ = try repository.saveNote(text: "Work \(index)", themes: ThemeSelection(primary: .work),
                                        date: start.addingTimeInterval(Double(index) * 3_600))
            _ = try repository.saveNote(text: "Rest \(index)", themes: ThemeSelection(primary: .rest),
                                        date: start.addingTimeInterval(Double(index) * 3_600 + 60))
        }
        for search in ["", "work"] {
            let query = JournalRepository.EntryQuery(search: search, theme: .work)
            let first = try repository.entries(matching: query, page: .init(offset: 0, limit: 3))
            let second = try repository.entries(matching: query, page: .init(offset: first.nextOffset, limit: 10))
            #expect(first.totalCount == 7 && first.hasMore && !second.hasMore)
            #expect((first.records + second.records).map(\.text) == (0..<7).reversed().map { "Work \($0)" })
        }
    }

    /// Two devices wrote the same day offline (`design/journal.md` section
    /// 6). The list hides the versions that are not the day's primary, and
    /// a search still finds them.
    @Test func versionsOfADayAreFoundAndHiddenFromTheUnfilteredList() throws {
        let repository = try repository()
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let day = CivilDay(date: date)
        _ = try repository.saveAnswer(text: "Answer from phone", prompt: "Question", day: day, date: date)
        _ = try repository.saveAnswer(text: "Answer from iPad", prompt: "Question", day: day, date: date.addingTimeInterval(60))
        _ = try repository.saveAnswer(text: "Answer next day", prompt: "Question", day: day.next, date: day.next.start)
        _ = try repository.saveRetro(wentWell: "Retro from phone", improve: "", tomorrow: "", day: day, date: date)
        _ = try repository.saveRetro(wentWell: "Retro from iPad", improve: "", tomorrow: "", day: day, date: date.addingTimeInterval(60))
        _ = try repository.saveNote(text: "Note the same day", date: date)
        let answer = try #require(try repository.answer(for: day))
        let retro = try #require(try repository.retro(for: day))

        let versions = try repository.versionRecordIDs()

        #expect(versions == Set((answer.variants.map(\.recordID) + retro.variants.map(\.recordID)).compactMap { $0 }))
        #expect(versions.count == 2)
        let entries = try repository.entries(matching: .init(excluding: versions))
        #expect(entries.totalCount == 3)
        #expect(Set(entries.records.map(\.text)) == [answer.primary.text, "Answer next day", "Note the same day"])
        #expect(try retroTexts(repository, .init(excluding: versions)) == [retro.primary.wentWell])
        #expect(try texts(repository, .init(search: "answer from")) == ["Answer from phone", "Answer from iPad"])
    }

    /// The grouping reads columns, not the writing, so it has to agree with
    /// the per-day selection on every shape of record: a stamped answer, a
    /// legacy answer with no stored day, and a weekly review from two
    /// devices.
    @Test func versionsGroupLegacyRowsAndWeeklyReviewsLikeTheSelections() throws {
        let repository = try repository()
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let day = CivilDay(date: date)
        _ = try repository.saveAnswer(text: "Stamped answer", prompt: "Question", day: day, date: date.addingTimeInterval(60))
        let legacy = JournalEntry(date: date, prompt: "Question", text: "Legacy answer", kind: JournalEntry.kindQuestion)
        legacy.civilDay = nil
        legacy.timeZoneIdentifier = nil
        container.mainContext.insert(legacy)
        try container.mainContext.save()
        let weekStart = day.start
        _ = try repository.saveWeeklyReview(text: "Review from phone", nextIntention: nil, weekStart: weekStart)
        _ = try repository.saveWeeklyReview(text: "Review from iPad", nextIntention: nil, weekStart: weekStart)
        _ = try repository.saveWeeklyReview(text: "Review next week", nextIntention: nil, weekStart: weekStart.addingTimeInterval(7 * 86_400))
        _ = try repository.saveRetro(wentWell: "Only retro", improve: "", tomorrow: "", day: day.next, date: day.next.start)

        let versions = try repository.versionRecordIDs()

        let answer = try #require(try repository.answer(for: day))
        let review = try #require(try repository.weeklyReview(weekStart: weekStart))
        #expect(answer.variants.count == 1)
        #expect(review.variants.count == 1)
        #expect(versions == Set((answer.variants + review.variants).compactMap(\.recordID)))
        #expect(versions.count == 2)
    }

    @Test func aJournalOfSingleRecordsHasNoVersions() throws {
        let repository = try repository()
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        _ = try repository.saveAnswer(text: "Answer", prompt: "Question", day: CivilDay(date: date), date: date)
        _ = try repository.saveRetro(wentWell: "Retro", improve: "", tomorrow: "", day: CivilDay(date: date), date: date)
        _ = try repository.saveNote(text: "Note", date: date)
        _ = try repository.saveNote(text: "Another note", date: date)

        #expect(try repository.versionRecordIDs().isEmpty)
    }

    @Test func reportsWhetherAnythingOrAKindWasWritten() throws {
        let repository = try repository()
        #expect(try !repository.hasRecords())
        _ = try repository.saveRetro(wentWell: "Retro", improve: "", tomorrow: "")
        #expect(try repository.hasRecords())
        #expect(try !repository.hasRecords(kind: JournalEntry.kindFocus))
        _ = try repository.saveFocusNote(text: "Focus", intention: "Write", sessionID: "session")
        #expect(try repository.hasRecords(kind: JournalEntry.kindFocus))
    }
}
