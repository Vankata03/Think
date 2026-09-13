//
//  ProgressStore.swift
//  Think
//

import Foundation
import Observation

nonisolated struct FocusSessionRecord: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let completedAt: Date
    let durationMinutes: Int
    var actualActiveSeconds: Int? = nil
    var isCompleted: Bool = true

    private enum CodingKeys: String, CodingKey { case id, completedAt, durationMinutes, actualActiveSeconds, isCompleted }
    init(id: String, completedAt: Date, durationMinutes: Int, actualActiveSeconds: Int? = nil, isCompleted: Bool = true) {
        self.id = id; self.completedAt = completedAt; self.durationMinutes = durationMinutes
        self.actualActiveSeconds = actualActiveSeconds; self.isCompleted = isCompleted
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        completedAt = try c.decode(Date.self, forKey: .completedAt)
        durationMinutes = try c.decode(Int.self, forKey: .durationMinutes)
        actualActiveSeconds = try c.decodeIfPresent(Int.self, forKey: .actualActiveSeconds)
        isCompleted = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? true
    }
}

nonisolated struct FocusHistoryDay: Codable, Equatable, Sendable {
    let day: Date
    let sessions: [FocusSessionRecord]
}

nonisolated enum StreakMilestone: Int, CaseIterable, Identifiable, Sendable {
    case seven = 7
    case twentyOne = 21
    case oneHundred = 100

    var id: Int { rawValue }
}

nonisolated enum ProgressAchievement: Hashable, Identifiable, Sendable {
    case streak(StreakMilestone)
    case path(Int)
    case focus(Int)

    static let streakMilestones = StreakMilestone.allCases.map(Self.streak)
    static let pathMilestones = [Self.path(1)]
    static let focusMilestones = [1, 10, 50, 100].map(Self.focus)
    static let all = streakMilestones + pathMilestones + focusMilestones

    var id: String {
        switch self {
        case .streak(let milestone): "streak-\(milestone.rawValue)"
        case .path(let target): "path-\(target)"
        case .focus(let target): "focus-\(target)"
        }
    }

    var target: Int {
        switch self {
        case .streak(let milestone): milestone.rawValue
        case .path(let target), .focus(let target): target
        }
    }
}

enum ProgressMutation: Sendable {
    case markTodayComplete
    case recordAppOpen
    case recordDailyQuestionAnswer
    case completePathStep
    case recordFocusSession
    case reset
    case activityChanged
    case pathRunChanged
    case partialFocusSession
}

/// Streak, focus-session, and path progress. Backed by UserDefaults —
/// small scalar state that doesn't warrant SwiftData.
@MainActor
@Observable
final class ProgressStore {

    private nonisolated enum Key {
        static let activities = "practice.activities.v1"
        static let pathRuns = "practice.pathRuns.v1"
        static let seenFocusIDs = "practice.seenFocusIDs.v1"
        static let legacyDays = "practice.legacyDays.v1"
        static let appliedSnapshotDate = "practice.appliedSnapshotDate"
        static let streak = "streak"
        static let lastCompletedDay = "lastCompletedDay"
        static let pathCompletedDays = "pathCompletedDays"
        static let lastPathCompletionDay = "lastPathCompletionDay"
        static let totalFocusSessions = "totalFocusSessions"
        static let focusSessionDay = "focusSessionDay"
        static let focusSessionDayCount = "focusSessionDayCount"
        static let focusHistory = "focusHistory"
        static let completedDays = "completedDays"
        static let lastOpenDay = "lastOpenDay"
        static let lastQuestionAnswerDay = "lastQuestionAnswerDay"
        static let earnedStreakMilestones = "earnedStreakMilestones"
    }

    /// Every key this store persists, for migrating between defaults suites.
    nonisolated static let persistedKeys: [String] = [
        Key.activities, Key.pathRuns, Key.seenFocusIDs, Key.legacyDays, Key.appliedSnapshotDate,
        Key.streak,
        Key.lastCompletedDay,
        Key.pathCompletedDays,
        Key.lastPathCompletionDay,
        Key.totalFocusSessions,
        Key.focusSessionDay,
        Key.focusSessionDayCount,
        Key.focusHistory,
        Key.completedDays,
        Key.lastOpenDay,
        Key.lastQuestionAnswerDay,
        Key.earnedStreakMilestones,
    ]

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date
    private static let focusHistoryRetentionDays = 365
    private(set) var practiceActivities: [PracticeActivity] = []
    private(set) var pathRuns: [PathRunProgress] = []
    private var seenFocusIDs: Set<String> = []
    private var legacyDays: Set<Date> = []
    var resetBoundary: SyncResetBoundary? { SharedDefaults.resetBoundary(in: defaults) }
    var latestAppliedSnapshotDate: Date { defaults.object(forKey: Key.appliedSnapshotDate) as? Date ?? .distantPast }

    private(set) var streak: Int
    private(set) var lastCompletedDay: Date?
    private(set) var pathCompletedDays: Int
    private(set) var lastPathCompletionDay: Date?
    private(set) var totalFocusSessions: Int
    private var focusSessionDay: Date?
    private var focusSessionDayCount: Int
    /// Completed focus phases grouped by their local calendar day. History is
    /// intentionally bounded; existing aggregate counters remain all-time.
    private(set) var focusHistoryByDay: [Date: [FocusSessionRecord]]
    /// Start-of-day dates for every completed practice day, for the
    /// streak calendar. Grows one entry per day at most.
    private(set) var completedDays: Set<Date>
    private var lastOpenDay: Date?
    private(set) var lastQuestionAnswerDay: Date?
    private(set) var earnedStreakMilestones: Set<StreakMilestone>

    /// Called after a successful local mutation. Snapshot application does
    /// not invoke this callback.
    var onMutation: (@MainActor (ProgressMutation) -> Void)?

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { .now }
    ) {
        let storedStreak = defaults.integer(forKey: Key.streak)
        let storedLastCompletedDay = defaults.object(forKey: Key.lastCompletedDay) as? Date
        let hasStoredMilestoneAwards = defaults.object(forKey: Key.earnedStreakMilestones) != nil

        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        streak = storedStreak
        lastCompletedDay = storedLastCompletedDay.map { calendar.startOfDay(for: $0) }
        pathCompletedDays = defaults.integer(forKey: Key.pathCompletedDays)
        lastPathCompletionDay = defaults.object(forKey: Key.lastPathCompletionDay) as? Date
        totalFocusSessions = defaults.integer(forKey: Key.totalFocusSessions)
        focusSessionDay = defaults.object(forKey: Key.focusSessionDay) as? Date
        focusSessionDayCount = defaults.integer(forKey: Key.focusSessionDayCount)
        if let data = defaults.data(forKey: Key.focusHistory),
           let days = try? SyncCodec.decode([FocusHistoryDay].self, from: data) {
            focusHistoryByDay = Dictionary(grouping: days.flatMap(\.sessions)) { session in
                calendar.startOfDay(for: session.completedAt)
            }
        } else {
            // Focus-duration history did not exist before Think 1.1. Starting
            // empty is deliberate: aggregate counters cannot reveal duration.
            focusHistoryByDay = [:]
        }
        lastOpenDay = defaults.object(forKey: Key.lastOpenDay) as? Date
        lastQuestionAnswerDay = defaults.object(forKey: Key.lastQuestionAnswerDay) as? Date
        earnedStreakMilestones = Set(
            (defaults.array(forKey: Key.earnedStreakMilestones) as? [Int] ?? [])
                .compactMap(StreakMilestone.init(rawValue:))
        )
        if let stored = defaults.array(forKey: Key.completedDays) as? [Date] {
            completedDays = Set(stored.map { calendar.startOfDay(for: $0) })
        } else {
            // An aggregate streak cannot prove the dates of older activity.
            completedDays = Set(storedLastCompletedDay.map { [calendar.startOfDay(for: $0)] } ?? [])
            defaults.set(Array(completedDays), forKey: Key.completedDays)
        }
        if let data = defaults.data(forKey: Key.activities) {
            practiceActivities = (try? SyncCodec.decode([PracticeActivity].self, from: data)) ?? []
        }
        if let data = defaults.data(forKey: Key.pathRuns) {
            pathRuns = (try? SyncCodec.decode([PathRunProgress].self, from: data)) ?? []
        } else if pathCompletedDays > 0 {
            pathRuns = [PathRunProgress(id: UUID(), pathID: PathLibrary.deepFocus.id,
                totalSteps: PathLibrary.deepFocus.steps.count, startedAt: nil,
                legacyCompletedSteps: pathCompletedDays, completions: [])]
        }
        seenFocusIDs = Set(defaults.stringArray(forKey: Key.seenFocusIDs) ?? [])
        seenFocusIDs.formUnion(focusHistoryByDay.values.flatMap { $0.map(\.id) })
        if let days = defaults.array(forKey: Key.legacyDays) as? [Date] {
            legacyDays = Set(days)
        } else { legacyDays = completedDays }
        persistPractice()

        if !hasStoredMilestoneAwards {
            let longestHistoricalRun = Self.maximumContiguousStreak(
                in: completedDays,
                calendar: calendar
            )
            let longestKnownRun = max(storedStreak, longestHistoricalRun)
            earnedStreakMilestones.formUnion(
                StreakMilestone.allCases.filter { $0.rawValue <= longestKnownRun }
            )
            // Persist even an empty result so this history migration is one-time.
            defaults.set(earnedStreakMilestones.map(\.rawValue), forKey: Key.earnedStreakMilestones)
        }
        pruneFocusHistory(relativeTo: now())
        persistFocusHistory()
        if defaults.bool(forKey: SharedDefaults.resetPendingKey) { reset() }
    }

    /// Same rule as `displayedStreak`, computed straight from stored
    /// defaults so widget timeline providers can read it off the main actor.
    nonisolated static func storedDisplayedStreak(
        in defaults: UserDefaults,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> Int {
        guard let last = defaults.object(forKey: Key.lastCompletedDay) as? Date,
              let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return 0 }
        if calendar.isDate(last, inSameDayAs: now) || calendar.isDate(last, inSameDayAs: yesterday) {
            return defaults.integer(forKey: Key.streak)
        }
        return 0
    }

    /// The four independent daily-practice signals available in the shared
    /// App Group: app open, daily answer, focus session, and path step.
    nonisolated static func storedDailyPracticeProgressCount(
        in defaults: UserDefaults,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> Int {
        var kinds: Set<PracticeActivityKind> = []
        if let data = defaults.data(forKey: Key.activities),
           let records = try? SyncCodec.decode([PracticeActivity].self, from: data) {
            kinds.formUnion(records.filter { calendar.isDate($0.date, inSameDayAs: now) }.map(\.kind))
        }
        if storedDate(forKey: Key.lastQuestionAnswerDay, in: defaults, isSameDayAs: now, calendar: calendar) { kinds.insert(.answer) }
        if defaults.integer(forKey: Key.focusSessionDayCount) > 0,
           storedDate(forKey: Key.focusSessionDay, in: defaults, isSameDayAs: now, calendar: calendar) { kinds.insert(.focus) }
        if storedDate(forKey: Key.lastPathCompletionDay, in: defaults, isSameDayAs: now, calendar: calendar) { kinds.insert(.path) }
        return kinds.count
    }

    /// Streak shown to the user: still alive if the last completed day
    /// is today or yesterday, otherwise back to zero.
    var displayedStreak: Int {
        guard let lastCompletedDay else { return 0 }
        if calendar.isDate(lastCompletedDay, inSameDayAs: now()) || calendar.isDate(lastCompletedDay, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now())!) {
            return streak
        }
        return 0
    }

    var focusSessionsToday: Int {
        guard let focusSessionDay, calendar.isDate(focusSessionDay, inSameDayAs: now()) else { return 0 }
        return focusSessionDayCount
    }

    var focusHistory: [FocusSessionRecord] {
        focusHistoryByDay.values
            .flatMap { $0 }
            .sorted {
                if $0.completedAt != $1.completedAt {
                    return $0.completedAt < $1.completedAt
                }
                return $0.id < $1.id
            }
    }

    func focusSessions(in interval: DateInterval) -> [FocusSessionRecord] {
        let firstDay = calendar.startOfDay(for: interval.start)
        return focusHistoryByDay
            .filter { day, _ in day >= firstDay && day < interval.end }
            .values
            .flatMap { $0 }
            .filter { $0.completedAt >= interval.start && $0.completedAt < interval.end }
            .sorted {
                if $0.completedAt != $1.completedAt {
                    return $0.completedAt < $1.completedAt
                }
                return $0.id < $1.id
            }
    }

    var completedTaskToday: Bool {
        guard let lastCompletedDay else { return false }
        return calendar.isDate(lastCompletedDay, inSameDayAs: now())
    }

    var completedPathStepToday: Bool {
        guard let lastPathCompletionDay else { return false }
        return calendar.isDate(lastPathCompletionDay, inSameDayAs: now())
    }

    var answeredDailyQuestionToday: Bool {
        guard let lastQuestionAnswerDay else { return false }
        return calendar.isDate(lastQuestionAnswerDay, inSameDayAs: now())
    }

    var dailyPracticeProgressCount: Int {
        activities(on: now()).count
    }

    var canCompletePathStepToday: Bool {
        canCompletePathStep(pathID: PathLibrary.deepFocus.id, totalSteps: PathLibrary.deepFocus.steps.count, at: now())
    }

    var completedPathCount: Int { pathRuns.filter(\.isComplete).count }

    var earnedAchievements: Set<ProgressAchievement> {
        Set(ProgressAchievement.all.filter(hasEarned))
    }

    func markTodayComplete() {
        guard recordActivitySilently(.note, id: "legacy-note-\(calendar.startOfDay(for: now()).timeIntervalSince1970)", at: now()) else { return }
        emit(.markTodayComplete)
    }

    func hasEarned(_ milestone: StreakMilestone) -> Bool {
        earnedStreakMilestones.contains(milestone)
    }

    func hasEarned(_ achievement: ProgressAchievement) -> Bool {
        switch achievement {
        case .streak(let milestone):
            hasEarned(milestone)
        case .path:
            completedPathCount >= achievement.target
        case .focus:
            totalFocusSessions >= achievement.target
        }
    }

    func hasCompleted(_ date: Date) -> Bool {
        completedDays.contains(calendar.startOfDay(for: date))
    }

    /// Showing up counts: the first open of the day is the first slice
    /// of the daily-practice bar. Does not touch the streak.
    var openedToday: Bool {
        guard let lastOpenDay else { return false }
        return calendar.isDate(lastOpenDay, inSameDayAs: now())
    }

    func recordAppOpen() {
        guard !openedToday else { return }
        lastOpenDay = calendar.startOfDay(for: now())
        defaults.set(lastOpenDay, forKey: Key.lastOpenDay)
        emit(.recordAppOpen)
    }

    func recordDailyQuestionAnswer(at date: Date = .now) {
        let day = calendar.startOfDay(for: date)
        guard lastQuestionAnswerDay.map({ !calendar.isDate($0, inSameDayAs: day) }) ?? true else { return }
        lastQuestionAnswerDay = day
        defaults.set(day, forKey: Key.lastQuestionAnswerDay)
        _ = recordActivitySilently(.answer, id: "answer-\(day.timeIntervalSince1970)", at: date)
        emit(.recordDailyQuestionAnswer)
    }

    func completePathStep() {
        _ = completePathStep(pathID: PathLibrary.deepFocus.id, totalSteps: PathLibrary.deepFocus.steps.count, at: now())
    }

    /// Records a completed focus phase on the calendar day it actually
    /// finished. Delayed events therefore cannot become today's sessions.
    func recordFocusSession(
        at date: Date = .now,
        durationMinutes: Int? = nil,
        eventID: String? = nil,
        actualActiveSeconds: Int? = nil
    ) {
        let resolvedID = eventID ?? UUID().uuidString
        guard seenFocusIDs.insert(resolvedID).inserted else { return }
        defaults.set(Array(seenFocusIDs), forKey: Key.seenFocusIDs)
        let day = calendar.startOfDay(for: date)
        if let existingFocusSessionDay = focusSessionDay {
            let existingDay = calendar.startOfDay(for: existingFocusSessionDay)
            if calendar.isDate(existingDay, inSameDayAs: day) {
                focusSessionDayCount += 1
            } else if day > existingDay {
                focusSessionDay = day
                focusSessionDayCount = 1
            }
        } else {
            focusSessionDay = day
            focusSessionDayCount = 1
        }
        totalFocusSessions += 1
        defaults.set(focusSessionDay, forKey: Key.focusSessionDay)
        defaults.set(focusSessionDayCount, forKey: Key.focusSessionDayCount)
        defaults.set(totalFocusSessions, forKey: Key.totalFocusSessions)
        if let durationMinutes, (1...120).contains(durationMinutes) {
            recordFocusHistory(
                at: date,
                durationMinutes: durationMinutes,
                eventID: resolvedID, actualActiveSeconds: actualActiveSeconds
            )
        }
        _ = recordActivitySilently(.focus, id: resolvedID, at: date)
        emit(.recordFocusSession)
    }

    func reset() {
        for key in Self.persistedKeys {
            defaults.removeObject(forKey: key)
        }

        practiceActivities = []; pathRuns = []; seenFocusIDs = []; legacyDays = []
        persistPractice()
        streak = 0
        lastCompletedDay = nil
        pathCompletedDays = 0
        lastPathCompletionDay = nil
        totalFocusSessions = 0
        focusSessionDay = nil
        focusSessionDayCount = 0
        focusHistoryByDay = [:]
        completedDays = []
        lastOpenDay = nil
        lastQuestionAnswerDay = nil
        earnedStreakMilestones = []
        defaults.set([], forKey: Key.completedDays)
        persistFocusHistory()
        defaults.removeObject(forKey: SharedDefaults.resetPendingKey)
        defaults.synchronize()
        emit(.reset)
    }

    func snapshot(
        appliedEventIDs: [String] = [],
        publishedAt: Date = .now
    ) -> ProgressSnapshot {
        ProgressSnapshot(
            streak: streak,
            lastCompletedDay: lastCompletedDay,
            completedDays: completedDays.sorted(),
            pathCompletedDays: pathCompletedDays,
            lastPathCompletionDay: lastPathCompletionDay,
            totalFocusSessions: totalFocusSessions,
            focusSessionDay: focusSessionDay,
            focusSessionDayCount: focusSessionDayCount,
            lastOpenDay: lastOpenDay,
            lastQuestionAnswerDay: lastQuestionAnswerDay,
            appliedEventIDs: appliedEventIDs,
            publishedAt: publishedAt,
            resetBoundary: resetBoundary,
            practiceActivities: practiceActivities
        )
    }

    /// Replaces every persisted progress field. This is intentionally silent;
    /// the phone is the only writer of canonical progress.
    func apply(_ snapshot: ProgressSnapshot) {
        guard snapshot.resetBoundary == resetBoundary,
              snapshot.publishedAt > latestAppliedSnapshotDate else { return }
        defaults.set(snapshot.publishedAt, forKey: Key.appliedSnapshotDate)
        practiceActivities = snapshot.practiceActivities ?? []
        // Snapshots replace canonical counters; pending Watch events are replayed afterwards.
        seenFocusIDs = Set(snapshot.appliedEventIDs)
        legacyDays = Set(snapshot.completedDays).subtracting(practiceActivities.map { calendar.startOfDay(for: $0.date) })
        persistPractice()
        streak = snapshot.streak
        lastCompletedDay = snapshot.lastCompletedDay.map(calendar.startOfDay(for:))
        completedDays = Set(snapshot.completedDays.map(calendar.startOfDay(for:)))
        pathCompletedDays = snapshot.pathCompletedDays
        lastPathCompletionDay = snapshot.lastPathCompletionDay.map(calendar.startOfDay(for:))
        totalFocusSessions = snapshot.totalFocusSessions
        focusSessionDay = snapshot.focusSessionDay.map(calendar.startOfDay(for:))
        focusSessionDayCount = snapshot.focusSessionDayCount
        lastOpenDay = snapshot.lastOpenDay.map(calendar.startOfDay(for:))
        lastQuestionAnswerDay = snapshot.lastQuestionAnswerDay.map(calendar.startOfDay(for:))
        persistAllFields()
    }

    private func completeDay(at date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        guard completedDays.insert(day).inserted else { return false }
        let previousStreak = streak
        let previousLastDay = lastCompletedDay
        recomputeStreak()
        if let previousLastDay,
           calendar.date(byAdding: .day, value: 1, to: previousLastDay) == day {
            // Preserve a known legacy aggregate without fabricating its dates.
            streak = max(streak, previousStreak + 1)
        }
        awardMilestonesIfNeeded()
        defaults.set(streak, forKey: Key.streak)
        setOptional(lastCompletedDay, forKey: Key.lastCompletedDay)
        defaults.set(Array(completedDays), forKey: Key.completedDays)
        return true
    }

    private func awardMilestonesIfNeeded() {
        let reached = Set(StreakMilestone.allCases.filter { $0.rawValue <= streak })
        guard !reached.isSubset(of: earnedStreakMilestones) else { return }
        earnedStreakMilestones.formUnion(reached)
        defaults.set(earnedStreakMilestones.map(\.rawValue), forKey: Key.earnedStreakMilestones)
    }

    private static func maximumContiguousStreak(
        in completedDays: Set<Date>,
        calendar: Calendar
    ) -> Int {
        let days = Set(completedDays.map(calendar.startOfDay(for:)))
        var longest = 0

        for day in days {
            if let previous = calendar.date(byAdding: .day, value: -1, to: day),
               days.contains(previous) {
                continue
            }

            var runLength = 1
            var cursor = day
            while let next = calendar.date(byAdding: .day, value: 1, to: cursor),
                  days.contains(next) {
                runLength += 1
                cursor = next
            }
            longest = max(longest, runLength)
        }

        return longest
    }

    private func recomputeStreak() {
        guard let latest = completedDays.max() else {
            streak = 0
            lastCompletedDay = nil
            return
        }

        var count = 1
        var day = latest
        while let previous = calendar.date(byAdding: .day, value: -1, to: day),
              completedDays.contains(previous) {
            count += 1
            day = previous
        }
        streak = count
        lastCompletedDay = latest
    }

    private func persistAllFields() {
        defaults.set(streak, forKey: Key.streak)
        setOptional(lastCompletedDay, forKey: Key.lastCompletedDay)
        defaults.set(pathCompletedDays, forKey: Key.pathCompletedDays)
        setOptional(lastPathCompletionDay, forKey: Key.lastPathCompletionDay)
        defaults.set(totalFocusSessions, forKey: Key.totalFocusSessions)
        setOptional(focusSessionDay, forKey: Key.focusSessionDay)
        defaults.set(focusSessionDayCount, forKey: Key.focusSessionDayCount)
        persistFocusHistory()
        defaults.set(Array(completedDays), forKey: Key.completedDays)
        setOptional(lastOpenDay, forKey: Key.lastOpenDay)
        setOptional(lastQuestionAnswerDay, forKey: Key.lastQuestionAnswerDay)
    }

    private func setOptional(_ value: Date?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private var focusHistoryDays: [FocusHistoryDay] {
        focusHistoryByDay
            .map { day, sessions in
                FocusHistoryDay(
                    day: day,
                    sessions: sessions.sorted {
                        if $0.completedAt != $1.completedAt {
                            return $0.completedAt < $1.completedAt
                        }
                        return $0.id < $1.id
                    }
                )
            }
            .sorted { $0.day < $1.day }
    }

    private func recordFocusHistory(at date: Date, durationMinutes: Int, eventID: String, actualActiveSeconds: Int? = nil, isCompleted: Bool = true) {
        pruneFocusHistory(relativeTo: now())
        let day = calendar.startOfDay(for: date)
        guard let cutoff = calendar.date(
            byAdding: .day,
            value: -(Self.focusHistoryRetentionDays - 1),
            to: calendar.startOfDay(for: now())
        ), day >= cutoff else { return }

        var sessions = focusHistoryByDay[day, default: []]
        guard !sessions.contains(where: { $0.id == eventID }) else { return }
        sessions.append(
            FocusSessionRecord(
                id: eventID,
                completedAt: date,
                durationMinutes: durationMinutes,
                actualActiveSeconds: actualActiveSeconds,
                isCompleted: isCompleted
            )
        )
        focusHistoryByDay[day] = sessions
        persistFocusHistory()
    }

    private func pruneFocusHistory(relativeTo date: Date) {
        guard let cutoff = calendar.date(
            byAdding: .day,
            value: -(Self.focusHistoryRetentionDays - 1),
            to: calendar.startOfDay(for: date)
        ) else { return }
        focusHistoryByDay = focusHistoryByDay.filter { $0.key >= cutoff }
    }

    private func persistFocusHistory() {
        guard let data = try? SyncCodec.encode(focusHistoryDays) else { return }
        defaults.set(data, forKey: Key.focusHistory)
    }

    private nonisolated static func storedDate(
        forKey key: String,
        in defaults: UserDefaults,
        isSameDayAs date: Date,
        calendar: Calendar
    ) -> Bool {
        guard let stored = defaults.object(forKey: key) as? Date else { return false }
        return calendar.isDate(stored, inSameDayAs: date)
    }

    func activities(on date: Date) -> Set<PracticeActivityKind> {
        var kinds = Set(practiceActivities.filter { calendar.isDate($0.date, inSameDayAs: date) }.map(\.kind))
        if let lastQuestionAnswerDay, calendar.isDate(lastQuestionAnswerDay, inSameDayAs: date) { kinds.insert(.answer) }
        if let focusSessionDay, focusSessionDayCount > 0, calendar.isDate(focusSessionDay, inSameDayAs: date) { kinds.insert(.focus) }
        if let lastPathCompletionDay, calendar.isDate(lastPathCompletionDay, inSameDayAs: date) { kinds.insert(.path) }
        return kinds
    }

    @discardableResult
    func recordActivity(_ kind: PracticeActivityKind, id: String, at date: Date = .now) -> Bool {
        guard recordActivitySilently(kind, id: id, at: date) else { return false }
        emit(.activityChanged)
        return true
    }

    private func recordActivitySilently(_ kind: PracticeActivityKind, id: String, at date: Date) -> Bool {
        guard !practiceActivities.contains(where: { $0.id == id && $0.kind == kind }) else { return false }
        practiceActivities.append(PracticeActivity(id: id, kind: kind, date: date))
        persistPractice()
        _ = completeDay(at: date)
        return true
    }

    func isMoveCompleted(practiceID: String, at date: Date = .now) -> Bool {
        let id = moveID(practiceID, date: date)
        return practiceActivities.contains { $0.id == id && $0.kind == .move }
    }

    func setMoveCompleted(_ completed: Bool, practiceID: String, at date: Date = .now) {
        let id = moveID(practiceID, date: date)
        if completed { _ = recordActivity(.move, id: id, at: date); return }
        let oldCount = practiceActivities.count
        practiceActivities.removeAll { $0.id == id && $0.kind == .move }
        guard practiceActivities.count != oldCount else { return }
        let day = calendar.startOfDay(for: date)
        if !legacyDays.contains(day) && activities(on: date).isEmpty {
            completedDays.remove(day)
            recomputeStreak()
        }
        persistPractice(); persistAllFields(); emit(.activityChanged)
    }

    private func moveID(_ practiceID: String, date: Date) -> String {
        "move-\(practiceID)-\(calendar.startOfDay(for: date).timeIntervalSince1970)"
    }

    func runs(for pathID: String) -> [PathRunProgress] { pathRuns.filter { $0.pathID == pathID } }
    func activeRun(for pathID: String) -> PathRunProgress? { runs(for: pathID).last }

    @discardableResult
    func startNewRun(pathID: String, totalSteps: Int, at date: Date = .now) -> PathRunProgress {
        let run = createRun(pathID: pathID, totalSteps: totalSteps, at: date)
        emit(.pathRunChanged)
        return run
    }

    private func createRun(pathID: String, totalSteps: Int, at date: Date) -> PathRunProgress {
        let run = PathRunProgress(id: UUID(), pathID: pathID, totalSteps: max(1, totalSteps),
            startedAt: date, legacyCompletedSteps: 0, completions: [])
        pathRuns.append(run)
        updateLegacyPathFields(pathID: pathID)
        persistPractice()
        return run
    }

    func canCompletePathStep(pathID: String, totalSteps: Int, at date: Date = .now) -> Bool {
        guard totalSteps > 0 else { return false }
        guard let run = activeRun(for: pathID) else { return true }
        guard !run.isComplete else { return false }
        let last = run.lastCompletionDate ?? (run.startedAt == nil && pathID == PathLibrary.deepFocus.id ? lastPathCompletionDay : nil)
        return last.map { !calendar.isDate($0, inSameDayAs: date) } ?? true
    }

    @discardableResult
    func completePathStep(pathID: String, totalSteps: Int, at date: Date = .now) -> Bool {
        guard canCompletePathStep(pathID: pathID, totalSteps: totalSteps, at: date) else { return false }
        if activeRun(for: pathID) == nil { _ = createRun(pathID: pathID, totalSteps: totalSteps, at: date) }
        guard let index = pathRuns.lastIndex(where: { $0.pathID == pathID }) else { return false }
        let step = pathRuns[index].completedSteps + 1
        pathRuns[index].completions.append(PathStepCompletion(step: step, date: date))
        updateLegacyPathFields(pathID: pathID)
        _ = recordActivitySilently(.path, id: "\(pathRuns[index].id.uuidString)-\(step)", at: date)
        persistPractice(); emit(.completePathStep)
        return true
    }

    private func updateLegacyPathFields(pathID: String) {
        guard pathID == PathLibrary.deepFocus.id, let run = activeRun(for: pathID) else { return }
        pathCompletedDays = run.completedSteps
        lastPathCompletionDay = run.lastCompletionDate
        defaults.set(pathCompletedDays, forKey: Key.pathCompletedDays)
        setOptional(lastPathCompletionDay, forKey: Key.lastPathCompletionDay)
    }

    func recordPartialFocusSession(_ record: FocusSessionRecord) {
        guard !record.isCompleted, (record.actualActiveSeconds ?? 0) > 0,
              seenFocusIDs.insert(record.id).inserted else { return }
        persistPractice()
        recordFocusHistory(at: record.completedAt, durationMinutes: record.durationMinutes,
            eventID: record.id, actualActiveSeconds: record.actualActiveSeconds, isCompleted: false)
        emit(.partialFocusSession)
    }

    func installResetBoundary(_ boundary: SyncResetBoundary) {
        defaults.set(true, forKey: SharedDefaults.resetPendingKey)
        SharedDefaults.setResetBoundary(boundary, in: defaults)
        reset()
    }

    func weeklySummary(containing date: Date = .now, calendar summaryCalendar: Calendar = .current) -> WeeklyPracticeSummary {
        let start = summaryCalendar.dateInterval(of: .weekOfYear, for: date)?.start ?? summaryCalendar.startOfDay(for: date)
        let end = summaryCalendar.date(byAdding: .day, value: 7, to: start)!
        var days = (0..<7).map { WeeklyPracticeDay(date: summaryCalendar.date(byAdding: .day, value: $0, to: start)!) }
        let indices = Dictionary(uniqueKeysWithValues: days.enumerated().map { ($0.element.date, $0.offset) })
        for day in completedDays {
            if let i = indices[summaryCalendar.startOfDay(for: day)] { days[i].practiced = true }
        }
        for activity in practiceActivities {
            if let i = indices[summaryCalendar.startOfDay(for: activity.date)] { days[i].activities.insert(activity.kind) }
        }
        for records in focusHistoryByDay.values {
            for record in records {
                guard let i = indices[summaryCalendar.startOfDay(for: record.completedAt)] else { continue }
                if record.isCompleted {
                    days[i].completedSessions += 1
                    days[i].completedMinutes += record.durationMinutes
                    days[i].completedActiveSeconds += record.actualActiveSeconds ?? 0
                } else { days[i].partialActiveSeconds += record.actualActiveSeconds ?? 0 }
                if record.actualActiveSeconds == nil { days[i].unknownActualDurationSessions += 1 }
            }
        }
        return WeeklyPracticeSummary(interval: DateInterval(start: start, end: end), days: days, focusHistoryRetentionDays: Self.focusHistoryRetentionDays)
    }

    private func persistPractice() {
        if let data = try? SyncCodec.encode(practiceActivities) { defaults.set(data, forKey: Key.activities) }
        if let data = try? SyncCodec.encode(pathRuns) { defaults.set(data, forKey: Key.pathRuns) }
        defaults.set(Array(seenFocusIDs), forKey: Key.seenFocusIDs)
        defaults.set(Array(legacyDays), forKey: Key.legacyDays)
    }

    private func emit(_ mutation: ProgressMutation) {
        onMutation?(mutation)
    }
}
