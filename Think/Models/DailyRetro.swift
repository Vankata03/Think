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
    var recordID: UUID?
    var civilDay: String?
    var timeZoneIdentifier: String?
    var practiceID: String?
    var promptSnapshot: String?
    var tomorrowIntention: String?
    var updatedAt: Date?

    init(
        date: Date = .now,
        wentWell: String,
        improve: String,
        tomorrow: String,
        mood: Mood? = nil
    ) {
        let day = CivilDay(date: date)
        self.recordID = UUID()
        self.civilDay = day.key
        self.timeZoneIdentifier = day.timeZoneIdentifier
        self.date = date
        self.wentWell = wentWell
        self.improve = improve
        self.tomorrow = tomorrow
        self.mood = mood?.rawValue
    }
}
