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
    }

    private let defaults: UserDefaults
    private let calendar = Calendar.current

    private(set) var streak: Int
    private(set) var lastCompletedDay: Date?
    private(set) var pathCompletedDays: Int	
    private(set) var lastPathCompletionDay: Date?
    private(set) var totalFocusSessions: Int
    private var focusSessionDay: Date?
    private var focusSessionDayCount: Int

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        streak = defaults.integer(forKey: Key.streak)
        lastCompletedDay = defaults.object(forKey: Key.lastCompletedDay) as? Date
        pathCompletedDays = defaults.integer(forKey: Key.pathCompletedDays)
        lastPathCompletionDay = defaults.object(forKey: Key.lastPathCompletionDay) as? Date
        totalFocusSessions = defaults.integer(forKey: Key.totalFocusSessions)
        focusSessionDay = defaults.object(forKey: Key.focusSessionDay) as? Date
        focusSessionDayCount = defaults.integer(forKey: Key.focusSessionDayCount)
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
        defaults.set(streak, forKey: Key.streak)
        defaults.set(today, forKey: Key.lastCompletedDay)
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
