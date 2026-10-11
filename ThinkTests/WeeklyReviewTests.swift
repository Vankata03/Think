import Foundation
import SwiftData
import Testing
@testable import Think

/// What the weekly review reads for its private sections
/// (`design/progress-settings.md` section 9): nothing while the journal is
/// locked; otherwise the week's activity and the reflection's state.
@MainActor struct WeeklyReviewTests {
    private let sofia = TimeZone(identifier: "Europe/Sofia")!
    private func repository() throws -> JournalRepository {
        let container = try ModelContainer(for: JournalDataStore.schema, configurations: JournalDataStore.configuration(for: .inMemory))
        return JournalRepository(modelContext: container.mainContext, storage: .inMemory)
    }
    /// Saturday 26 September 2026, 21:00 in Sofia: ISO week 39.
    private var saturday: Date { CivilDay(year: 2026, month: 9, day: 26, timeZoneIdentifier: "Europe/Sofia").start.addingTimeInterval(21 * 3_600) }

    @Test func theWeekRunsMondayToSundayInItsZone() {
        let week = WeeklyReviewWeek(containing: saturday, timeZone: sofia)
        #expect(week.start == CivilDay(year: 2026, month: 9, day: 21, timeZoneIdentifier: "Europe/Sofia"))
        #expect(week.interval.duration == 7 * 86_400)
        let sunday = CivilDay(year: 2026, month: 9, day: 27, timeZoneIdentifier: "Europe/Sofia").start.addingTimeInterval(23 * 3_600)
        #expect(WeeklyReviewWeek(containing: sunday, timeZone: sofia).start == week.start)
    }

    @Test func aLockedJournalReadsNothingPrivate() throws {
        let repository = try repository()
        let week = WeeklyReviewWeek(containing: saturday, timeZone: sofia)
        _ = try repository.saveWeeklyReview(text: "Private reflection", nextIntention: nil, weekStart: week.start.start, timeZone: sofia)
        _ = try repository.saveNote(text: "Private note", mood: .good, day: week.start, date: saturday)

        let journal = WeeklyReviewJournal.load(week: week, locked: true, repository: repository)
        #expect(journal.reflection == .locked)
        #expect(journal.activity == nil)
    }

    @Test func aZeroWeekHasZeroCountsAndAWritableReflection() throws {
        let journal = WeeklyReviewJournal.load(week: WeeklyReviewWeek(containing: saturday, timeZone: sofia), locked: false,
                                               repository: try repository())
        #expect(journal.reflection == .notWritten)
        let activity = try #require(journal.activity)
        #expect(activity.answers == 0 && activity.notes == 0 && activity.retros == 0 && activity.untaggedCount == 0)
    }

    @Test func aSavedReviewIsTheWeeksReflection() throws {
        let repository = try repository()
        let week = WeeklyReviewWeek(containing: saturday, timeZone: sofia)
        let lastWeek = WeeklyReviewWeek(containing: saturday.addingTimeInterval(-7 * 86_400), timeZone: sofia)
        _ = try repository.saveWeeklyReview(text: "Last week", nextIntention: nil, weekStart: lastWeek.start.start, timeZone: sofia)
        #expect(WeeklyReviewJournal.load(week: week, locked: false, repository: repository).reflection == .notWritten)

        let receipt = try repository.saveWeeklyReview(text: "Five of seven days.", nextIntention: nil, weekStart: week.start.start,
                                                      timeZone: sofia)
        _ = try repository.saveNote(text: "A note", mood: .good, day: week.start, date: saturday)
        let journal = WeeklyReviewJournal.load(week: week, locked: false, repository: repository)
        #expect(journal.reflection == .saved(receipt.recordID))
        #expect(journal.review?.text == "Five of seven days.")
        // The review describes the week; it is not one of its entries.
        #expect(journal.activity?.notes == 1 && journal.activity?.taggedMoodCounts[Mood.good.rawValue] == 1)
    }
}
