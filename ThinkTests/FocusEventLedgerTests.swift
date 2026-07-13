//
//  FocusEventLedgerTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

@MainActor
struct FocusEventLedgerTests {

    @Test func appliedIDsUseAnInsertionOrderedFiftyEntryRing() {
        let defaults = makeDefaults()
        let ledger = FocusEventLedger(defaults: defaults)

        for index in 0..<51 {
            _ = ledger.recordApplied("event-\(index)")
        }

        #expect(ledger.appliedEventIDs.count == 50)
        #expect(!ledger.containsApplied("event-0"))
        #expect(ledger.containsApplied("event-1"))
        #expect(ledger.appliedEventIDs.last == "event-50")
        #expect(!ledger.recordApplied("event-50"))
    }

    @Test func pendingEventsPersistSortAndAcknowledgeByID() {
        let defaults = makeDefaults()
        let first = FocusSessionEvent(
            id: "first",
            completedAt: Date(timeIntervalSince1970: 2)
        )
        let second = FocusSessionEvent(
            id: "second",
            completedAt: Date(timeIntervalSince1970: 1)
        )
        let ledger = FocusEventLedger(defaults: defaults)

        #expect(ledger.addPending(first))
        #expect(ledger.addPending(second))
        #expect(!ledger.addPending(second))
        #expect(ledger.pendingEvents.map(\.id) == ["second", "first"])

        let restored = FocusEventLedger(defaults: defaults)
        #expect(restored.pendingEvents.map(\.id) == ["second", "first"])
        #expect(restored.acknowledgePending(["second"]))
        #expect(restored.pendingEvents.map(\.id) == ["first"])
        #expect(!restored.acknowledgePending(["missing"]))
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "ThinkTests.FocusEventLedger.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
