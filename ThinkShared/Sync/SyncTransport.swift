//
//  SyncTransport.swift
//  Think
//

import Foundation

/// Typed representation of the property-list dictionary sent through
/// WatchConnectivity. Only Data blobs and the schema Int cross the boundary.
nonisolated struct SyncTransportPayload: Equatable, Sendable {
    let schemaVersion: Int
    let timer: Data?
    let progressSnapshot: Data?
    let focusSessionEvent: Data?

    init(
        schemaVersion: Int = SyncSchema.currentVersion,
        timer: Data? = nil,
        progressSnapshot: Data? = nil,
        focusSessionEvent: Data? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.timer = timer
        self.progressSnapshot = progressSnapshot
        self.focusSessionEvent = focusSessionEvent
    }

    var propertyList: [String: Any] {
        var values: [String: Any] = [SyncContextKey.schemaVersion: schemaVersion]
        if let timer {
            values[SyncContextKey.timer] = timer
        }
        if let progressSnapshot {
            values[SyncContextKey.progressSnapshot] = progressSnapshot
        }
        if let focusSessionEvent {
            values[SyncContextKey.focusSessionEvent] = focusSessionEvent
        }
        return values
    }
}

/// Sendable copy of a received WatchConnectivity dictionary. The dictionary
/// itself never crosses an actor boundary.
nonisolated struct SyncInboundEnvelope: Equatable, Sendable {
    let schemaVersion: Int
    let timer: Data?
    let progressSnapshot: Data?
    let focusSessionEvent: Data?

    init?(propertyList values: [String: Any]) {
        guard let schemaVersion = values[SyncContextKey.schemaVersion] as? Int,
              schemaVersion == SyncSchema.currentVersion else { return nil }

        self.schemaVersion = schemaVersion
        timer = values[SyncContextKey.timer] as? Data
        progressSnapshot = values[SyncContextKey.progressSnapshot] as? Data
        focusSessionEvent = values[SyncContextKey.focusSessionEvent] as? Data
    }

    init(payload: SyncTransportPayload) {
        schemaVersion = payload.schemaVersion
        timer = payload.timer
        progressSnapshot = payload.progressSnapshot
        focusSessionEvent = payload.focusSessionEvent
    }
}

@MainActor
protocol SyncTransportDelegate: AnyObject {
    func syncTransportDidActivate(_ transport: any SyncTransport)
    func syncTransport(_ transport: any SyncTransport, didReceive envelope: SyncInboundEnvelope)
}

@MainActor
protocol SyncTransport: AnyObject {
    var isAvailable: Bool { get }
    var isReachable: Bool { get }

    func setDelegate(_ delegate: (any SyncTransportDelegate)?)
    func activate()
    func sendMessage(_ payload: SyncTransportPayload)
    func updateApplicationContext(_ payload: SyncTransportPayload) throws
    func transferUserInfo(_ payload: SyncTransportPayload)
}

/// Used by UI tests and unsupported environments. It intentionally has no
/// persistence or side effects.
@MainActor
class NoopSyncTransport: SyncTransport {
    let isAvailable = false
    let isReachable = false

    func setDelegate(_ delegate: (any SyncTransportDelegate)?) { }
    func activate() { }
    func sendMessage(_ payload: SyncTransportPayload) { }
    func updateApplicationContext(_ payload: SyncTransportPayload) throws { }
    func transferUserInfo(_ payload: SyncTransportPayload) { }
}
