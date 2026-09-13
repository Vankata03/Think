import Foundation
import SwiftData

/// Private journal-side linkage. Never include these fields in timer/watch payloads.
@Model
final class FocusSessionMetadata {
    var recordID: UUID?
    var sessionID: String = ""
    var intention: String?
    var outcome: String?
    var energy: String?
    var closingNoteRecordID: UUID?
    var completedAt: Date?
    var civilDay: String?
    var timeZoneIdentifier: String?
    var updatedAt: Date?

    init(sessionID: String, intention: String? = nil, completedAt: Date? = nil) {
        self.recordID = UUID()
        self.sessionID = sessionID
        self.intention = intention
        self.completedAt = completedAt
        if let completedAt {
            let day = CivilDay(date: completedAt)
            self.civilDay = day.key
            self.timeZoneIdentifier = day.timeZoneIdentifier
        }
    }
}

nonisolated enum FocusOutcome: String, CaseIterable, Codable, Sendable {
    case done, movedForward, changedDirection
}

nonisolated enum EnergyLevel: String, CaseIterable, Codable, Sendable {
    case low, steady, high
}
