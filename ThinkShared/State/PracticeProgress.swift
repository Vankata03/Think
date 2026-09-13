import Foundation

/// Named evidence of practice. Merely opening the app is never evidence.
nonisolated enum PracticeActivityKind: String, Codable, CaseIterable, Sendable {
    case answer, note, retro, move, path, focus
}

nonisolated struct PracticeActivity: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let kind: PracticeActivityKind
    let date: Date
}

nonisolated struct PathStepCompletion: Codable, Equatable, Sendable {
    let step: Int
    let date: Date
}

nonisolated struct PathRunProgress: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let pathID: String
    let totalSteps: Int
    let startedAt: Date?
    /// Legacy count has no invented dates. New completions carry dates below.
    var legacyCompletedSteps: Int
    var completions: [PathStepCompletion]
    var completedSteps: Int { min(totalSteps, legacyCompletedSteps + completions.count) }
    var isComplete: Bool { totalSteps > 0 && completedSteps >= totalSteps }
    var lastCompletionDate: Date? { completions.last?.date }
}

nonisolated struct WeeklyPracticeDay: Equatable, Sendable {
    let date: Date
    var practiced = false
    var activities: Set<PracticeActivityKind> = []
    var completedSessions = 0
    var completedMinutes = 0
    var completedActiveSeconds = 0
    var partialActiveSeconds = 0
    var unknownActualDurationSessions = 0
}

nonisolated struct WeeklyPracticeSummary: Equatable, Sendable {
    let interval: DateInterval
    let days: [WeeklyPracticeDay]
    let focusHistoryRetentionDays: Int
    var practiceDays: Int { days.filter(\.practiced).count }
    var completedSessions: Int { days.reduce(0) { $0 + $1.completedSessions } }
    /// Planned minutes for completed sessions; actual effort is separate.
    var completedMinutes: Int { days.reduce(0) { $0 + $1.completedMinutes } }
    var completedActiveSeconds: Int { days.reduce(0) { $0 + $1.completedActiveSeconds } }
    var partialActiveSeconds: Int { days.reduce(0) { $0 + $1.partialActiveSeconds } }
    var unknownActualDurationSessions: Int { days.reduce(0) { $0 + $1.unknownActualDurationSessions } }
}

/// A deletion barrier, replicated by the canonical phone. Nil means legacy era.
/// A device must receive the new barrier before its work can be accepted again.
nonisolated struct SyncResetBoundary: Codable, Equatable, Sendable {
    let id: UUID
    let date: Date
    init(id: UUID = UUID(), date: Date) { self.id = id; self.date = date }
}
