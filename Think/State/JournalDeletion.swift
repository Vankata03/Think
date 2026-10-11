//
//  JournalDeletion.swift
//  Think
//

import Foundation

/// Deleting a Journal record and then any unsaved edit of it. The list's
/// swipe and the read detail share it, so both say the same thing on
/// failure (`design/journal.md` section 5).
enum JournalDeletion {
    enum Outcome: Equatable {
        /// The record and any unsaved edit are gone.
        case deleted
        /// The record is still there.
        case failed(String)
        /// The record is gone but its unsaved edit is not.
        case draftKept(String)

        /// Whether the record no longer exists.
        var recordRemoved: Bool {
            if case .failed = self { return false }
            return true
        }

        /// The message to show, if any.
        var notice: String? {
            switch self {
            case .deleted: nil
            case .failed(let message), .draftKept(let message): message
            }
        }
    }

    @MainActor
    static func delete(_ record: JournalRecordID, repository: JournalRepository, drafts: JournalDraftStore) -> Outcome {
        do {
            switch record {
            case .entry(let id): try repository.deleteEntry(id: id)
            case .retro(let id): try repository.deleteRetro(id: id)
            }
        } catch {
            return .failed(String(localized: "Could not delete this entry. It is still here. Try again."))
        }
        do {
            if let draft = try existingEditingDraft(for: record.uuid, in: drafts) {
                try drafts.delete(id: draft.id)
            }
        } catch {
            return .draftKept(String(localized: "Entry deleted. Its unsaved edit is still here; retry cleanup from Drafts."))
        }
        return .deleted
    }
}
