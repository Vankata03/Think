//
//  JournalEntry.swift
//  Think
//

import Foundation
import SwiftData

@Model
final class JournalEntry {
    static let kindQuestion = "question"
    static let kindNote = "note"
    /// A note written right after a focus session, prompted by the
    /// intention that session was started with.
    static let kindFocus = "focus"

    // CloudKit mirroring requires every attribute to be optional or carry a
    // default value, so all four are defaulted even though the initializer
    // always supplies them.
    var date: Date = Date()
    var prompt: String = ""
    var text: String = ""
    // Default also keeps existing stores migrating cleanly; entries written
    // before the split were all daily-question answers.
    var kind: String = JournalEntry.kindQuestion
    /// Raw `Mood` value, or nil when the entry is untagged. Stored as a
    /// string so an unrecognised value reads back as untagged.
    var mood: String?

    init(date: Date = .now, prompt: String, text: String, kind: String, mood: Mood? = nil) {
        self.date = date
        self.prompt = prompt
        self.text = text
        self.kind = kind
        self.mood = mood?.rawValue
    }
}
