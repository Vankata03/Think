//
//  MoodTests.swift
//  ThinkTests
//

import Foundation
import SwiftData
import Testing
@testable import Think

@MainActor
struct MoodTests {

    @Test func entriesAreUntaggedByDefault() {
        let entry = JournalEntry(prompt: "", text: "A note.", kind: JournalEntry.kindNote)
        let retro = DailyRetro(wentWell: "Shipped.", improve: "", tomorrow: "")

        #expect(entry.mood == nil)
        #expect(retro.mood == nil)
        #expect(Mood(stored: entry.mood) == nil)
    }

    @Test func taggedEntriesStoreTheRawValue() {
        let entry = JournalEntry(
            prompt: "",
            text: "A note.",
            kind: JournalEntry.kindNote,
            mood: .steady
        )

        #expect(entry.mood == "steady")
        #expect(Mood(stored: entry.mood) == .steady)
    }

    @Test func unrecognisedStoredValueReadsBackAsUntagged() {
        // A value written by a future version must degrade, not crash.
        #expect(Mood(stored: "euphoric") == nil)
        #expect(Mood(stored: nil) == nil)
        #expect(Mood(stored: "") == nil)
    }

    @Test func everyMoodHasALabelAndSymbol() {
        for mood in Mood.allCases {
            #expect(!mood.label.isEmpty)
            #expect(!mood.systemImage.isEmpty)
        }
        #expect(Mood.allCases.count == 5)
    }

    @Test func moodSurvivesAStoreRoundTrip() throws {
        // Uses the app's own in-memory configuration, which claims no App
        // Group container and no CloudKit database, so it cannot collide
        // with the store the test host opened at launch.
        let container = try ModelContainer(
            for: JournalDataStore.schema,
            configurations: JournalDataStore.configuration(for: .inMemory)
        )
        let context = ModelContext(container)
        context.insert(
            JournalEntry(prompt: "", text: "Tagged.", kind: JournalEntry.kindNote, mood: .sharp)
        )
        context.insert(DailyRetro(wentWell: "Done.", improve: "", tomorrow: "", mood: .low))
        try context.save()

        let entries = try context.fetch(FetchDescriptor<JournalEntry>())
        let retros = try context.fetch(FetchDescriptor<DailyRetro>())
        #expect(entries.map { Mood(stored: $0.mood) } == [.sharp])
        #expect(retros.map { Mood(stored: $0.mood) } == [.low])
    }

    @Test func exportIncludesMoodOnlyForTaggedRecords() {
        let tagged = JournalEntry(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            prompt: "",
            text: "Tagged note.",
            kind: JournalEntry.kindNote,
            mood: .good
        )
        let untagged = JournalEntry(
            date: Date(timeIntervalSince1970: 1_600_000_000),
            prompt: "",
            text: "Untagged note.",
            kind: JournalEntry.kindNote
        )
        let retro = DailyRetro(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            wentWell: "Shipped.",
            improve: "",
            tomorrow: "",
            mood: .flat
        )

        let export = JournalExport(entries: [tagged, untagged], retrospectives: [retro])
        let text = export.text(locale: Locale(identifier: "en_US"), timeZone: TimeZone(identifier: "UTC")!)

        #expect(text.contains("Mood: \(Mood.good.label)"))
        #expect(text.contains("Mood: \(Mood.flat.label)"))
        // Two tagged records, so exactly two mood lines.
        #expect(text.components(separatedBy: "Mood: ").count == 3)
    }
}
