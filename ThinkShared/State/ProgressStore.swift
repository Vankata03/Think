//
//  ProgressStore.swift
//  Think
//

import Foundation
import Observation

enum ProgressMutation: Sendable {
    case markTodayComplete
    case recordAppOpen
    case completePathStep
    case recordFocusSession
    case reset
}

/// Streak, focus-session, and path progress. Backed by UserDefaults —
/// small scalar state that doesn't warrant SwiftData.
@MainActor
@Observable
final class ProgressStore {

    private nonisolated enum Key {
        static let streak = "streak"
        static let lastCompletedDay = "lastCompletedDay"
        static let pathCompletedDays = "pathCompletedDays"
        static let lastPathCompletionDay = "lastPathCompletionDay"
        static let totalFocusSessions = "totalFocusSessions"
        static let focusSessionDay = "focusSessionDay"
        static let focusSessionDayCount = "focusSessionDayCount"
        static let completedDays = "completedDays"
        static let lastOpenDay = "lastOpenDay"
    }

    /// Every key this store persists, for migrating between defaults suites.
    nonisolated static let persistedKeys: [String] = [
        Key.streak,
        Key.lastCompletedDay,
        Key.pathCompletedDays,
        Key.lastPathCompletionDay,
        Key.totalFocusSessions,
        Key.focusSessionDay,
        Key.focusSessionDayCount,
        Key.completedDays,
        Key.lastOpenDay,
    ]

    private let defaults: UserDefaults
    private let calendar: Calendar

    private(set) var streak: Int
    private(set) var lastCompletedDay: Date?
    private(set) var pathCompletedDays: Int
    private(set) var lastPathCompletionDay: Date?
    private(set) var totalFocusSessions: Int
    private var focusSessionDay: Date?
    private var focusSessionDayCount: Int
    /// Start-of-day dates for every completed practice day, for the
    /// streak calendar. Grows one entry per day at most.
    private(set) var completedDays: Set<Date>
    private var lastOpenDay: Date?

    /// Called after a successful local mutation. Snapshot application does
    /// not invoke this callback.
    var onMutation: (@MainActor (ProgressMutation) -> Void)?

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        let storedStreak = defaults.integer(forKey: Key.streak)
        let storedLastCompletedDay = defaults.object(forKey: Key.lastCompletedDay) as? Date

        self.defaults = defaults
        self.calendar = calendar
        streak = storedStreak
        lastCompletedDay = storedLastCompletedDay
        pathCompletedDays = defaults.integer(forKey: Key.pathCompletedDays)
        lastPathCompletionDay = defaults.object(forKey: Key.lastPathCompletionDay) as? Date
        totalFocusSessions = defaults.integer(forKey: Key.totalFocusSessions)
        focusSessionDay = defaults.object(forKey: Key.focusSessionDay) as? Date
        focusSessionDayCount = defaults.integer(forKey: Key.focusSessionDayCount)
        lastOpenDay = defaults.object(forKey: Key.lastOpenDay) as? Date
        if let stored = defaults.array(forKey: Key.completedDays) as? [Date] {
            completedDays = Set(stored.map { calendar.startOfDay(for: $0) })
        } else {
            // History shipped after streaks did; reconstruct the current
            // run from the streak counter so existing users don't open
            // an empty calendar.
            var backfilled: Set<Date> = []
            if let last = storedLastCompletedDay, storedStreak > 0 {
                let lastDay = calendar.startOfDay(for: last)
                for offset in 0..<storedStreak {
                    if let day = calendar.date(byAdding: .day, value: -offset, to: lastDay) {
                        backfilled.insert(day)
                    }
                }
            }
            completedDays = backfilled
            defaults.set(Array(backfilled), forKey: Key.completedDays)
        }
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

    /// Streak shown to the user: still alive if the last completed day
    /// is today or yesterday, otherwise back to zero.
    var displayedStreak: Int {
        guard let lastCompletedDay else { return 0 }
        if calendar.isDateInToday(lastCompletedDay) || calendar.isDateInYesterday(lastCompletedDay) {
            return streak
        }
        return 0
    }

    var focusSessionsToday: Int {
        guard let focusSessionDay, calendar.isDateInToday(focusSessionDay) else { return 0 }
        return focusSessionDayCount
    }

    var completedTaskToday: Bool {
        guard let lastCompletedDay else { return false }
        return calendar.isDateInToday(lastCompletedDay)
    }

    var completedPathStepToday: Bool {
        guard let lastPathCompletionDay else { return false }
        return calendar.isDateInToday(lastPathCompletionDay)
    }

    var canCompletePathStepToday: Bool {
        guard pathCompletedDays < PathLibrary.deepFocus.steps.count else { return false }
        guard let lastPathCompletionDay else { return true }
        return !calendar.isDateInToday(lastPathCompletionDay)
    }

    func markTodayComplete() {
        guard completeDay(at: .now) else { return }
        emit(.markTodayComplete)
    }

    func hasCompleted(_ date: Date) -> Bool {
        completedDays.contains(calendar.startOfDay(for: date))
    }

    /// Showing up counts: the first open of the day is the first slice
    /// of the daily-practice bar. Does not touch the streak.
    var openedToday: Bool {
        guard let lastOpenDay else { return false }
        return calendar.isDateInToday(lastOpenDay)
    }

    func recordAppOpen() {
        guard !openedToday else { return }
        lastOpenDay = calendar.startOfDay(for: .now)
        defaults.set(lastOpenDay, forKey: Key.lastOpenDay)
        emit(.recordAppOpen)
    }

    func completePathStep() {
        guard canCompletePathStepToday else { return }
        pathCompletedDays += 1
        let today = calendar.startOfDay(for: .now)
        lastPathCompletionDay = today
        defaults.set(pathCompletedDays, forKey: Key.pathCompletedDays)
        defaults.set(today, forKey: Key.lastPathCompletionDay)
        _ = completeDay(at: today)
        emit(.completePathStep)
    }

    /// Records a completed focus phase on the calendar day it actually
    /// finished. Delayed events therefore cannot become today's sessions.
    func recordFocusSession(at date: Date = .now) {
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
        _ = completeDay(at: day)
        emit(.recordFocusSession)
    }

    func reset() {
        for key in Self.persistedKeys {
            defaults.removeObject(forKey: key)
        }

        streak = 0
        lastCompletedDay = nil
        pathCompletedDays = 0
        lastPathCompletionDay = nil
        totalFocusSessions = 0
        focusSessionDay = nil
        focusSessionDayCount = 0
        completedDays = []
        lastOpenDay = nil
        defaults.set([], forKey: Key.completedDays)
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
            appliedEventIDs: appliedEventIDs,
            publishedAt: publishedAt
        )
    }

    /// Replaces every persisted progress field. This is intentionally silent;
    /// the phone is the only writer of canonical progress.
    func apply(_ snapshot: ProgressSnapshot) {
        streak = snapshot.streak
        lastCompletedDay = snapshot.lastCompletedDay.map(calendar.startOfDay(for:))
        completedDays = Set(snapshot.completedDays.map(calendar.startOfDay(for:)))
        pathCompletedDays = snapshot.pathCompletedDays
        lastPathCompletionDay = snapshot.lastPathCompletionDay.map(calendar.startOfDay(for:))
        totalFocusSessions = snapshot.totalFocusSessions
        focusSessionDay = snapshot.focusSessionDay.map(calendar.startOfDay(for:))
        focusSessionDayCount = snapshot.focusSessionDayCount
        lastOpenDay = snapshot.lastOpenDay.map(calendar.startOfDay(for:))
        persistAllFields()
    }

    private func completeDay(at date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        guard completedDays.insert(day).inserted else { return false }
        recomputeStreak()
        defaults.set(streak, forKey: Key.streak)
        setOptional(lastCompletedDay, forKey: Key.lastCompletedDay)
        defaults.set(Array(completedDays), forKey: Key.completedDays)
        return true
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
        defaults.set(Array(completedDays), forKey: Key.completedDays)
        setOptional(lastOpenDay, forKey: Key.lastOpenDay)
    }

    private func setOptional(_ value: Date?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func emit(_ mutation: ProgressMutation) {
        onMutation?(mutation)
    }
}
