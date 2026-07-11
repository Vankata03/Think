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

        init(phase: Phase, startDate: Date, endDate: Date) {
            self.phase = phase
            self.startDate = startDate
            self.endDate = endDate
        }

        private enum CodingKeys: String, CodingKey {
            case phase
            case startDate
            case endDate
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            phase = try container.decode(Phase.self, forKey: .phase)
            endDate = try container.decode(Date.self, forKey: .endDate)
            startDate = try container.decodeIfPresent(Date.self, forKey: .startDate) ?? endDate
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(phase, forKey: .phase)
            try container.encode(startDate, forKey: .startDate)
            try container.encode(endDate, forKey: .endDate)
        }

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
