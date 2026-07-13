//
//  FocusEventLedger.swift
//  Think
//

import Foundation

@MainActor
final class FocusEventLedger {
    static let appliedEventIDsKey = "sync.phone.appliedEventIDs"
    static let pendingEventsKey = "sync.watch.pendingEvents"
    static let maxAppliedEventIDs = 50

    private let defaults: UserDefaults
    private(set) var appliedEventIDs: [String]
    private(set) var pendingEvents: [FocusSessionEvent]

    init(defaults: UserDefaults) {
        self.defaults = defaults
        appliedEventIDs = defaults.stringArray(forKey: Self.appliedEventIDsKey) ?? []
        if let data = defaults.data(forKey: Self.pendingEventsKey),
           let events = try? SyncCodec.decode([FocusSessionEvent].self, from: data) {
            pendingEvents = Self.sorted(events)
        } else {
            pendingEvents = []
        }

        if appliedEventIDs.count > Self.maxAppliedEventIDs {
            appliedEventIDs = Array(appliedEventIDs.suffix(Self.maxAppliedEventIDs))
            persistAppliedEventIDs()
        }
    }

    func containsApplied(_ eventID: String) -> Bool {
        appliedEventIDs.contains(eventID)
    }

    @discardableResult
    func recordApplied(_ eventID: String) -> Bool {
        guard !containsApplied(eventID) else { return false }
        appliedEventIDs.append(eventID)
        if appliedEventIDs.count > Self.maxAppliedEventIDs {
            appliedEventIDs.removeFirst(appliedEventIDs.count - Self.maxAppliedEventIDs)
        }
        persistAppliedEventIDs()
        return true
    }

    @discardableResult
    func addPending(_ event: FocusSessionEvent) -> Bool {
        guard !pendingEvents.contains(where: { $0.id == event.id }) else { return false }
        pendingEvents.append(event)
        pendingEvents = Self.sorted(pendingEvents)
        persistPendingEvents()
        return true
    }

    @discardableResult
    func acknowledgePending(_ eventIDs: Set<String>) -> Bool {
        let remaining = pendingEvents.filter { !eventIDs.contains($0.id) }
        guard remaining.count != pendingEvents.count else { return false }
        pendingEvents = remaining
        persistPendingEvents()
        return true
    }

    private func persistAppliedEventIDs() {
        defaults.set(appliedEventIDs, forKey: Self.appliedEventIDsKey)
    }

    private func persistPendingEvents() {
        guard let data = try? SyncCodec.encode(pendingEvents) else { return }
        defaults.set(data, forKey: Self.pendingEventsKey)
    }

    private static func sorted(_ events: [FocusSessionEvent]) -> [FocusSessionEvent] {
        events.sorted {
            if $0.completedAt != $1.completedAt {
                return $0.completedAt < $1.completedAt
            }
            return $0.id < $1.id
        }
    }
}
