//
//  SavedLinesStoreTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

@MainActor
struct SavedLinesStoreTests {

    /// Renamed in Swift only: lines saved by earlier builds live under this key.
    @Test func savedLinesKeepTheirStorageKey() {
        #expect(SavedLinesStore.storageKey == "favorites.quotes")
    }

    @Test func togglingAddsThenRemoves() {
        let store = SavedLinesStore(defaults: makeDefaults())
        let quote = ContentLibrary.quotes[0]

        #expect(!store.isSaved(quote))
        #expect(store.toggle(quote))
        #expect(store.isSaved(quote))
        #expect(store.lines.map(\.id) == [quote.id])

        #expect(store.toggle(quote) == false)
        #expect(!store.isSaved(quote))
        #expect(store.lines.isEmpty)
    }

    @Test func savedLinesAreNewestFirst() {
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = SavedLinesStore(defaults: makeDefaults(), now: { now })

        store.toggle(ContentLibrary.quotes[0])
        now = now.addingTimeInterval(60)
        store.toggle(ContentLibrary.quotes[1])
        now = now.addingTimeInterval(60)
        store.toggle(ContentLibrary.quotes[2])

        #expect(store.lines.map(\.id) == [
            ContentLibrary.quotes[2].id,
            ContentLibrary.quotes[1].id,
            ContentLibrary.quotes[0].id,
        ])
    }

    @Test func savedLinesSurviveAStoreRebuild() {
        let defaults = makeDefaults()
        let first = SavedLinesStore(defaults: defaults)
        first.toggle(ContentLibrary.quotes[3])

        let second = SavedLinesStore(defaults: defaults)

        #expect(second.isSaved(ContentLibrary.quotes[3]))
        #expect(second.lines.count == 1)
    }

    @Test func anIDThatNoLongerExistsIsDroppedFromTheList() throws {
        let defaults = makeDefaults()
        let records = [
            SavedLineRecord(quoteID: ContentLibrary.quotes[0].id, savedAt: Date(timeIntervalSince1970: 2)),
            // A line removed from the library in a later release.
            SavedLineRecord(quoteID: "practice.999", savedAt: Date(timeIntervalSince1970: 1)),
        ]
        defaults.set(try JSONEncoder().encode(records), forKey: SavedLinesStore.storageKey)

        let store = SavedLinesStore(defaults: defaults)

        #expect(store.lines.map(\.id) == [ContentLibrary.quotes[0].id])
    }

    @Test func aDamagedPayloadReadsBackAsEmpty() {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: SavedLinesStore.storageKey)

        let store = SavedLinesStore(defaults: defaults)

        #expect(store.lines.isEmpty)
        #expect(store.records.isEmpty)
    }

    @Test func duplicateRecordsCollapseToOne() throws {
        let defaults = makeDefaults()
        let quote = ContentLibrary.quotes[0]
        let records = [
            SavedLineRecord(quoteID: quote.id, savedAt: Date(timeIntervalSince1970: 1)),
            SavedLineRecord(quoteID: quote.id, savedAt: Date(timeIntervalSince1970: 2)),
            SavedLineRecord(quoteID: "", savedAt: Date(timeIntervalSince1970: 3)),
        ]
        defaults.set(try JSONEncoder().encode(records), forKey: SavedLinesStore.storageKey)

        let store = SavedLinesStore(defaults: defaults)

        #expect(store.records.count == 1)
        #expect(store.lines.map(\.id) == [quote.id])
    }

    /// Storing the catalog key rather than the rendered text is what keeps
    /// a saved line localized: the same record resolves to whatever the
    /// current language renders for that key.
    @Test func recordsStoreTheCatalogKeyNotTheRenderedText() {
        let store = SavedLinesStore(defaults: makeDefaults())
        let quote = ContentLibrary.quotes[0]

        store.toggle(quote)

        let record = try? #require(store.records.first)
        #expect(record?.quoteID == quote.id)
        #expect(record?.quoteID != quote.text)
        #expect(record?.quoteID.hasPrefix("practice.") == true)
    }

    @Test func removeAllClearsBothMemoryAndStorage() {
        let defaults = makeDefaults()
        let store = SavedLinesStore(defaults: defaults)
        store.toggle(ContentLibrary.quotes[0])
        store.toggle(ContentLibrary.quotes[1])

        store.removeAll()

        #expect(store.lines.isEmpty)
        #expect(defaults.data(forKey: SavedLinesStore.storageKey) == nil)
        #expect(SavedLinesStore(defaults: defaults).lines.isEmpty)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "ThinkTests.Favorites.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
