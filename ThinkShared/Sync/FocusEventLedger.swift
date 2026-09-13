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

    private static let seenIDsKey = "sync.phone.seenEventIDs.v1"
    private var seenIDs: Set<String>
    var resetBoundary: SyncResetBoundary? { SharedDefaults.resetBoundary(in: defaults) }
    private let defaults: UserDefaults
    private(set) var appliedEventIDs: [String]
    private(set) var pendingEvents: [FocusSessionEvent]

    init(defaults: UserDefaults) {
        self.defaults = defaults
        seenIDs = Set(defaults.stringArray(forKey: Self.seenIDsKey) ?? defaults.stringArray(forKey: Self.appliedEventIDsKey) ?? [])
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
        seenIDs.contains(eventID)
    }

    @discardableResult
    func recordApplied(_ eventID: String) -> Bool {
        guard !containsApplied(eventID) else { return false }
        seenIDs.insert(eventID)
        defaults.set(Array(seenIDs), forKey: Self.seenIDsKey)
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

    func refreshAcknowledgement(_ id: String) {
        guard seenIDs.contains(id) else { return }
        appliedEventIDs.removeAll { $0 == id }
        appliedEventIDs.append(id)
        appliedEventIDs = Array(appliedEventIDs.suffix(Self.maxAppliedEventIDs))
        persistAppliedEventIDs()
    }

    func installResetBoundary(_ boundary: SyncResetBoundary) {
        SharedDefaults.setResetBoundary(boundary, in: defaults)
        pendingEvents.removeAll { $0.resetBoundary != boundary }
        appliedEventIDs = []
        seenIDs = []
        defaults.set([], forKey: Self.seenIDsKey)
        persistAppliedEventIDs(); persistPendingEvents()
    }

    func accepts(_ event: FocusSessionEvent) -> Bool {
        guard event.hasValidIdentity, event.resetBoundary == resetBoundary else { return false }
        if let resetBoundary, event.completedAt < resetBoundary.date { return false }
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
