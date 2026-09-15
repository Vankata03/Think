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
    var resetBoundary: SyncResetBoundary? = nil
    var sessionID: String? = nil
    var activeSeconds: Double? = nil
    var activeSegmentStart: Date? = nil

    init(
        workMinutes: Int,
        restMinutes: Int,
        isCustomPreset: Bool? = nil,
        phase: String,
        isRunning: Bool,
        endDate: Date?,
        remainingSeconds: Int,
        revision: Revision,
        resetBoundary: SyncResetBoundary? = nil,
        sessionID: String? = nil,
        activeSeconds: Double? = nil,
        activeSegmentStart: Date? = nil
    ) {
        self.workMinutes = workMinutes
        self.restMinutes = restMinutes
        self.isCustomPreset = isCustomPreset
        self.phase = phase
        self.isRunning = isRunning
        self.endDate = endDate
        self.remainingSeconds = remainingSeconds
        self.revision = revision
        self.resetBoundary = resetBoundary
        self.sessionID = sessionID
        self.activeSeconds = activeSeconds
        self.activeSegmentStart = activeSegmentStart
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
        case resetBoundary, sessionID, activeSeconds, activeSegmentStart
    }
}

/// One completed work phase, recorded on the watch and delivered to the phone.
nonisolated struct FocusSessionEvent: Codable, Equatable, Sendable {
    let id: String
    let completedAt: Date
    /// Additive in schema v1. Older queued events decode as nil and still
    /// update aggregate progress, but cannot create fabricated history.
    let durationMinutes: Int?
    var resetBoundary: SyncResetBoundary? = nil
    var actualActiveSeconds: Int? = nil

    init(id: String, completedAt: Date, durationMinutes: Int? = nil, resetBoundary: SyncResetBoundary? = nil, actualActiveSeconds: Int? = nil) {
        self.id = id
        self.completedAt = completedAt
        self.durationMinutes = durationMinutes
        self.resetBoundary = resetBoundary
        self.actualActiveSeconds = actualActiveSeconds
    }

    init(endDate: Date, durationMinutes: Int? = nil) {
        self.init(
            id: Self.id(for: endDate),
            completedAt: endDate,
            durationMinutes: durationMinutes
        )
    }

    var hasValidIdentity: Bool {
        id == Self.id(for: completedAt) || UUID(uuidString: id) != nil
    }

    static func id(for endDate: Date) -> String {
        let milliseconds = (endDate.timeIntervalSince1970 * 1_000).rounded()
        let normalized = Date(timeIntervalSince1970: milliseconds / 1_000)
        return SyncDateCoding.string(from: normalized)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case completedAt
        case durationMinutes
        case resetBoundary, actualActiveSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
        resetBoundary = try container.decodeIfPresent(SyncResetBoundary.self, forKey: .resetBoundary)
        actualActiveSeconds = try container.decodeIfPresent(Int.self, forKey: .actualActiveSeconds)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(durationMinutes, forKey: .durationMinutes)
        try container.encodeIfPresent(resetBoundary, forKey: .resetBoundary)
        try container.encodeIfPresent(actualActiveSeconds, forKey: .actualActiveSeconds)
    }
}

/// Phone-owned scalar progress, replicated to the watch. Focus-duration
/// history stays phone-local; watch completions carry duration in their event.
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
    let lastQuestionAnswerDay: Date?
    let appliedEventIDs: [String]
    let publishedAt: Date
    var resetBoundary: SyncResetBoundary? = nil
    var practiceActivities: [PracticeActivity]? = nil

    init(
        streak: Int,
        lastCompletedDay: Date?,
        completedDays: [Date],
        pathCompletedDays: Int,
        lastPathCompletionDay: Date?,
        totalFocusSessions: Int,
        focusSessionDay: Date?,
        focusSessionDayCount: Int,
        lastOpenDay: Date?,
        lastQuestionAnswerDay: Date? = nil,
        appliedEventIDs: [String],
        publishedAt: Date,
        resetBoundary: SyncResetBoundary? = nil,
        practiceActivities: [PracticeActivity]? = nil
    ) {
        self.streak = streak
        self.lastCompletedDay = lastCompletedDay
        self.completedDays = completedDays
        self.pathCompletedDays = pathCompletedDays
        self.lastPathCompletionDay = lastPathCompletionDay
        self.totalFocusSessions = totalFocusSessions
        self.focusSessionDay = focusSessionDay
        self.focusSessionDayCount = focusSessionDayCount
        self.lastOpenDay = lastOpenDay
        self.lastQuestionAnswerDay = lastQuestionAnswerDay
        self.appliedEventIDs = appliedEventIDs
        self.publishedAt = publishedAt
        self.resetBoundary = resetBoundary
        self.practiceActivities = practiceActivities
    }

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
        case lastQuestionAnswerDay
        case appliedEventIDs
        case publishedAt
        case resetBoundary, practiceActivities
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
