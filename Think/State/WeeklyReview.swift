//
//  WeeklyReview.swift
//  Think
//

import Foundation

/// The ISO week the weekly review covers, Monday to Sunday in the zone it
/// is reviewed in.
nonisolated struct WeeklyReviewWeek: Equatable {
    /// The civil day the week starts on.
    let start: CivilDay
    let interval: DateInterval

    init(containing date: Date = .now, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone
        let first = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 7, to: first) ?? first
        start = CivilDay(date: first, timeZone: timeZone)
        interval = DateInterval(start: first, end: end)
    }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = start.timeZone
        return calendar
    }
}

/// The private half of the weekly review: the week's journal activity and
/// the state of its reflection (`design/progress-settings.md` section 9.1).
/// Nothing is read while the journal is locked.
@MainActor
struct WeeklyReviewJournal {
    enum Reflection: Equatable {
        case locked
        case unavailable
        /// The week's review; nil identity only for a row that predates
        /// record identities.
        case saved(UUID?)
        case notWritten
    }

    var reflection: Reflection
    var activity: JournalRepository.ActivitySummary?
    var review: JournalRepository.EntrySnapshot?

    static func load(week: WeeklyReviewWeek, locked: Bool, repository: JournalRepository) -> WeeklyReviewJournal {
        guard !locked else { return WeeklyReviewJournal(reflection: .locked) }
        do {
            let activity = try repository.activitySummary(in: week.interval)
            let review = try repository.weeklyReview(weekStart: week.start.start, timeZone: week.start.timeZone)?.primary
            return WeeklyReviewJournal(
                reflection: review.map { .saved($0.recordID) } ?? .notWritten,
                activity: activity, review: review)
        } catch {
            return WeeklyReviewJournal(reflection: .unavailable)
        }
    }
}
