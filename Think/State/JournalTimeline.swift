//
//  JournalTimeline.swift
//  Think
//

import Foundation

/// The Journal list's run of day sections (`design/journal.md` section 2).
///
/// Entries and retros are separate tables, each read in bounded repository
/// pages. A record is shown only once no unloaded record of the other
/// table can sort above it, so "Load more" only ever appends: a later page
/// never inserts a row above what is already on screen.
struct JournalTimeline {
    enum Record: Identifiable {
        case entry(JournalRepository.EntrySnapshot)
        case retro(JournalRepository.RetroSnapshot)

        var id: String {
            switch self {
            case .entry(let value): "entry-\(value.recordID?.uuidString ?? String(describing: value.persistentModelID))"
            case .retro(let value): "retro-\(value.recordID?.uuidString ?? String(describing: value.persistentModelID))"
            }
        }

        var date: Date {
            switch self {
            case .entry(let value): value.date
            case .retro(let value): value.date
            }
        }

        var recordID: UUID? {
            switch self {
            case .entry(let value): value.recordID
            case .retro(let value): value.recordID
            }
        }

        /// The stored civil day; rows from before identity capture fall
        /// back to their timestamp.
        var day: CivilDay {
            switch self {
            case .entry(let value): value.day
            case .retro(let value): value.day
            }
        }
    }

    struct Day: Identifiable {
        let day: CivilDay
        let records: [Record]
        var id: String { day.key }
    }

    /// One table's pages. A nil query leaves that table out.
    private struct Stream<Query, Snapshot> {
        let query: Query?
        var records: [Snapshot] = []
        var offset = 0
        var hasMore: Bool

        init(query: Query?) {
            self.query = query
            hasMore = query != nil
        }
    }

    private var entries: Stream<JournalRepository.EntryQuery, JournalRepository.EntrySnapshot>
    private var retros: Stream<JournalRepository.RetroQuery, JournalRepository.RetroSnapshot>
    private var loaded = false
    let pageSize: Int
    private(set) var days: [Day] = []

    init(entries: JournalRepository.EntryQuery?, retros: JournalRepository.RetroQuery?, pageSize: Int = 50) {
        self.entries = Stream(query: entries)
        self.retros = Stream(query: retros)
        self.pageSize = pageSize
    }

    var hasMore: Bool { entries.hasMore || retros.hasMore }
    var isEmpty: Bool { days.isEmpty }

    /// Reads the first page of each table, then, on every later call, the
    /// next page of whichever table holds back what is shown.
    mutating func loadMore(from repository: JournalRepository) throws {
        let cutoff = self.cutoff
        let first = !loaded
        if let query = entries.query, entries.hasMore, first || entries.records.last?.date == cutoff {
            let page = try repository.entries(matching: query, page: .init(offset: entries.offset, limit: pageSize))
            entries.records += page.records; entries.offset = page.nextOffset; entries.hasMore = page.hasMore
        }
        if let query = retros.query, retros.hasMore, first || retros.records.last?.date == cutoff {
            let page = try repository.retros(matching: query, page: .init(offset: retros.offset, limit: pageSize))
            retros.records += page.records; retros.offset = page.nextOffset; retros.hasMore = page.hasMore
        }
        loaded = true
        days = Self.group(visible)
    }

    /// The oldest date that can be shown: the last loaded date of every
    /// table that still has pages, whichever is newest.
    private var cutoff: Date? {
        [entries.hasMore ? entries.records.last?.date : nil, retros.hasMore ? retros.records.last?.date : nil]
            .compactMap { $0 }.max()
    }

    private var visible: [Record] {
        let all = entries.records.map(Record.entry) + retros.records.map(Record.retro)
        guard let cutoff else { return all }
        return all.filter { $0.date >= cutoff }
    }

    private static func group(_ records: [Record]) -> [Day] {
        Dictionary(grouping: records, by: \.day.key)
            .map { key, records in
                let sorted = records.sorted { $0.date != $1.date ? $0.date > $1.date : $0.id < $1.id }
                return Day(day: sorted[0].day, records: sorted)
            }
            .sorted { $0.day.key > $1.day.key }
    }

    /// "Today", "Yesterday", then the full weekday and date. The year is
    /// added only for a day outside the current year.
    static func title(for day: CivilDay, today: CivilDay = .today()) -> String {
        if day.key == today.key { return String(localized: "Today") }
        if day.key == today.previous.key { return String(localized: "Yesterday") }
        return fullDate(day, today: today)
    }

    /// The full weekday and date of a civil day ("Thursday 24 September"),
    /// with the year only outside the current year. Never the stored key.
    static func fullDate(_ day: CivilDay, today: CivilDay = .today()) -> String {
        var style = Date.FormatStyle.dateTime.weekday(.wide).day().month(.wide)
        if day.components.year != today.components.year { style = style.year() }
        style.timeZone = day.timeZone
        return day.start.formatted(style)
    }
}
