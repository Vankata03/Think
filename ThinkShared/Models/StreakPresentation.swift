//
//  StreakPresentation.swift
//  Think
//

import Foundation

nonisolated struct StreakPresentation: Equatable, Sendable {
    static let widgetKind = "StreakWidget"
    static let dailyPracticeTotal = 4

    let streak: Int
    let completedPracticeCount: Int

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
        return String(localized: LocalizedStringResource("Begin today", table: "StreakPresentation"))
    }

    var todayText: String {
        if isTodayComplete {
            return String(localized: LocalizedStringResource("Today complete", table: "StreakPresentation"))
        }
        return String(
            localized: LocalizedStringResource(
                "\(completedPracticeCount)/4 today",
                table: "StreakPresentation"
            )
        )
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
            )
        )
    }
}
