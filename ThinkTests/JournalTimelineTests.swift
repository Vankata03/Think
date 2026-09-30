import Foundation
import SwiftData
import Testing
@testable import Think

/// The Journal list's timeline (`design/journal.md` section 2): entries and
/// retros paged from the repository into one run of day sections.
@MainActor struct JournalTimelineTests {
    private let repository: JournalRepository
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    init() throws {
        let container = try ModelContainer(for: JournalDataStore.schema, configurations: JournalDataStore.configuration(for: .inMemory))
        repository = JournalRepository(modelContext: container.mainContext)
    }

    private func date(daysAgo: Int, hour: Int = 9) -> Date {
        CivilDay(date: start).adding(days: -daysAgo).start.addingTimeInterval(Double(hour) * 3_600)
    }

    private func texts(_ timeline: JournalTimeline) -> [String] {
        timeline.days.flatMap(\.records).map { record in
            switch record {
            case .entry(let entry): entry.text
            case .retro(let retro): retro.wentWell
            }
        }
    }

    @Test func pagingLoadsBeyondTheFirstPageAndStaysOrderedByDay() throws {
        // Notes on even days, retros on odd days, newest first: 0 to 9.
        for daysAgo in stride(from: 0, to: 10, by: 2) {
            _ = try repository.saveNote(text: "Day \(daysAgo)", date: date(daysAgo: daysAgo))
        }
        for daysAgo in stride(from: 1, to: 10, by: 2) {
            let day = CivilDay(date: date(daysAgo: daysAgo))
            _ = try repository.saveRetro(wentWell: "Day \(daysAgo)", improve: "", tomorrow: "", day: day, date: date(daysAgo: daysAgo, hour: 21))
        }
        var timeline = JournalTimeline(entries: .init(), retros: .init(), pageSize: 2)

        try timeline.loadMore(from: repository)
        // Two notes (days 0 and 2) and two retros (days 1 and 3) are loaded,
        // but day 3 waits: a note on day 3 could still be on the next page.
        #expect(texts(timeline) == ["Day 0", "Day 1", "Day 2"])
        #expect(timeline.hasMore)

        var shown = texts(timeline)
        var pages = 1
        while timeline.hasMore {
            try timeline.loadMore(from: repository)
            let next = texts(timeline)
            #expect(Array(next.prefix(shown.count)) == shown, "a later page never inserts above what is shown")
            shown = next
            pages += 1
        }
        #expect(pages > 1)
        #expect(shown == (0..<10).map { "Day \($0)" })
        let keys = timeline.days.map(\.day.key)
        #expect(keys == keys.sorted(by: >))
        #expect(timeline.days.count == 10)
    }

    @Test func recordsOfOneDayShareASectionNewestFirst() throws {
        _ = try repository.saveNote(text: "Morning", date: date(daysAgo: 0, hour: 8))
        _ = try repository.saveNote(text: "Evening", date: date(daysAgo: 0, hour: 20))
        _ = try repository.saveRetro(wentWell: "Retro", improve: "", tomorrow: "",
                                     day: CivilDay(date: date(daysAgo: 0)), date: date(daysAgo: 0, hour: 21))
        var timeline = JournalTimeline(entries: .init(), retros: .init())

        try timeline.loadMore(from: repository)

        #expect(timeline.days.count == 1)
        #expect(texts(timeline) == ["Retro", "Evening", "Morning"])
        #expect(!timeline.hasMore)
    }

    @Test func aMissingStreamIsNeverLoaded() throws {
        _ = try repository.saveNote(text: "Note")
        _ = try repository.saveRetro(wentWell: "Retro", improve: "", tomorrow: "")
        var timeline = JournalTimeline(entries: nil, retros: .init())

        try timeline.loadMore(from: repository)

        #expect(texts(timeline) == ["Retro"])
        #expect(!timeline.isEmpty)
    }

    @Test func dayTitlesNameTodayAndYesterday() {
        let today = CivilDay(date: start)
        #expect(JournalTimeline.title(for: today, today: today) == String(localized: "Today"))
        #expect(JournalTimeline.title(for: today.previous, today: today) == String(localized: "Yesterday"))
        let older = JournalTimeline.title(for: today.adding(days: -3), today: today)
        #expect(older != String(localized: "Today") && older != String(localized: "Yesterday"))
        #expect(!older.contains(today.adding(days: -3).key))
    }
}
