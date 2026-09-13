//
//  JournalIdentity.swift
//  Think
//

import Foundation

/// The local calendar day a journal record belongs to, captured when the
/// record is written rather than recomputed from its timestamp later.
///
/// A daily answer written at 23:50 in Sofia and read back after a flight
/// to New York must still count as that Sofia day, and two devices that
/// both wrote "today's" answer offline must agree on which day it was.
/// The key is a Gregorian `yyyy-MM-dd` in the time zone that was current
/// at capture, which keeps it comparable across devices whose user
/// calendars differ.
nonisolated struct CivilDay: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    /// `yyyy-MM-dd` in `timeZoneIdentifier`.
    let key: String
    /// Identifier of the zone the key was computed in, so the day's exact
    /// interval can be rebuilt later even after the device changes zone.
    let timeZoneIdentifier: String

    init(key: String, timeZoneIdentifier: String) {
        self.key = key
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    init(date: Date, timeZone: TimeZone = .current) {
        var calendar = Self.gregorian
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(
            year: components.year ?? 1970,
            month: components.month ?? 1,
            day: components.day ?? 1,
            timeZoneIdentifier: timeZone.identifier
        )
    }

    init(year: Int, month: Int, day: Int, timeZoneIdentifier: String = TimeZone.current.identifier) {
        self.key = String(format: "%04d-%02d-%02d", year, month, day)
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    /// Rebuilds a day from the two strings a model stores. Nil when either
    /// is missing, which is what every row written before identity
    /// capture looks like.
    init?(storedKey: String?, timeZoneIdentifier: String?) {
        guard let storedKey, let timeZoneIdentifier, Self.isValidKey(storedKey) else { return nil }
        self.init(key: storedKey, timeZoneIdentifier: timeZoneIdentifier)
    }

    static func today(now: Date = .now, timeZone: TimeZone = .current) -> CivilDay {
        CivilDay(date: now, timeZone: timeZone)
    }

    /// The zone the key was captured in, or GMT when the identifier no
    /// longer resolves (the interval is then approximate, which only
    /// affects legacy date matching, never the stored key).
    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? TimeZone(secondsFromGMT: 0)!
    }

    var components: (year: Int, month: Int, day: Int) {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return (1970, 1, 1) }
        return (parts[0], parts[1], parts[2])
    }

    /// Start of the day in its own zone. DST transitions are handled by
    /// the calendar, so a 23-hour day still has a correct interval.
    var start: Date {
        var calendar = Self.gregorian
        calendar.timeZone = timeZone
        let (year, month, day) = components
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    /// Half-open interval `[start, next.start)` covering the whole day.
    var interval: DateInterval {
        DateInterval(start: start, end: next.start)
    }

    var next: CivilDay { adding(days: 1) }
    var previous: CivilDay { adding(days: -1) }

    func adding(days: Int) -> CivilDay {
        var calendar = Self.gregorian
        calendar.timeZone = timeZone
        let shifted = calendar.date(byAdding: .day, value: days, to: start) ?? start
        return CivilDay(date: shifted, timeZone: timeZone)
    }

    func contains(_ date: Date) -> Bool {
        interval.contains(date) && date != interval.end
    }

    var description: String { "\(key)@\(timeZoneIdentifier)" }

    /// Keys sort chronologically because they are zero-padded ISO dates.
    static func < (lhs: CivilDay, rhs: CivilDay) -> Bool {
        lhs.key < rhs.key || (lhs.key == rhs.key && lhs.timeZoneIdentifier < rhs.timeZoneIdentifier)
    }

    static func isValidKey(_ key: String) -> Bool {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let month = Int(parts[1]), let day = Int(parts[2]), Int(parts[0]) != nil
        else { return false }
        return (1...12).contains(month) && (1...31).contains(day)
    }

    private static let gregorian = Calendar(identifier: .gregorian)
}

/// The records that claim one logical day: the one to show or edit, plus
/// every other original kept as a conflict variant.
///
/// Two devices writing today's answer offline produce two rows once they
/// sync. Neither is deleted or merged; the selection is deterministic so
/// both devices land on the same primary.
nonisolated struct DailySelection<Record> {
    let primary: Record
    let variants: [Record]

    var all: [Record] { [primary] + variants }
    var hasConflicts: Bool { !variants.isEmpty }
}

nonisolated enum JournalIdentity {
    /// Picks the primary record deterministically: earliest `date` first,
    /// then the smallest record UUID string, then the smallest tiebreak
    /// (used for rows that predate record IDs). Device-independent, so the
    /// same set of rows selects the same primary everywhere.
    static func select<Record>(
        _ records: [Record],
        date: (Record) -> Date,
        recordID: (Record) -> UUID?,
        tiebreak: (Record) -> String = { _ in "" }
    ) -> DailySelection<Record>? {
        guard !records.isEmpty else { return nil }
        let ordered = records.sorted { lhs, rhs in
            let lhsDate = date(lhs)
            let rhsDate = date(rhs)
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            let lhsID = recordID(lhs)?.uuidString ?? ""
            let rhsID = recordID(rhs)?.uuidString ?? ""
            if lhsID != rhsID { return lhsID < rhsID }
            return tiebreak(lhs) < tiebreak(rhs)
        }
        return DailySelection(primary: ordered[0], variants: Array(ordered.dropFirst()))
    }

    /// Whether a stored row belongs to `day`. Rows written with a captured
    /// day compare by key; rows from before identity capture fall back to
    /// their timestamp inside the day's own interval. The fallback is a
    /// read-time interpretation and is never written back.
    static func belongs(
        storedKey: String?,
        date: Date,
        to day: CivilDay
    ) -> Bool {
        if let storedKey {
            return storedKey == day.key
        }
        return day.contains(date)
    }

    /// ISO week key (`yyyy-Www`) for weekly-review drafts, computed in the
    /// given zone with Monday-first ISO weeks so it is stable across
    /// devices with different user calendars.
    static func weekKey(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", components.yearForWeekOfYear ?? 1970, components.weekOfYear ?? 1)
    }
}
