//
//  FocusHistoryIntentions.swift
//  Think
//

import Foundation

/// The private intention shown on a Focus history row
/// (`design/progress-settings.md` section 2). Nothing is read while the
/// journal is locked, and one unreadable session hides every intention:
/// the rows then show their timing and status only.
enum FocusHistoryIntentions {
    static func load(
        sessionIDs: [String],
        isLocked: Bool,
        read: (String) throws -> String?
    ) -> [String: String] {
        guard !isLocked else { return [:] }
        var intentions: [String: String] = [:]
        do {
            for id in sessionIDs {
                let text = try read(id)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !text.isEmpty { intentions[id] = text }
            }
        } catch {
            return [:]
        }
        return intentions
    }

    @MainActor
    static func load(sessionIDs: [String], isLocked: Bool, repository: JournalRepository) -> [String: String] {
        load(sessionIDs: sessionIDs, isLocked: isLocked) { id in
            try repository.sessionMetadata(sessionID: id)?.intention
        }
    }
}
