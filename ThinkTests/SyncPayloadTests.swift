//
//  SyncPayloadTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

struct SyncPayloadTests {

    @Test func revisionOrdersByDateThenDeviceID() throws {
        let firstDevice = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let secondDevice = try #require(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let date = try #require(SyncDateCoding.date(from: "2026-07-12T10:00:00.000Z"))

        #expect(Revision(date: date, deviceID: firstDevice) < Revision(date: date, deviceID: secondDevice))
        #expect(Revision(date: date, deviceID: secondDevice) > Revision(date: date, deviceID: firstDevice))
        #expect(Revision(date: date, deviceID: firstDevice) == Revision(date: date, deviceID: firstDevice))
    }

    @Test func payloadsRoundTripThroughConfiguredCodec() throws {
        let timer = try SyncCodec.decode(TimerSyncState.self, from: fixture("timer-v1.json"))
        let event = try SyncCodec.decode(FocusSessionEvent.self, from: fixture("focus-event-v1.json"))
        let progress = try SyncCodec.decode(ProgressSnapshot.self, from: fixture("progress-v1.json"))

        #expect(try SyncCodec.decode(TimerSyncState.self, from: SyncCodec.encode(timer)) == timer)
        #expect(try SyncCodec.decode(FocusSessionEvent.self, from: SyncCodec.encode(event)) == event)
        #expect(try SyncCodec.decode(ProgressSnapshot.self, from: SyncCodec.encode(progress)) == progress)
    }

    @Test func codecProducesStableGoldenPayloads() throws {
        for name in ["timer-v1.json", "focus-event-v1.json", "progress-v1.json"] {
            let original = try JSONSerialization.jsonObject(with: fixture(name)) as! NSDictionary
            let value: Any
            switch name {
            case "timer-v1.json":
                value = try SyncCodec.decode(TimerSyncState.self, from: fixture(name))
            case "focus-event-v1.json":
                value = try SyncCodec.decode(FocusSessionEvent.self, from: fixture(name))
            default:
                value = try SyncCodec.decode(ProgressSnapshot.self, from: fixture(name))
            }
            let encoded = try encodeErased(value)
            let roundTripped = try JSONSerialization.jsonObject(with: encoded) as! NSDictionary
            #expect(roundTripped == original)
        }
    }

    @Test func identicalEndDatesProduceIdenticalEventIDs() throws {
        let firstDate = try #require(SyncDateCoding.date(from: "2026-07-12T10:25:30.1234Z"))
        let secondDate = try #require(SyncDateCoding.date(from: "2026-07-12T10:25:30.12349Z"))
        let first = FocusSessionEvent(endDate: firstDate)
        let second = FocusSessionEvent(endDate: secondDate)

        #expect(first.id == second.id)
        #expect(first.id == "2026-07-12T10:25:30.123Z")
    }

    @Test func malformedPayloadIsRejected() {
        let malformed = Data(#"{"workMinutes":"not-a-number"}"#.utf8)

        #expect(throws: (any Error).self) {
            try SyncCodec.decode(TimerSyncState.self, from: malformed)
        }
    }

    @Test func unknownKeysAreIgnored() throws {
        let data = Data(#"{"id":"event","completedAt":"2026-07-12T10:25:30.123Z","futureField":true}"#.utf8)
        let event = try SyncCodec.decode(FocusSessionEvent.self, from: data)

        #expect(event.id == "event")
        #expect(event.completedAt == SyncDateCoding.date(from: "2026-07-12T10:25:30.123Z"))
        #expect(event.durationMinutes == nil)
    }

    @Test func additiveDurationFieldRoundTripsWithoutBreakingV1Fixtures() throws {
        let completedAt = try #require(SyncDateCoding.date(from: "2026-07-12T10:25:30.123Z"))
        let event = FocusSessionEvent(endDate: completedAt, durationMinutes: 50)
        let decodedEvent = try SyncCodec.decode(
            FocusSessionEvent.self,
            from: SyncCodec.encode(event)
        )
        #expect(decodedEvent.durationMinutes == 50)

        let oldEvent = try SyncCodec.decode(FocusSessionEvent.self, from: fixture("focus-event-v1.json"))
        #expect(oldEvent.durationMinutes == nil)
    }

    private func fixture(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Sync")
            .appendingPathComponent(name)
        return try Data(contentsOf: url)
    }

    private func encodeErased(_ value: Any) throws -> Data {
        switch value {
        case let timer as TimerSyncState:
            return try SyncCodec.encode(timer)
        case let event as FocusSessionEvent:
            return try SyncCodec.encode(event)
        case let progress as ProgressSnapshot:
            return try SyncCodec.encode(progress)
        default:
            throw CocoaError(.coderInvalidValue)
        }
    }
}
