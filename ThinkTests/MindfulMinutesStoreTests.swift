//
//  MindfulMinutesStoreTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

@MainActor
struct MindfulMinutesStoreTests {

    @Test func enablingRequestsAuthorizationAndPersistsOnlyAfterApproval() async {
        let defaults = makeDefaults()
        let client = MockMindfulHealthClient(authorization: .notDetermined)
        client.authorizationAfterRequest = .authorized
        let store = MindfulMinutesStore(defaults: defaults, client: client)

        await store.setEnabled(true)

        #expect(client.authorizationRequests == 1)
        #expect(store.authorization == .authorized)
        #expect(store.isEnabled)
        #expect(defaults.bool(forKey: MindfulMinutesStore.enabledKey))
    }

    @Test func denialLeavesToggleOffAndDoesNotPersistOptIn() async {
        let defaults = makeDefaults()
        let client = MockMindfulHealthClient(authorization: .notDetermined)
        client.authorizationAfterRequest = .denied
        let store = MindfulMinutesStore(defaults: defaults, client: client)

        await store.setEnabled(true)

        #expect(store.authorization == .denied)
        #expect(!store.isEnabled)
        #expect(!defaults.bool(forKey: MindfulMinutesStore.enabledKey))
    }

    @Test func completedSessionWritesExactMindfulIntervalWhenEnabled() async {
        let defaults = makeDefaults()
        defaults.set(true, forKey: MindfulMinutesStore.enabledKey)
        let client = MockMindfulHealthClient(authorization: .authorized)
        let store = MindfulMinutesStore(defaults: defaults, client: client)
        let endDate = Date(timeIntervalSince1970: 50_000)

        await store.logCompletedSession(endedAt: endDate, durationMinutes: 25)

        #expect(client.savedSessions.count == 1)
        #expect(client.savedSessions.first?.startDate == endDate.addingTimeInterval(-25 * 60))
        #expect(client.savedSessions.first?.endDate == endDate)
    }

    @Test func healthFailureNeverDisablesOrEscapesTheTimerSideEffect() async {
        let defaults = makeDefaults()
        defaults.set(true, forKey: MindfulMinutesStore.enabledKey)
        let client = MockMindfulHealthClient(authorization: .authorized)
        client.saveError = TestError.saveFailed
        let store = MindfulMinutesStore(defaults: defaults, client: client)

        await store.logCompletedSession(endedAt: .now, durationMinutes: 50)

        #expect(store.isEnabled)
        #expect(client.saveAttempts == 1)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "ThinkTests.MindfulMinutes.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

@MainActor
private final class MockMindfulHealthClient: MindfulHealthClient {
    struct Session: Equatable {
        let startDate: Date
        let endDate: Date
    }

    var authorization: MindfulMinutesAuthorization
    var authorizationAfterRequest: MindfulMinutesAuthorization?
    var authorizationRequests = 0
    var saveAttempts = 0
    var savedSessions: [Session] = []
    var saveError: Error?

    init(authorization: MindfulMinutesAuthorization) {
        self.authorization = authorization
    }

    func requestAuthorization() async throws {
        authorizationRequests += 1
        if let authorizationAfterRequest {
            authorization = authorizationAfterRequest
        }
    }

    func saveMindfulSession(startDate: Date, endDate: Date) async throws {
        saveAttempts += 1
        if let saveError {
            throw saveError
        }
        savedSessions.append(Session(startDate: startDate, endDate: endDate))
    }
}

private enum TestError: Error {
    case saveFailed
}
