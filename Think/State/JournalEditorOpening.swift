//
//  JournalEditorOpening.swift
//  Think
//

import Foundation

/// Resolves the draft Today hands the editor for the day's answer or retro.
/// The context is captured once, when the sheet opens. Locked: a blank
/// draft, with no lookup of saved text or unsaved drafts. Unlocked: the
/// unsaved draft is resumed, and a written retro opens for Edit. Unreadable
/// draft files are reported but never block writing: a fresh draft has its
/// own identity, so it cannot overwrite the file that failed to read.
@MainActor
enum JournalEditorOpening {
    struct Opened {
        let draft: JournalDraft
        /// Shown in the editor above the writing, never instead of it.
        let notice: String?
    }

    static func answer(day: CivilDay, practiceID: String, prompt: String, locked: Bool,
                       drafts: JournalDraftStore) -> Opened {
        let blank = JournalDraft(kind: .answer, context: .init(civilDay: day, practiceID: practiceID, promptSnapshot: prompt))
        guard !locked else { return Opened(draft: blank, notice: nil) }
        let (listing, notice) = read(drafts, kind: .answer)
        let pending = listing?.drafts.first { $0.context.practiceID == practiceID && $0.context.civilDay.key == day.key }
        return Opened(draft: pending ?? blank, notice: notice)
    }

    /// With more than one version of the day's retro, the primary opens
    /// (`CONTEXT.md`: Version); the others stay reachable from the Journal.
    /// Throws when the written retro cannot be read, so the caller shows
    /// an error instead of a blank retro that would become a second version.
    static func retro(day: CivilDay, practiceID: String, prompt: String, locked: Bool,
                      repository: JournalRepository, drafts: JournalDraftStore) throws -> Opened {
        let blank = JournalDraft(kind: .retro, context: .init(civilDay: day, practiceID: practiceID, promptSnapshot: prompt))
        guard !locked else { return Opened(draft: blank, notice: nil) }
        let written = try repository.retro(for: day)?.primary
        let (listing, notice) = read(drafts, kind: .retro)
        if let written {
            if let recordID = written.recordID,
               let pending = listing?.drafts.first(where: { $0.context.editingRecordID == recordID }) {
                return Opened(draft: pending, notice: notice)
            }
            if let editing = JournalDraft.editing(written) { return Opened(draft: editing, notice: notice) }
        }
        let pending = listing?.drafts.first { $0.context.editingRecordID == nil && $0.context.civilDay.key == day.key }
        return Opened(draft: pending ?? blank, notice: notice)
    }

    /// The drafts of one kind, or nil with a notice when the folder itself
    /// cannot be read.
    private static func read(_ drafts: JournalDraftStore, kind: JournalDraft.Kind) -> (JournalDraftStore.Listing?, String?) {
        do {
            let listing = try drafts.listing(kind: kind)
            return (listing, listing.unreadableCount > 0
                ? String(localized: "An unsaved draft could not be read. It was left untouched; check Drafts in Journal.")
                : nil)
        } catch {
            return (nil, String(localized: "Unsaved drafts could not be checked. Your writing here starts fresh; earlier drafts were left untouched."))
        }
    }
}
