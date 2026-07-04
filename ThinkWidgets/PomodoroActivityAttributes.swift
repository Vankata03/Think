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
        var endDate: Date
    }
}
