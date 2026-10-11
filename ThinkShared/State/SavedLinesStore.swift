//
//  SavedLinesStore.swift
//  Think
//

import Foundation
import Observation

nonisolated struct SavedLineRecord: Codable, Equatable, Identifiable, Sendable {
    let quoteID: String
    let savedAt: Date

    var id: String { quoteID }
}

/// Keeps the lines someone wants to come back to.
///
/// Saved lines are references, not copies: `Quote.id` is the stable catalog
/// key, so a saved line follows the user's language instead of freezing
/// the words that were on screen when they tapped. The price is that a
/// line removed from the library in a later release leaves a dangling ID,
/// which `lines` filters out rather than rendering blank.
@MainActor
@Observable
final class SavedLinesStore {
    static let storageKey = "favorites.quotes"

    private let defaults: UserDefaults
    private let now: () -> Date
    private(set) var records: [SavedLineRecord]

    init(defaults: UserDefaults = SharedDefaults.appGroup(), now: @escaping () -> Date = { .now }) {
        self.defaults = defaults
        self.now = now
        self.records = Self.decodeRecords(from: defaults)
    }

    /// Newest first, resolved against the library the app is running with.
    var lines: [Quote] {
        let quotesByID = Dictionary(
            ContentLibrary.quotes.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return records
            .sorted { $0.savedAt > $1.savedAt }
            .compactMap { quotesByID[$0.quoteID] }
    }

    var isEmpty: Bool { lines.isEmpty }

    func isSaved(_ quote: Quote) -> Bool {
        records.contains { $0.quoteID == quote.id }
    }

    @discardableResult
    func toggle(_ quote: Quote) -> Bool {
        if let index = records.firstIndex(where: { $0.quoteID == quote.id }) {
            records.remove(at: index)
            persist()
            return false
        }

        records.append(SavedLineRecord(quoteID: quote.id, savedAt: now()))
        persist()
        return true
    }

    func remove(_ quote: Quote) {
        guard let index = records.firstIndex(where: { $0.quoteID == quote.id }) else { return }
        records.remove(at: index)
        persist()
    }

    func removeAll() {
        guard !records.isEmpty else { return }
        records.removeAll()
        persist()
    }

    private func persist() {
        if records.isEmpty {
            defaults.removeObject(forKey: Self.storageKey)
        } else if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    private static func decodeRecords(from defaults: UserDefaults) -> [SavedLineRecord] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SavedLineRecord].self, from: data)
        else { return [] }

        // Drop empties and duplicates written by a damaged or older
        // payload; the store's own invariants are cheap to restore here.
        var seen = Set<String>()
        return decoded.filter { record in
            guard !record.quoteID.isEmpty, seen.insert(record.quoteID).inserted else { return false }
            return true
        }
    }
}
