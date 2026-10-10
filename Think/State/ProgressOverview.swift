//
//  ProgressOverview.swift
//  Think
//

import Foundation

/// Everything the Progress tab shows, read from `ProgressStore` at one
/// instant (`design/progress-settings.md` sections 1 and 2). Partial
/// effort is never a completed Focus session.
struct ProgressOverview {
    /// All-time days with practice evidence.
    let practiceDays: Int
    let completedPathSteps: Int
    let completedFocusSessions: Int
    /// This calendar week, Monday to Sunday.
    let week: WeeklyPracticeSummary
    /// The two newest Focus sessions, completed or partial, newest first.
    let recentSessions: [FocusSessionRecord]
    /// The highest earned medal of each group, in the order Streak, Paths,
    /// Focus sessions: at most three.
    let highlightedAchievements: [ProgressAchievement]

    @MainActor
    init(progress: ProgressStore, now: Date = .now, calendar: Calendar = ProgressOverview.weekCalendar) {
        practiceDays = progress.completedDays.count
        completedPathSteps = progress.pathRuns.reduce(0) { $0 + $1.completedSteps }
        completedFocusSessions = progress.totalFocusSessions
        week = progress.weeklySummary(containing: now, calendar: calendar)
        recentSessions = Array(progress.focusHistory.suffix(2).reversed())
        highlightedAchievements = ProgressAchievement.groups.compactMap { group in
            group.last(where: progress.hasEarned)
        }
    }

    /// Weeks run Monday to Sunday in every locale, as the weekly review's do.
    static var weekCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }
}
