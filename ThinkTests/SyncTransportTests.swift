//
//  SyncTransportTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

@MainActor
struct SyncTransportTests {

    @Test func latestApplicationContextReplacesUnreachableState() throws {
        let (sender, receiver) = MockSyncTransport.paired()
        let recorder = TransportRecorder()
        receiver.setDelegate(recorder)
        receiver.activate()
        sender.setReachable(false)

        let first = SyncTransportPayload(timer: Data("first".utf8))
        let latest = SyncTransportPayload(timer: Data("latest".utf8))
        try sender.updateApplicationContext(first)
        try sender.updateApplicationContext(latest)
        #expect(recorder.envelopes.isEmpty)

        sender.setReachable(true)

        #expect(recorder.envelopes.count == 1)
        #expect(recorder.envelopes.first?.timer == Data("latest".utf8))
    }

    @Test func reachableMessagesDeliverImmediately() {
        let (sender, receiver) = MockSyncTransport.paired()
        let recorder = TransportRecorder()
        receiver.setDelegate(recorder)
        receiver.activate()

        sender.sendMessage(SyncTransportPayload(timer: Data("message".utf8)))

        #expect(recorder.envelopes.count == 1)
        #expect(recorder.envelopes[0].timer == Data("message".utf8))
    }

    @Test func userInfoIsDeliveredFIFOAfterReconnect() {
        let (sender, receiver) = MockSyncTransport.paired()
        let recorder = TransportRecorder()
        receiver.setDelegate(recorder)
        receiver.activate()
        sender.setReachable(false)

        sender.transferUserInfo(SyncTransportPayload(focusSessionEvent: Data("one".utf8)))
        sender.transferUserInfo(SyncTransportPayload(focusSessionEvent: Data("two".utf8)))
        #expect(recorder.envelopes.isEmpty)

        sender.setReachable(true)

        #expect(recorder.envelopes.map(\.focusSessionEvent) == [Data("one".utf8), Data("two".utf8)])
    }

    @Test func unavailableTransportDoesNoWork() throws {
        let (sender, receiver) = MockSyncTransport.paired()
        let recorder = TransportRecorder()
        receiver.setDelegate(recorder)
        receiver.activate()
        sender.setAvailable(false)

        sender.sendMessage(SyncTransportPayload(timer: Data("message".utf8)))
        try sender.updateApplicationContext(SyncTransportPayload(timer: Data("context".utf8)))
        sender.transferUserInfo(SyncTransportPayload(focusSessionEvent: Data("event".utf8)))

        #expect(sender.sentMessages.isEmpty)
        #expect(recorder.envelopes.isEmpty)
    }

    @Test func unknownKeysAreIgnoredAndFutureSchemaIsDropped() {
        let values: [String: Any] = [
            SyncContextKey.schemaVersion: SyncSchema.currentVersion,
            SyncContextKey.timer: Data("timer".utf8),
            "unknown": "ignored",
        ]
        let envelope = SyncInboundEnvelope(propertyList: values)
        #expect(envelope?.timer == Data("timer".utf8))
        #expect(SyncInboundEnvelope(propertyList: [SyncContextKey.schemaVersion: 99]) == nil)
    }
}

@MainActor
private final class TransportRecorder: SyncTransportDelegate {
    var envelopes: [SyncInboundEnvelope] = []

    func syncTransportDidActivate(_ transport: any SyncTransport) { }

    func syncTransport(_ transport: any SyncTransport, didReceive envelope: SyncInboundEnvelope) {
        envelopes.append(envelope)
    }
}
