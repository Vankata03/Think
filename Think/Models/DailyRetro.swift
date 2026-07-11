//
//  DailyRetro.swift
//  Think
//

import Foundation
import SwiftData

/// One evening retrospective per day: what went well, what can
/// improve, and ideas or tasks for tomorrow. Stored on device only,
/// like all journal content.
@Model
final class DailyRetro {
    var date: Date
    var wentWell: String
    var improve: String
    var tomorrow: String

    init(date: Date = .now, wentWell: String, improve: String, tomorrow: String) {
        self.date = date
        self.wentWell = wentWell
        self.improve = improve
        self.tomorrow = tomorrow
    }
}
