//
//  ProgressStore.swift
//  Think
//

import Foundation
import Observation

/// Streak, focus-session, and path progress. Backed by UserDefaults —
/// small scalar state that doesn't warrant SwiftData.
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
        guard let last = lastCompletedDay else { return 0 }
        if calendar.isDateInToday(last) || calendar.isDateInYesterday(last) {
            return streak
        }
        return 0
    }

    var focusSessionsToday: Int {
        guard let day = focusSessionDay, calendar.isDateInToday(day) else { return 0 }
        return focusSessionDayCount
    }

    var completedTaskToday: Bool {
        guard let last = lastCompletedDay else { return false }
        return calendar.isDateInToday(last)
    }

    var completedPathStepToday: Bool {
        guard let last = lastPathCompletionDay else { return false }
        return calendar.isDateInToday(last)
    }

    var canCompletePathStepToday: Bool {
        guard pathCompletedDays < PathLibrary.deepFocus.steps.count else { return false }
        guard let last = lastPathCompletionDay else { return true }
        return !calendar.isDateInToday(last)
    }

    func markTodayComplete() {
        let today = calendar.startOfDay(for: .now)
        if let last = lastCompletedDay, calendar.isDateInToday(last) { return }
        if let last = lastCompletedDay, calendar.isDateInYesterday(last) {
            streak += 1
        } else {
            streak = 1
        }
        lastCompletedDay = today
        completedDays.insert(today)
        defaults.set(streak, forKey: Key.streak)
        defaults.set(today, forKey: Key.lastCompletedDay)
        defaults.set(Array(completedDays), forKey: Key.completedDays)
    }

    func hasCompleted(_ date: Date) -> Bool {
        completedDays.contains(calendar.startOfDay(for: date))
    }

    /// Showing up counts: the first open of the day is the first slice
    /// of the daily-practice bar. Does not touch the streak.
    var openedToday: Bool {
        guard let day = lastOpenDay else { return false }
        return calendar.isDateInToday(day)
    }

    func recordAppOpen() {
        guard !openedToday else { return }
        let today = calendar.startOfDay(for: .now)
        lastOpenDay = today
        defaults.set(today, forKey: Key.lastOpenDay)
    }

    func completePathStep() {
        guard canCompletePathStepToday else { return }
        pathCompletedDays += 1
        let today = calendar.startOfDay(for: .now)
        lastPathCompletionDay = today
        defaults.set(pathCompletedDays, forKey: Key.pathCompletedDays)
        defaults.set(today, forKey: Key.lastPathCompletionDay)
        markTodayComplete()
    }

    func recordFocusSession() {
        let today = calendar.startOfDay(for: .now)
        if let day = focusSessionDay, calendar.isDateInToday(day) {
            focusSessionDayCount += 1
        } else {
            focusSessionDay = today
            focusSessionDayCount = 1
        }
        totalFocusSessions += 1
        defaults.set(today, forKey: Key.focusSessionDay)
        defaults.set(focusSessionDayCount, forKey: Key.focusSessionDayCount)
        defaults.set(totalFocusSessions, forKey: Key.totalFocusSessions)
        markTodayComplete()
    }
}
