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
    static let kindWeeklyReview = "weeklyReview"
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
    /// Raw primary `Theme` value, or nil when the entry has no theme.
    /// Strings for the same reason as `mood`; two plain fields rather than
    /// a list so a `#Predicate` can match either one directly.
    var theme: String?
    /// Raw secondary `Theme` value; only ever set alongside `theme`.
    var secondaryTheme: String?
    var recordID: UUID?
    var civilDay: String?
    var timeZoneIdentifier: String?
    var practiceID: String?
    var sessionID: String?
    var updatedAt: Date?
    var periodKey: String?
    var nextIntention: String?

    init(date: Date = .now, prompt: String, text: String, kind: String, mood: Mood? = nil,
         themes: ThemeSelection = ThemeSelection()) {
        let day = CivilDay(date: date)
        self.recordID = UUID()
        self.civilDay = day.key
        self.timeZoneIdentifier = day.timeZoneIdentifier
        self.date = date
        self.prompt = prompt
        self.text = text
        self.kind = kind
        self.mood = mood?.rawValue
        self.themes = themes
    }

    /// Both themes, read and written as one selection. A weekly review
    /// summarises the week rather than being part of it, so setting themes
    /// on one stores none.
    var themes: ThemeSelection {
        get { ThemeSelection(stored: theme, secondary: secondaryTheme) }
        set {
            let stored = kind == JournalEntry.kindWeeklyReview ? ThemeSelection() : newValue
            theme = stored.primary?.rawValue
            secondaryTheme = stored.secondary?.rawValue
        }
    }

    /// Entries whose primary or secondary theme is `theme`.
    static func predicate(theme: Theme) -> Predicate<JournalEntry> {
        let raw: String? = theme.rawValue
        return #Predicate { $0.theme == raw || $0.secondaryTheme == raw }
    }
}
