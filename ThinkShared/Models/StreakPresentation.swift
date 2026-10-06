//
//  StreakPresentation.swift
//  Think
//

import Foundation

nonisolated struct StreakPresentation: Equatable, Sendable {
    static let widgetKind = "StreakWidget"
    static let dailyPracticeTotal = 1

    let streak: Int
    let completedPracticeCount: Int
    /// Whether any day was ever practised: a zero streak then reads as
    /// lapsed ("Begin again.") rather than new ("Start today.").
    let hasPractised: Bool

    init(streak: Int, completedPracticeCount: Int, hasPractised: Bool = false) {
        self.streak = streak
        self.completedPracticeCount = completedPracticeCount
        self.hasPractised = hasPractised || streak > 0
    }

    static let placeholder = StreakPresentation(streak: 5, completedPracticeCount: 2)

    var practiceProgress: Double {
        Double(min(max(completedPracticeCount, 0), Self.dailyPracticeTotal))
            / Double(Self.dailyPracticeTotal)
    }

    var isTodayComplete: Bool {
        completedPracticeCount >= Self.dailyPracticeTotal
    }

    var streakText: String {
        if streak == 1 {
            return String(localized: LocalizedStringResource("1-day streak", table: "StreakPresentation"))
        }
        if streak > 1 {
            return String(
                localized: LocalizedStringResource(
                    "\(streak)-day streak",
                    table: "StreakPresentation"
                )
            )
        }
        // Two-state copy, design-system section 8: never practised versus lapsed.
        if hasPractised {
            return String(localized: LocalizedStringResource("Begin again.", table: "StreakPresentation"))
        }
        return String(localized: LocalizedStringResource("Start today.", table: "StreakPresentation"))
    }

    var todayText: String {
        if isTodayComplete {
            return String(localized: LocalizedStringResource("Today complete", table: "StreakPresentation"))
        }
        return String(localized: LocalizedStringResource("Begin today's practice", table: "StreakPresentation"))
    }

    static func stored(
        in defaults: UserDefaults,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> StreakPresentation {
        StreakPresentation(
            streak: ProgressStore.storedDisplayedStreak(
                in: defaults,
                calendar: calendar,
                now: now
            ),
            completedPracticeCount: ProgressStore.storedDailyPracticeProgressCount(
                in: defaults,
                calendar: calendar,
                now: now
            ),
            hasPractised: defaults.object(forKey: ProgressStore.lastCompletedDayKey) != nil
        )
    }
}
