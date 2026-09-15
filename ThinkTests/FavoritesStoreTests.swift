//
//  FavoritesStoreTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

@MainActor
struct FavoritesStoreTests {

    @Test func togglingAddsThenRemoves() {
        let store = FavoritesStore(defaults: makeDefaults())
        let quote = ContentLibrary.quotes[0]

        #expect(!store.isFavorite(quote))
        #expect(store.toggle(quote))
        #expect(store.isFavorite(quote))
        #expect(store.favorites.map(\.id) == [quote.id])

        #expect(store.toggle(quote) == false)
        #expect(!store.isFavorite(quote))
        #expect(store.favorites.isEmpty)
    }

    @Test func favoritesAreNewestFirst() {
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = FavoritesStore(defaults: makeDefaults(), now: { now })

        store.toggle(ContentLibrary.quotes[0])
        now = now.addingTimeInterval(60)
        store.toggle(ContentLibrary.quotes[1])
        now = now.addingTimeInterval(60)
        store.toggle(ContentLibrary.quotes[2])

        #expect(store.favorites.map(\.id) == [
            ContentLibrary.quotes[2].id,
            ContentLibrary.quotes[1].id,
            ContentLibrary.quotes[0].id,
        ])
    }

    @Test func savedLinesSurviveAStoreRebuild() {
        let defaults = makeDefaults()
        let first = FavoritesStore(defaults: defaults)
        first.toggle(ContentLibrary.quotes[3])

        let second = FavoritesStore(defaults: defaults)

        #expect(second.isFavorite(ContentLibrary.quotes[3]))
        #expect(second.favorites.count == 1)
    }

    @Test func anIDThatNoLongerExistsIsDroppedFromTheList() throws {
        let defaults = makeDefaults()
        let records = [
            FavoriteRecord(quoteID: ContentLibrary.quotes[0].id, savedAt: Date(timeIntervalSince1970: 2)),
            // A line removed from the library in a later release.
            FavoriteRecord(quoteID: "practice.999", savedAt: Date(timeIntervalSince1970: 1)),
        ]
        defaults.set(try JSONEncoder().encode(records), forKey: FavoritesStore.storageKey)

        let store = FavoritesStore(defaults: defaults)

        #expect(store.favorites.map(\.id) == [ContentLibrary.quotes[0].id])
    }

    @Test func aDamagedPayloadReadsBackAsEmpty() {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: FavoritesStore.storageKey)

        let store = FavoritesStore(defaults: defaults)

        #expect(store.favorites.isEmpty)
        #expect(store.records.isEmpty)
    }

    @Test func duplicateRecordsCollapseToOne() throws {
        let defaults = makeDefaults()
        let quote = ContentLibrary.quotes[0]
        let records = [
            FavoriteRecord(quoteID: quote.id, savedAt: Date(timeIntervalSince1970: 1)),
            FavoriteRecord(quoteID: quote.id, savedAt: Date(timeIntervalSince1970: 2)),
            FavoriteRecord(quoteID: "", savedAt: Date(timeIntervalSince1970: 3)),
        ]
        defaults.set(try JSONEncoder().encode(records), forKey: FavoritesStore.storageKey)

        let store = FavoritesStore(defaults: defaults)

        #expect(store.records.count == 1)
        #expect(store.favorites.map(\.id) == [quote.id])
    }

    /// Storing the catalog key rather than the rendered text is what keeps
    /// a saved line localized: the same record resolves to whatever the
    /// current language renders for that key.
    @Test func recordsStoreTheCatalogKeyNotTheRenderedText() {
        let store = FavoritesStore(defaults: makeDefaults())
        let quote = ContentLibrary.quotes[0]

        store.toggle(quote)

        let record = try? #require(store.records.first)
        #expect(record?.quoteID == quote.id)
        #expect(record?.quoteID != quote.text)
        #expect(record?.quoteID.hasPrefix("practice.") == true)
    }

    @Test func removeAllClearsBothMemoryAndStorage() {
        let defaults = makeDefaults()
        let store = FavoritesStore(defaults: defaults)
        store.toggle(ContentLibrary.quotes[0])
        store.toggle(ContentLibrary.quotes[1])

        store.removeAll()

        #expect(store.favorites.isEmpty)
        #expect(defaults.data(forKey: FavoritesStore.storageKey) == nil)
        #expect(FavoritesStore(defaults: defaults).favorites.isEmpty)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "ThinkTests.Favorites.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
