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

    var date: Date
    var prompt: String
    var text: String
    // Default keeps existing stores migrating cleanly; entries written
    // before the split were all daily-question answers.
    var kind: String = JournalEntry.kindQuestion

    init(date: Date = .now, prompt: String, text: String, kind: String) {
        self.date = date
        self.prompt = prompt
        self.text = text
        self.kind = kind
    }
}
