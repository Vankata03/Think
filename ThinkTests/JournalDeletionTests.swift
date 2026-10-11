import Foundation
import SwiftData
import Testing

@testable import Think

/// Deleting a record and then its unsaved edit (`design/journal.md`
/// section 5). The detail pops whenever the record is gone, whatever
/// happened to the edit.
@MainActor struct JournalDeletionTests {
    private func makeRepository(interceptor: (() throws -> Void)? = nil) throws -> JournalRepository {
        let container = try ModelContainer(for: JournalDataStore.schema, configurations: JournalDataStore.configuration(for: .inMemory))
        return JournalRepository(modelContext: container.mainContext, storage: .inMemory, commitInterceptor: interceptor)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    @Test func deletingARecordWithNoEditSaysNothing() throws {
        let repository = try makeRepository()
        let drafts = JournalDraftStore(directory: temporaryDirectory())
        let id = try repository.saveNote(text: "Groceries").recordID

        let outcome = JournalDeletion.delete(.entry(id), repository: repository, drafts: drafts)

        #expect(outcome == .deleted)
        #expect(outcome.recordRemoved)
        #expect(outcome.notice == nil)
        #expect(try repository.entry(id: id) == nil)
    }

    @Test func deletingARecordAlsoRemovesItsUnsavedEdit() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try makeRepository()
        let drafts = JournalDraftStore(directory: directory)
        let id = try repository.saveNote(text: "Groceries").recordID
        try drafts.save(JournalDraft(kind: .note, context: .init(editingRecordID: id)))

        let outcome = JournalDeletion.delete(.entry(id), repository: repository, drafts: drafts)

        #expect(outcome == .deleted)
        #expect(try drafts.drafts().isEmpty)
    }

    @Test func aFailedDeleteLeavesTheRecordAndSaysSo() throws {
        enum Failure: Error { case injected }
        var fail = false
        let repository = try makeRepository(interceptor: { if fail { throw Failure.injected } })
        let id = try repository.saveNote(text: "Keep me").recordID
        fail = true

        let outcome = JournalDeletion.delete(
            .entry(id), repository: repository, drafts: JournalDraftStore(directory: temporaryDirectory()))

        #expect(outcome == .failed("Could not delete this entry. It is still here. Try again."))
        #expect(!outcome.recordRemoved)
        fail = false
        #expect(try repository.entry(id: id) != nil)
    }

    /// The record is gone, so the detail must pop; the message tells the
    /// owner the edit remains in Drafts.
    @Test func aFailedEditCleanupStillRemovesTheRecordAndKeepsTheMessage() throws {
        let directory = temporaryDirectory()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try? FileManager.default.removeItem(at: directory)
        }
        let repository = try makeRepository()
        let drafts = JournalDraftStore(directory: directory)
        let id = try repository.saveNote(text: "Groceries").recordID
        try drafts.save(JournalDraft(kind: .note, context: .init(editingRecordID: id)))
        // Read-only directory: the draft is found but cannot be removed.
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)

        let outcome = JournalDeletion.delete(.entry(id), repository: repository, drafts: drafts)

        #expect(outcome == .draftKept("Entry deleted. Its unsaved edit is still here; retry cleanup from Drafts."))
        #expect(outcome.recordRemoved)
        #expect(try repository.entry(id: id) == nil)
    }

    @Test func retrosDeleteThroughTheSamePath() throws {
        let repository = try makeRepository()
        let drafts = JournalDraftStore(directory: temporaryDirectory())
        let receipt = try repository.saveRetro(wentWell: "Shipped", improve: "Email", tomorrow: "Rest")

        let outcome = JournalDeletion.delete(.retro(receipt.recordID), repository: repository, drafts: drafts)

        #expect(outcome == .deleted)
        #expect(try repository.retro(id: receipt.recordID) == nil)
    }
}
