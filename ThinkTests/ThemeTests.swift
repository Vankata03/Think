//
//  ThemeTests.swift
//  ThinkTests
//

import Foundation
import SwiftData
import Testing
@testable import Think

@MainActor
struct ThemeSelectionTests {

    @Test func firstPickBecomesThePrimaryAndSecondPickTheSecondary() {
        var selection = ThemeSelection()

        selection.toggle(.work)
        #expect(selection.primary == .work)
        #expect(selection.secondary == nil)

        selection.toggle(.health)
        #expect(selection.primary == .work)
        #expect(selection.secondary == .health)
        #expect(selection.themes == [.work, .health])
    }

    @Test func aThirdPickReplacesTheSecondary() {
        var selection = ThemeSelection(primary: .work, secondary: .health)

        selection.toggle(.rest)

        #expect(selection.primary == .work)
        #expect(selection.secondary == .rest)
    }

    @Test func pickingTheSecondaryAgainClearsIt() {
        var selection = ThemeSelection(primary: .work, secondary: .health)

        selection.toggle(.health)

        #expect(selection.primary == .work)
        #expect(selection.secondary == nil)
    }

    @Test func clearingThePrimaryPromotesTheSecondary() {
        var selection = ThemeSelection(primary: .work, secondary: .health)

        selection.toggle(.work)

        #expect(selection.primary == .health)
        #expect(selection.secondary == nil)

        selection.toggle(.health)
        #expect(selection.isEmpty)
    }

    @Test func clearRemovesBothThemes() {
        var selection = ThemeSelection(primary: .money, secondary: .home)

        selection.clear()

        #expect(selection.primary == nil)
        #expect(selection.secondary == nil)
        #expect(selection.isEmpty)
    }
}

@MainActor
struct ThemeTests {

    @Test func theEightThemesAreFixed() {
        #expect(Theme.allCases.map(\.rawValue) == [
            "work", "people", "health", "money", "learning", "making", "home", "rest",
        ])
    }

    @Test func unrecognisedStoredValuesReadBackAsUntagged() {
        // A value written by a future version must degrade, not crash.
        #expect(Theme(stored: "travel") == nil)
        #expect(Theme(stored: nil) == nil)
        #expect(Theme(stored: "") == nil)
        #expect(Theme(stored: "money") == .money)
    }

    @Test func storedSelectionNeverKeepsASecondaryWithoutAPrimary() {
        #expect(ThemeSelection(stored: "work", secondary: "rest").themes == [.work, .rest])
        #expect(ThemeSelection(stored: "travel", secondary: "rest").themes == [.rest])
        #expect(ThemeSelection(stored: nil, secondary: "rest").themes == [.rest])
        #expect(ThemeSelection(stored: "work", secondary: "work").themes == [.work])
        #expect(ThemeSelection(stored: nil, secondary: nil).isEmpty)
    }

    @Test func exportLabelsAreEnglishInEveryLocale() {
        #expect(Theme.allCases.map(\.exportLabel) == [
            "Work", "People", "Health", "Money", "Learning", "Making", "Home", "Rest",
        ])
    }

    @Test(arguments: ["en", "bg", "de", "es", "fr", "it", "pt-BR"])
    func everyThemeHasALabelInEveryLocale(locale: String) throws {
        let path = try #require(
            Bundle.main.path(forResource: locale, ofType: "lproj"),
            "The app bundle has no \(locale).lproj"
        )
        let bundle = try #require(Bundle(path: path))
        let missing = "__missing__"
        for theme in Theme.allCases {
            // English labels are the catalog keys; the export label spells
            // them independently of the localised lookup.
            let label = bundle.localizedString(forKey: theme.exportLabel, value: missing, table: "Localizable")
            #expect(label != missing, "\(theme) has no \(locale) label")
            #expect(!label.isEmpty)
        }
    }
}

@MainActor
struct ThemeStorageTests {

    private func makeContext() throws -> ModelContext {
        // The app's own in-memory configuration claims no App Group
        // container and no CloudKit database, so it cannot collide with the
        // store the test host opened at launch.
        let container = try ModelContainer(
            for: JournalDataStore.schema,
            configurations: JournalDataStore.configuration(for: .inMemory)
        )
        return ModelContext(container)
    }

    @Test func recordsAreUntaggedByDefault() {
        let entry = JournalEntry(prompt: "", text: "A note.", kind: JournalEntry.kindNote)
        let retro = DailyRetro(wentWell: "Shipped.", improve: "", tomorrow: "")

        #expect(entry.theme == nil && entry.secondaryTheme == nil)
        #expect(retro.theme == nil && retro.secondaryTheme == nil)
    }

    @Test func taggedRecordsStoreTheRawValuesInOrder() {
        let entry = JournalEntry(
            prompt: "", text: "A note.", kind: JournalEntry.kindNote,
            themes: ThemeSelection(primary: .work, secondary: .people)
        )
        let retro = DailyRetro(
            wentWell: "Shipped.", improve: "", tomorrow: "",
            themes: ThemeSelection(primary: .rest)
        )

        #expect(entry.theme == "work")
        #expect(entry.secondaryTheme == "people")
        #expect(retro.theme == "rest")
        #expect(retro.secondaryTheme == nil)
    }

    @Test func weeklyReviewEntriesNeverCarryATheme() {
        let entry = JournalEntry(
            prompt: "Weekly review", text: "A good week.", kind: JournalEntry.kindWeeklyReview,
            themes: ThemeSelection(primary: .work, secondary: .people)
        )

        #expect(entry.theme == nil)
        #expect(entry.secondaryTheme == nil)
    }

    @Test func themePredicateMatchesEitherFieldOnEntries() throws {
        let context = try makeContext()
        context.insert(JournalEntry(prompt: "", text: "Primary.", kind: JournalEntry.kindNote,
                                    themes: ThemeSelection(primary: .health)))
        context.insert(JournalEntry(prompt: "", text: "Secondary.", kind: JournalEntry.kindQuestion,
                                    themes: ThemeSelection(primary: .work, secondary: .health)))
        context.insert(JournalEntry(prompt: "", text: "Other.", kind: JournalEntry.kindNote,
                                    themes: ThemeSelection(primary: .money)))
        context.insert(JournalEntry(prompt: "", text: "Untagged.", kind: JournalEntry.kindNote))
        try context.save()

        let matched = try context.fetch(FetchDescriptor(predicate: JournalEntry.predicate(theme: .health)))

        #expect(Set(matched.map(\.text)) == ["Primary.", "Secondary."])
    }

    @Test func themePredicateMatchesEitherFieldOnRetros() throws {
        let context = try makeContext()
        context.insert(DailyRetro(wentWell: "Primary.", improve: "", tomorrow: "",
                                  themes: ThemeSelection(primary: .learning, secondary: .rest)))
        context.insert(DailyRetro(wentWell: "Secondary.", improve: "", tomorrow: "",
                                  themes: ThemeSelection(primary: .home, secondary: .learning)))
        context.insert(DailyRetro(wentWell: "Untagged.", improve: "", tomorrow: ""))
        try context.save()

        let matched = try context.fetch(FetchDescriptor(predicate: DailyRetro.predicate(theme: .learning)))

        #expect(Set(matched.map(\.wentWell)) == ["Primary.", "Secondary."])
    }
}

@MainActor
struct ThemeExportTests {

    @Test func exportIncludesThemesOnlyForTaggedRecords() {
        let tagged = JournalEntry(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            prompt: "", text: "Tagged note.", kind: JournalEntry.kindNote,
            themes: ThemeSelection(primary: .work, secondary: .health)
        )
        let untagged = JournalEntry(
            date: Date(timeIntervalSince1970: 1_600_000_000),
            prompt: "", text: "Untagged note.", kind: JournalEntry.kindNote
        )
        let retro = DailyRetro(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            wentWell: "Shipped.", improve: "", tomorrow: "",
            themes: ThemeSelection(primary: .making)
        )
        let untaggedRetro = DailyRetro(
            date: Date(timeIntervalSince1970: 1_600_000_000),
            wentWell: "Rested.", improve: "", tomorrow: ""
        )

        let export = JournalExport(entries: [tagged, untagged], retrospectives: [retro, untaggedRetro])
        let text = export.text(locale: Locale(identifier: "de_DE"), timeZone: TimeZone(identifier: "UTC")!)

        // English names in primary-then-secondary order, whatever the locale.
        #expect(text.contains("Themes: Work, Health"))
        #expect(text.contains("Themes: Making"))
        // Two tagged records, so exactly two theme lines.
        #expect(text.components(separatedBy: "Themes: ").count == 3)
    }
}

/// The journal models as they were before themes, so a store written by the
/// previous release can be opened with today's schema.
private enum PreThemeSchema {
    @Model final class JournalEntry {
        var date: Date = Date()
        var prompt: String = ""
        var text: String = ""
        var kind: String = "question"
        var mood: String?
        var recordID: UUID?
        var civilDay: String?
        var timeZoneIdentifier: String?
        var practiceID: String?
        var sessionID: String?
        var updatedAt: Date?
        var periodKey: String?
        var nextIntention: String?

        init(text: String, mood: String?) {
            self.recordID = UUID(); self.text = text; self.kind = "note"; self.mood = mood
        }
    }

    @Model final class DailyRetro {
        var date: Date = Date()
        var wentWell: String = ""
        var improve: String = ""
        var tomorrow: String = ""
        var mood: String?
        var recordID: UUID?
        var civilDay: String?
        var timeZoneIdentifier: String?
        var practiceID: String?
        var promptSnapshot: String?
        var tomorrowIntention: String?
        var updatedAt: Date?

        init(wentWell: String) {
            self.recordID = UUID(); self.wentWell = wentWell
        }
    }

    @Model final class FocusSessionMetadata {
        var recordID: UUID?
        var sessionID: String = ""
        var intention: String?
        var outcome: String?
        var energy: String?
        var closingNoteRecordID: UUID?
        var completedAt: Date?
        var civilDay: String?
        var timeZoneIdentifier: String?
        var updatedAt: Date?

        init(sessionID: String) { self.sessionID = sessionID }
    }

    static var schema: Schema { Schema([JournalEntry.self, DailyRetro.self, FocusSessionMetadata.self]) }
}

@MainActor
struct ThemeMigrationTests {

    @Test func aStoreWrittenBeforeThemesOpensAndReadsBackUntagged() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThemeMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("journal.store")

        do {
            let legacy = try ModelContainer(
                for: PreThemeSchema.schema,
                configurations: ModelConfiguration(schema: PreThemeSchema.schema, url: url, cloudKitDatabase: .none)
            )
            let context = ModelContext(legacy)
            context.insert(PreThemeSchema.JournalEntry(text: "Old note.", mood: "steady"))
            context.insert(PreThemeSchema.DailyRetro(wentWell: "Old retro."))
            try context.save()
        }

        let current = try ModelContainer(
            for: JournalDataStore.schema,
            configurations: ModelConfiguration(schema: JournalDataStore.schema, url: url, cloudKitDatabase: .none)
        )
        let context = ModelContext(current)
        let entries = try context.fetch(FetchDescriptor<JournalEntry>())
        let retros = try context.fetch(FetchDescriptor<DailyRetro>())

        #expect(entries.map(\.text) == ["Old note."])
        #expect(entries.map(\.mood) == ["steady"])
        #expect(entries.allSatisfy { $0.theme == nil && $0.secondaryTheme == nil })
        #expect(retros.map(\.wentWell) == ["Old retro."])
        #expect(retros.allSatisfy { $0.theme == nil && $0.secondaryTheme == nil })

        // The migrated store takes themes like any new record.
        entries[0].setThemes(ThemeSelection(primary: .home))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor(predicate: JournalEntry.predicate(theme: .home))) == 1)
    }
}

@MainActor
struct ThemeRepositoryTests {
    private func repository() throws -> JournalRepository {
        let container = try ModelContainer(for: JournalDataStore.schema, configurations: JournalDataStore.configuration(for: .inMemory))
        return JournalRepository(modelContext: container.mainContext, storage: .inMemory)
    }

    @Test func savedEntriesAndRetrosReadBackWithTheirThemes() throws {
        let repository = try repository()
        let pair = ThemeSelection(primary: .people, secondary: .health)

        let answer = try repository.saveAnswer(text: "An answer.", prompt: "Why?", themes: pair)
        let note = try repository.saveNote(text: "A note.", themes: ThemeSelection(primary: .money))
        let practiceNote = try repository.savePracticeNote(text: "A practice note.", practiceID: "p1", prompt: "",
                                                           themes: ThemeSelection(primary: .making))
        let retro = try repository.saveRetro(wentWell: "Went well.", improve: "", tomorrow: "", themes: pair)

        #expect(try repository.entry(id: answer.recordID)?.themes == pair)
        #expect(try repository.entry(id: note.recordID)?.themes == ThemeSelection(primary: .money))
        #expect(try repository.entry(id: practiceNote.recordID)?.themes == ThemeSelection(primary: .making))
        #expect(try repository.retro(id: retro.recordID)?.themes == pair)
    }

    @Test func updatesChangeAndClearThemes() throws {
        let repository = try repository()
        let entry = try repository.saveNote(text: "A note.", themes: ThemeSelection(primary: .work))
        let retro = try repository.saveRetro(wentWell: "Went well.", improve: "", tomorrow: "",
                                             themes: ThemeSelection(primary: .rest))

        try repository.updateEntry(id: entry.recordID, text: "A note.", mood: nil,
                                   themes: ThemeSelection(primary: .learning, secondary: .work))
        try repository.updateRetro(id: retro.recordID, wentWell: "Went well.", improve: "", tomorrow: "", mood: nil,
                                   themes: ThemeSelection())

        #expect(try repository.entry(id: entry.recordID)?.themes == ThemeSelection(primary: .learning, secondary: .work))
        #expect(try repository.retro(id: retro.recordID)?.themes.isEmpty == true)
    }

    @Test func savesWithoutThemesLeaveStoredThemesAlone() throws {
        // Callers that do not edit themes (a draft resave, an edit from a
        // screen without the Theme chip) must not wipe them.
        let repository = try repository()
        let pair = ThemeSelection(primary: .home, secondary: .money)
        let entry = try repository.saveNote(text: "Draft.", themes: pair)
        let retro = try repository.saveRetro(wentWell: "Draft.", improve: "", tomorrow: "", themes: pair)

        try repository.saveNote(text: "Draft, resaved.", recordID: entry.recordID)
        try repository.updateEntry(id: entry.recordID, text: "Edited.", mood: .good)
        try repository.saveRetro(wentWell: "Draft, resaved.", improve: "", tomorrow: "", recordID: retro.recordID)
        try repository.updateRetro(id: retro.recordID, wentWell: "Edited.", improve: "", tomorrow: "", mood: .good)

        #expect(try repository.entry(id: entry.recordID)?.text == "Edited.")
        #expect(try repository.entry(id: entry.recordID)?.themes == pair)
        #expect(try repository.retro(id: retro.recordID)?.wentWell == "Edited.")
        #expect(try repository.retro(id: retro.recordID)?.themes == pair)
    }

    @Test func aDraftResavedWithNewThemesUpdatesThem() throws {
        let repository = try repository()
        let entry = try repository.saveNote(text: "Draft.", themes: ThemeSelection(primary: .home))

        try repository.saveNote(text: "Draft.", themes: ThemeSelection(primary: .rest), recordID: entry.recordID)

        let saved = try #require(try repository.entry(id: entry.recordID))
        #expect(saved.themes == ThemeSelection(primary: .rest))
        #expect(saved.updatedAt != nil)
    }

    @Test func weeklyReviewsNeverCarryATheme() throws {
        let repository = try repository()
        let review = try repository.saveWeeklyReview(text: "A good week.", nextIntention: nil, weekStart: .now)

        try repository.updateEntry(id: review.recordID, text: "A good week.", mood: nil,
                                   themes: ThemeSelection(primary: .work))

        #expect(try repository.entry(id: review.recordID)?.themes.isEmpty == true)
    }
}
