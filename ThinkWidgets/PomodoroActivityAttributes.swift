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
        var restEndDate: Date?
        /// What the person said this session is for. Absent for sessions
        /// started without one, and for every activity encoded by 1.1.1.
        var intention: String?

        init(
            phase: Phase,
            startDate: Date,
            endDate: Date,
            restEndDate: Date? = nil,
            intention: String? = nil
        ) {
            self.phase = phase
            self.startDate = startDate
            self.endDate = endDate
            self.restEndDate = restEndDate
            self.intention = intention
        }

        private enum CodingKeys: String, CodingKey {
            case phase
            case startDate
            case endDate
            case restEndDate
            case intention
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            phase = try container.decode(Phase.self, forKey: .phase)
            endDate = try container.decode(Date.self, forKey: .endDate)
            startDate = try container.decodeIfPresent(Date.self, forKey: .startDate) ?? endDate
            restEndDate = try container.decodeIfPresent(Date.self, forKey: .restEndDate)
            // `decodeIfPresent`: an activity encoded by 1.1.1 carries no
            // intention key and must still decode after the update.
            intention = try container.decodeIfPresent(String.self, forKey: .intention)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(phase, forKey: .phase)
            try container.encode(startDate, forKey: .startDate)
            try container.encode(endDate, forKey: .endDate)
            try container.encodeIfPresent(restEndDate, forKey: .restEndDate)
            try container.encodeIfPresent(intention, forKey: .intention)
        }

        func presentationState(isStale: Bool) -> Self {
            guard isStale,
                  phase == .work,
                  let restEndDate,
                  restEndDate > endDate else { return self }

            return Self(
                phase: .rest,
                startDate: endDate,
                endDate: restEndDate
            )
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
