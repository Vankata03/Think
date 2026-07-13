//
//  SyncPayloads.swift
//  Think
//

import Foundation

nonisolated enum SyncContextKey {
    static let schemaVersion = "schemaVersion"
    static let timer = "timer"
    static let progressSnapshot = "progressSnapshot"
    static let focusSessionEvent = "focusSessionEvent"
}

nonisolated enum SyncSchema {
    static let currentVersion = 1
}

/// A last-writer-wins tag for timer mutations.
nonisolated struct Revision: Codable, Comparable, Equatable, Sendable {
    let date: Date
    let deviceID: UUID

    init(date: Date, deviceID: UUID) {
        let milliseconds = (date.timeIntervalSince1970 * 1_000).rounded()
        self.date = Date(timeIntervalSince1970: milliseconds / 1_000)
        self.deviceID = deviceID
    }

    private enum CodingKeys: String, CodingKey {
        case date
        case deviceID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            date: try container.decode(Date.self, forKey: .date),
            deviceID: try container.decode(UUID.self, forKey: .deviceID)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(deviceID, forKey: .deviceID)
    }

    static func < (lhs: Revision, rhs: Revision) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date < rhs.date
        }
        return lhs.deviceID.uuidString < rhs.deviceID.uuidString
    }
}

/// Complete pomodoro state. Running countdowns derive from `endDate`.
nonisolated struct TimerSyncState: Codable, Equatable, Sendable {
    let workMinutes: Int
    let restMinutes: Int
    let isCustomPreset: Bool?
    let phase: String
    let isRunning: Bool
    let endDate: Date?
    let remainingSeconds: Int
    let revision: Revision

    init(
        workMinutes: Int,
        restMinutes: Int,
        isCustomPreset: Bool? = nil,
        phase: String,
        isRunning: Bool,
        endDate: Date?,
        remainingSeconds: Int,
        revision: Revision
    ) {
        self.workMinutes = workMinutes
        self.restMinutes = restMinutes
        self.isCustomPreset = isCustomPreset
        self.phase = phase
        self.isRunning = isRunning
        self.endDate = endDate
        self.remainingSeconds = remainingSeconds
        self.revision = revision
    }

    private enum CodingKeys: String, CodingKey {
        case workMinutes
        case restMinutes
        case isCustomPreset
        case phase
        case isRunning
        case endDate
        case remainingSeconds
        case revision
    }
}

/// One completed work phase, recorded on the watch and delivered to the phone.
nonisolated struct FocusSessionEvent: Codable, Equatable, Sendable {
    let id: String
    let completedAt: Date

    init(id: String, completedAt: Date) {
        self.id = id
        self.completedAt = completedAt
    }

    init(endDate: Date) {
        self.init(id: Self.id(for: endDate), completedAt: endDate)
    }

    static func id(for endDate: Date) -> String {
        let milliseconds = (endDate.timeIntervalSince1970 * 1_000).rounded()
        let normalized = Date(timeIntervalSince1970: milliseconds / 1_000)
        return SyncDateCoding.string(from: normalized)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case completedAt
    }
}

/// Phone-owned progress, replicated to the watch.
nonisolated struct ProgressSnapshot: Codable, Equatable, Sendable {
    let streak: Int
    let lastCompletedDay: Date?
    let completedDays: [Date]
    let pathCompletedDays: Int
    let lastPathCompletionDay: Date?
    let totalFocusSessions: Int
    let focusSessionDay: Date?
    let focusSessionDayCount: Int
    let lastOpenDay: Date?
    let appliedEventIDs: [String]
    let publishedAt: Date

    private enum CodingKeys: String, CodingKey {
        case streak
        case lastCompletedDay
        case completedDays
        case pathCompletedDays
        case lastPathCompletionDay
        case totalFocusSessions
        case focusSessionDay
        case focusSessionDayCount
        case lastOpenDay
        case appliedEventIDs
        case publishedAt
    }
}

/// Shared by payload IDs and the JSON codec. Wire dates always use UTC and
/// exactly three fractional digits so both devices derive identical event IDs.
nonisolated enum SyncDateCoding {
    static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return formatter.string(from: date)
    }

    static func date(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return formatter.date(from: string)
    }
}
