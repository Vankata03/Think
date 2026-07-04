//
//  PomodoroActivityAttributes.swift
//  Think
//
//  Shared between the app target (starts/updates the activity) and
//  the widget extension (renders it).
//

import ActivityKit
import Foundation

nonisolated struct PomodoroActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable {
            case work
            case rest
        }

        var phase: Phase
        var startDate: Date
        var endDate: Date

        var progressRange: ClosedRange<Date> {
            startDate...max(startDate, endDate)
        }

        func progress(at date: Date = .now) -> Double {
            let totalDuration = endDate.timeIntervalSince(startDate)
            guard totalDuration > 0 else { return 0 }

            let elapsed = date.timeIntervalSince(startDate)
            return min(max(elapsed / totalDuration, 0), 1)
        }
    }
}
