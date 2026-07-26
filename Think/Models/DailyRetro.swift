//
//  DailyRetro.swift
//  Think
//

import Foundation
import SwiftData

/// One evening retrospective per day: what went well, what can
/// improve, and ideas or tasks for tomorrow. Like all journal content it
/// stays on device, or in the user's own iCloud when backup is on.
@Model
final class DailyRetro {
    // Defaulted for CloudKit mirroring, which cannot represent a
    // non-optional attribute without a default.
    var date: Date = Date()
    var wentWell: String = ""
    var improve: String = ""
    var tomorrow: String = ""
    /// Raw `Mood` value, or nil when the retrospective is untagged.
    var mood: String?

    init(
        date: Date = .now,
        wentWell: String,
        improve: String,
        tomorrow: String,
        mood: Mood? = nil
    ) {
        self.date = date
        self.wentWell = wentWell
        self.improve = improve
        self.tomorrow = tomorrow
        self.mood = mood?.rawValue
    }
}
