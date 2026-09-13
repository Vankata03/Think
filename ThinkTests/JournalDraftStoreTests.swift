import Foundation
import Testing
@testable import Think

@MainActor struct JournalDraftStoreTests {
    @Test func relaunchPreservesOriginalDayZonePromptAndID() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let day = CivilDay(year: 2026, month: 9, day: 11, timeZoneIdentifier: "Europe/Sofia")
        var draft = JournalDraft(kind: .answer, context: .init(civilDay: day, practiceID: "practice.002", promptSnapshot: "Original question"))
        draft.text = "Unfinished answer"
        try JournalDraftStore(directory: directory).save(draft)
        let recovered = try #require(try JournalDraftStore(directory: directory).draft(id: draft.id))
        #expect(recovered.id == draft.id && recovered.context == draft.context && recovered.text == draft.text)
        #expect(recovered.context.civilDay != day.next)
        #expect(recovered.containsPrivateContent)
    }
    @Test func blankCaptureNeedsNoRecoveryGateAndErrorsAreExplicit() throws {
        #expect(!JournalDraft(kind: .note).containsPrivateContent)
        let location = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("not a directory".utf8).write(to: location)
        defer { try? FileManager.default.removeItem(at: location) }
        #expect(throws: JournalDraftStore.StoreError.self) { try JournalDraftStore(directory: location).save(JournalDraft(kind: .note)) }
    }
    @Test func malformedDraftIsNotSilentlyDiscardedAndDoesNotHideOthers() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let broken = directory.appendingPathComponent(UUID().uuidString + ".json")
        try Data("broken".utf8).write(to: broken)
        try Data("{}".utf8).write(to: directory.appendingPathComponent("garbage.json"))
        let store = JournalDraftStore(directory: directory)
        var healthy = JournalDraft(kind: .note); healthy.text = "Still here"
        try store.save(healthy)
        let listing = try store.listing()
        #expect(listing.drafts.map(\.id) == [healthy.id])
        #expect(listing.unreadableCount == 2)
        #expect(try store.recoverableDrafts().map(\.id) == [healthy.id])
        #expect(try store.recoverableListing().unreadableCount == 2)
        // The unreadable files remain on disk for a build that can read them.
        #expect(FileManager.default.fileExists(atPath: broken.path))
        #expect(throws: JournalDraftStore.StoreError.self) {
            try store.draft(id: UUID(uuidString: broken.deletingPathExtension().lastPathComponent)!)
        }
    }
    @Test func blankCaptureBesideUnreadableDraftLeavesItUntouched() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let broken = directory.appendingPathComponent(UUID().uuidString + ".json")
        try Data("broken".utf8).write(to: broken)
        let store = JournalDraftStore(directory: directory)
        // Today's answer lookup no longer throws; a fresh draft has its own file.
        #expect(try store.answerDraft(practiceID: "practice.001", day: .today()) == nil)
        var fresh = JournalDraft(kind: .answer, context: .init(practiceID: "practice.001")); fresh.text = "New"
        try store.save(fresh)
        #expect(try Data(contentsOf: broken) == Data("broken".utf8))
        #expect(try store.listing(kind: .answer).drafts.map(\.id) == [fresh.id])
    }
}
