//
//  FocusHistoryIntentionsTests.swift
//  ThinkTests
//

import Foundation
import SwiftData
import Testing
@testable import Think

/// Private intentions on Focus history rows (`design/progress-settings.md`
/// section 2): read only while the journal is unlocked, and fail closed.
struct FocusHistoryIntentionsTests {

    private struct ReadFailure: Error {}

    @Test func unlockedJournalShowsEachStoredIntention() {
        let stored = ["a": "Write chapter 3", "b": "  ", "c": nil as String?]

        let intentions = FocusHistoryIntentions.load(sessionIDs: ["a", "b", "c", "d"], isLocked: false) { stored[$0] ?? nil }

        #expect(intentions == ["a": "Write chapter 3"])
    }

    @Test func lockedJournalReadsNothing() {
        var reads: [String] = []

        let intentions = FocusHistoryIntentions.load(sessionIDs: ["a"], isLocked: true) { id in
            reads.append(id)
            return "Write chapter 3"
        }

        #expect(intentions.isEmpty)
        #expect(reads.isEmpty)
    }

    @Test func unreadableMetadataShowsNoIntentionAtAll() {
        let intentions = FocusHistoryIntentions.load(sessionIDs: ["a", "b"], isLocked: false) { id in
            if id == "b" { throw ReadFailure() }
            return "Write chapter 3"
        }

        #expect(intentions.isEmpty)
    }

    @MainActor
    @Test func readsTheIntentionFromTheJournalRepository() throws {
        let container = try ModelContainer(
            for: JournalDataStore.schema, configurations: JournalDataStore.configuration(for: .inMemory))
        let repository = JournalRepository(modelContext: container.mainContext, storage: .inMemory)
        try repository.upsertSessionMetadata(sessionID: "s1", intention: "Plan the week")

        let intentions = FocusHistoryIntentions.load(sessionIDs: ["s1", "s2"], isLocked: false, repository: repository)

        #expect(intentions == ["s1": "Plan the week"])
    }
}
