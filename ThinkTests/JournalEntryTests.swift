//
//  JournalEntryTests.swift
//  ThinkTests
//

import SwiftData
import Testing
@testable import Think

@MainActor
struct JournalEntryTests {

    @Test func questionEntryStoresPromptTextAndKind() {
        let entry = JournalEntry(prompt: "What matters?", text: "Focus.", kind: JournalEntry.kindQuestion)

        #expect(entry.prompt == "What matters?")
        #expect(entry.text == "Focus.")
        #expect(entry.kind == JournalEntry.kindQuestion)
    }

    @Test func journalEntriesPersistInInMemorySwiftDataContainer() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: JournalEntry.self, configurations: configuration)
        let context = ModelContext(container)
        let entry = JournalEntry(prompt: "", text: "A private note.", kind: JournalEntry.kindNote)

        context.insert(entry)
        try context.save()

        let descriptor = FetchDescriptor<JournalEntry>()
        let entries = try context.fetch(descriptor)
        #expect(entries.map(\.text) == ["A private note."])
        #expect(entries.map(\.kind) == [JournalEntry.kindNote])
    }
}
