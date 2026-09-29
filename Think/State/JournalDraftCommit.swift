//
//  JournalDraftCommit.swift
//  Think
//

import Foundation

extension JournalDraft {
    /// A focus draft written from a session screen carries intention,
    /// outcome and energy alongside the note. Saving it must keep all of
    /// them; an Edit of a stored focus note has only the text.
    var isRecoveredSession: Bool {
        kind == .focus && context.editingRecordID == nil && context.sessionID != nil
    }

    /// Whether Done can commit this draft. Mood and themes alone never make
    /// an entry; a retro may be only a mood, and a recovered session may be
    /// only an outcome.
    var hasSomethingToSave: Bool {
        if isRecoveredSession { return true }
        let intention = (tomorrowIntention ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .retro:
            return fields.values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                || mood != nil || !intention.isEmpty
        case .weeklyReview:
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !intention.isEmpty
        case .answer, .note, .focus:
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

extension JournalRepository {
    /// Commits a draft of any kind: a new record under the draft's own
    /// identity, or an edit of the record it was opened on. Nil only when a
    /// recovered session held no note text, so only its metadata was kept.
    @discardableResult
    func save(_ draft: JournalDraft) throws -> SaveReceipt? {
        let mood = Mood(stored: draft.mood)
        let themes = draft.themes
        let context = draft.context
        if let id = context.editingRecordID {
            switch draft.kind {
            case .retro:
                return try updateRetro(id: id, wentWell: draft.fields["wentWell"] ?? "", improve: draft.fields["improve"] ?? "",
                                       tomorrow: draft.fields["tomorrow"] ?? "", mood: mood, themes: themes,
                                       tomorrowIntention: draft.tomorrowIntention)
            case .weeklyReview:
                return try updateWeeklyReview(id: id, text: draft.text, nextIntention: draft.tomorrowIntention)
            case .answer, .note, .focus:
                return try updateEntry(id: id, text: draft.text, mood: mood, themes: themes)
            }
        }
        switch draft.kind {
        case .answer:
            return try saveAnswer(text: draft.text, practiceID: context.practiceID, prompt: context.promptSnapshot ?? "",
                                  mood: mood, themes: themes, day: context.civilDay, date: draft.createdAt, recordID: draft.id)
        case .retro:
            return try saveRetro(wentWell: draft.fields["wentWell"] ?? "", improve: draft.fields["improve"] ?? "",
                                 tomorrow: draft.fields["tomorrow"] ?? "", mood: mood, themes: themes, day: context.civilDay,
                                 date: draft.createdAt, practiceID: context.practiceID, promptSnapshot: context.promptSnapshot,
                                 tomorrowIntention: draft.tomorrowIntention, recordID: draft.id)
        case .focus:
            return try saveSession(draft, mood: mood, themes: themes)
        case .weeklyReview:
            // The draft's civil day carries the zone the week was captured in.
            return try saveWeeklyReview(text: draft.text, nextIntention: draft.tomorrowIntention, weekStart: context.civilDay.start,
                                        timeZone: context.civilDay.timeZone, recordID: draft.id)
        case .note:
            if let practiceID = context.practiceID {
                return try savePracticeNote(text: draft.text, practiceID: practiceID, prompt: context.promptSnapshot ?? "",
                                            mood: mood, themes: themes, day: context.civilDay, recordID: draft.id)
            }
            return try saveNote(text: draft.text, mood: mood, themes: themes, day: context.civilDay, date: draft.createdAt,
                                recordID: draft.id)
        }
    }

    /// Recovered focus drafts write the note under the session's existing
    /// closing-note identity (never a second row) and restore the session's
    /// intention, outcome and energy, including when only those were set.
    private func saveSession(_ draft: JournalDraft, mood: Mood?, themes: ThemeSelection) throws -> SaveReceipt? {
        let sessionID = draft.context.sessionID ?? draft.id.uuidString
        let metadata = try sessionMetadata(sessionID: sessionID)
        // Drafts written before the editor dropped the intention field keep
        // their edited intention in `fields`.
        let intention = draft.fields["intention"] ?? draft.context.promptSnapshot ?? ""
        let completedAt = metadata?.completedAt ?? draft.createdAt
        var receipt: SaveReceipt?
        if !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            receipt = try saveFocusNote(text: draft.text, intention: intention, sessionID: sessionID, completedAt: completedAt,
                                        mood: mood, themes: themes, recordID: metadata?.closingNoteRecordID ?? draft.id)
        } else if let noteID = metadata?.closingNoteRecordID {
            try deleteEntry(id: noteID)
        }
        try upsertSessionMetadata(sessionID: sessionID, intention: intention.isEmpty ? nil : intention,
                                  outcome: FocusOutcome(rawValue: draft.outcome ?? ""), energy: EnergyLevel(rawValue: draft.energy ?? ""),
                                  closingNoteRecordID: receipt?.recordID, completedAt: completedAt)
        return receipt
    }
}
