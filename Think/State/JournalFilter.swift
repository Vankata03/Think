//
//  JournalFilter.swift
//  Think
//

import Foundation

/// What the Journal list's filter menu has chosen (`design/journal.md`
/// section 3): one kind, one mood, one theme and one date range.
struct JournalFilter: Hashable {
    enum Kind: CaseIterable, Hashable {
        case all, answers, notes, retros, weeklyReviews, focusNotes

        var label: String {
            switch self {
            case .all: String(localized: "All")
            case .answers: String(localized: "Answers")
            case .notes: String(localized: "Notes")
            case .retros: String(localized: "Retros")
            case .weeklyReviews: String(localized: "Weekly reviews")
            case .focusNotes: String(localized: "Focus notes")
            }
        }

        /// The kind of row this option keeps; nil for "All".
        var rowKind: JournalRowContent.Kind? {
            switch self {
            case .all: nil
            case .answers: .answer
            case .notes: .note
            case .retros: .retro
            case .weeklyReviews: .weeklyReview
            case .focusNotes: .focusNote
            }
        }

        /// The row badge's symbol; "All" has none.
        var symbol: String? { rowKind?.symbol }

        /// The stored `JournalEntry.kind`, or nil for every entry kind.
        fileprivate var entryKind: String? {
            switch self {
            case .all, .retros: nil
            case .answers: JournalEntry.kindQuestion
            case .notes: JournalEntry.kindNote
            case .weeklyReviews: JournalEntry.kindWeeklyReview
            case .focusNotes: JournalEntry.kindFocus
            }
        }
    }

    enum MoodChoice: Hashable {
        case any
        case noMood
        case mood(Mood)

        static var allCases: [MoodChoice] { [.any, .noMood] + Mood.allCases.map(MoodChoice.mood) }

        var label: String {
            switch self {
            case .any: String(localized: "Any mood")
            case .noMood: String(localized: "No mood")
            case .mood(let mood): mood.label
            }
        }

        fileprivate var filter: JournalRepository.MoodFilter {
            switch self {
            case .any: .all
            case .noMood: .untagged
            case .mood(let mood): .tagged(mood)
            }
        }
    }

    enum DateRange: CaseIterable, Hashable {
        case any, today, last7Days, last30Days

        var label: String {
            switch self {
            case .any: String(localized: "Any time")
            case .today: String(localized: "Today")
            case .last7Days: String(localized: "Last 7 days")
            case .last30Days: String(localized: "Last 30 days")
            }
        }

        fileprivate func interval(now: Date) -> DateInterval? {
            let today = CivilDay.today(now: now)
            switch self {
            case .any: return nil
            case .today: return today.interval
            case .last7Days: return DateInterval(start: today.adding(days: -6).start, end: today.next.start)
            case .last30Days: return DateInterval(start: today.adding(days: -29).start, end: today.next.start)
            }
        }
    }

    var kind = Kind.all
    var mood = MoodChoice.any
    /// Matches the primary or the secondary theme.
    var theme: Theme?
    var date = DateRange.any

    var isActive: Bool { self != JournalFilter() }

    /// The active filters line: the name of each filter that is on, joined
    /// by " · ". Empty while no filter is on.
    var summary: String {
        [
            kind == .all ? nil : kind.label,
            mood == .any ? nil : mood.label,
            theme?.label,
            date == .any ? nil : date.label,
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    mutating func clear() { self = JournalFilter() }

    /// The repository queries for this filter and a search. A nil query
    /// leaves that table out. The unfiltered list shows each day's primary
    /// only; a search or any filter also finds the other versions
    /// (`design/journal.md` section 6).
    func queries(search: String, versions: Set<UUID>, now: Date = .now)
        -> (entries: JournalRepository.EntryQuery?, retros: JournalRepository.RetroQuery?) {
        let excluding = isActive || !search.isEmpty ? [] : versions
        let range = date.interval(now: now)
        let entries = kind == .retros ? nil : JournalRepository.EntryQuery(
            search: search, kind: kind.entryKind, mood: mood.filter, theme: theme, dateRange: range, excluding: excluding)
        let retros = kind == .all || kind == .retros ? JournalRepository.RetroQuery(
            search: search, mood: mood.filter, theme: theme, dateRange: range, excluding: excluding) : nil
        return (entries, retros)
    }
}
