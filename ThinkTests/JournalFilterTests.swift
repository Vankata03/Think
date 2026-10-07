import Foundation
import Testing
@testable import Think

/// The filter menu's state (`design/journal.md` section 3) and how it
/// becomes repository queries.
@MainActor struct JournalFilterTests {
    private let versions: Set<UUID> = [UUID()]

    @Test func noFilterListsPrimariesOfBothTables() throws {
        let filter = JournalFilter()
        let (entries, retros) = filter.queries(search: "", versions: versions)

        #expect(!filter.isActive)
        #expect(try #require(entries).excluding == versions)
        #expect(try #require(retros).excluding == versions)
    }

    @Test func searchOrAnyFilterAlsoFindsVersions() throws {
        let searched = JournalFilter().queries(search: "river", versions: versions)
        #expect(try #require(searched.entries).excluding.isEmpty && #require(searched.entries).search == "river")
        #expect(try #require(searched.retros).excluding.isEmpty)

        var filter = JournalFilter()
        filter.date = .today
        #expect(try #require(filter.queries(search: "", versions: versions).entries).excluding.isEmpty)
    }

    @Test func kindPicksOneTable() throws {
        var filter = JournalFilter()
        filter.kind = .retros
        #expect(filter.queries(search: "", versions: []).entries == nil)
        #expect(filter.queries(search: "", versions: []).retros != nil)

        let expected: [(JournalFilter.Kind, String)] = [
            (.answers, JournalEntry.kindQuestion), (.notes, JournalEntry.kindNote),
            (.weeklyReviews, JournalEntry.kindWeeklyReview), (.focusNotes, JournalEntry.kindFocus),
        ]
        for (kind, stored) in expected {
            filter.kind = kind
            let queries = filter.queries(search: "", versions: [])
            #expect(try #require(queries.entries).kind == stored)
            #expect(queries.retros == nil)
        }
    }

    @Test func moodThemeAndDateReachBothTables() throws {
        var filter = JournalFilter()
        filter.mood = .noMood
        filter.theme = .health
        filter.date = .last7Days
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let today = CivilDay(date: now)
        let (entries, retros) = filter.queries(search: "", versions: [], now: now)

        for query in [try #require(entries).mood, try #require(retros).mood] { #expect(query == .untagged) }
        #expect(entries?.theme == .health && retros?.theme == .health)
        let week = DateInterval(start: today.adding(days: -6).start, end: today.next.start)
        #expect(entries?.dateRange == week && retros?.dateRange == week)

        filter.mood = .mood(.good)
        #expect(filter.queries(search: "", versions: []).entries?.mood == .tagged(.good))
    }

    @Test func summaryNamesEveryFilterThatIsOn() {
        var filter = JournalFilter()
        filter.kind = .answers
        filter.date = .last7Days
        #expect(filter.summary == "\(String(localized: "Answers")) · \(String(localized: "Last 7 days"))")

        filter.mood = .noMood
        filter.theme = .work
        #expect(filter.summary == [String(localized: "Answers"), String(localized: "No mood"), Theme.work.label,
                                   String(localized: "Last 7 days")].joined(separator: " · "))

        filter.clear()
        #expect(!filter.isActive && filter.summary.isEmpty)
    }
}
