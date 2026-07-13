//
//  MockSyncTransport.swift
//  ThinkTests
//

import Foundation
@testable import Think

@MainActor
final class MockSyncTransport: SyncTransport {
    private final class Link {
        var reachable = true
        var endpoints: [MockSyncTransport] = []

        func flush() {
            endpoints.forEach { $0.flushOutbound() }
            endpoints.forEach { $0.flushInbound() }
        }
    }

    private let link: Link
    private weak var peer: MockSyncTransport?
    private weak var delegate: (any SyncTransportDelegate)?
    private var inboundApplicationContext: SyncTransportPayload?
    private var hasUndeliveredApplicationContext = false
    private var inboundUserInfo: [SyncTransportPayload] = []
    private var outboundApplicationContext: SyncTransportPayload?
    private var outboundUserInfo: [SyncTransportPayload] = []
    private(set) var sentMessages: [SyncTransportPayload] = []
    private(set) var receivedEnvelopes: [SyncInboundEnvelope] = []
    private(set) var activated = false
    var isAvailable = true

    var isReachable: Bool {
        isAvailable && link.reachable
    }

    private init(link: Link) {
        self.link = link
    }

    static func paired() -> (MockSyncTransport, MockSyncTransport) {
        let link = Link()
        let first = MockSyncTransport(link: link)
        let second = MockSyncTransport(link: link)
        first.peer = second
        second.peer = first
        link.endpoints = [first, second]
        return (first, second)
    }

    func setDelegate(_ delegate: (any SyncTransportDelegate)?) {
        self.delegate = delegate
    }

    func activate() {
        activated = true
        delegate?.syncTransportDidActivate(self)
        flushInbound()
    }

    func sendMessage(_ payload: SyncTransportPayload) {
        guard isAvailable, isReachable, let peer, peer.isAvailable else { return }
        sentMessages.append(payload)
        peer.receive(payload)
    }

    func updateApplicationContext(_ payload: SyncTransportPayload) throws {
        guard isAvailable else { return }
        outboundApplicationContext = payload
        if isReachable {
            flushOutboundContext()
        }
    }

    func transferUserInfo(_ payload: SyncTransportPayload) {
        guard isAvailable else { return }
        outboundUserInfo.append(payload)
        if isReachable {
            flushOutboundUserInfo()
        }
    }

    func setReachable(_ reachable: Bool) {
        link.reachable = reachable
        if reachable {
            link.flush()
        }
    }

    func flush() {
        link.flush()
    }

    func setAvailable(_ available: Bool) {
        isAvailable = available
    }

    private func flushOutbound() {
        guard isReachable else { return }
        flushOutboundContext()
        flushOutboundUserInfo()
    }

    private func flushOutboundContext() {
        guard isReachable, let outboundApplicationContext, let peer, peer.isAvailable else { return }
        peer.receiveApplicationContext(outboundApplicationContext)
    }

    private func flushOutboundUserInfo() {
        guard isReachable, let peer, peer.isAvailable else { return }
        while !outboundUserInfo.isEmpty {
            peer.receiveUserInfo(outboundUserInfo.removeFirst())
        }
    }

    private func receiveApplicationContext(_ payload: SyncTransportPayload) {
        inboundApplicationContext = payload
        hasUndeliveredApplicationContext = true
        flushInbound()
    }

    private func receiveUserInfo(_ payload: SyncTransportPayload) {
        inboundUserInfo.append(payload)
        if activated && isReachable {
            flushInbound()
        }
    }

    private func receive(_ payload: SyncTransportPayload) {
        guard activated else { return }
        deliver(payload)
    }

    private func flushInbound() {
        guard activated, isReachable else { return }
        if hasUndeliveredApplicationContext, let inboundApplicationContext {
            hasUndeliveredApplicationContext = false
            deliver(inboundApplicationContext)
        }
        while !inboundUserInfo.isEmpty {
            deliver(inboundUserInfo.removeFirst())
        }
    }

    private func deliver(_ payload: SyncTransportPayload) {
        let envelope = SyncInboundEnvelope(payload: payload)
        receivedEnvelopes.append(envelope)
        delegate?.syncTransport(self, didReceive: envelope)
    }
}
