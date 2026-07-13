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

        store.enqueueCompletedSession(endedAt: endDate, durationMinutes: 25)
        await store.drainPendingSessions()

        #expect(client.savedSessions.count == 1)
        #expect(client.savedSessions.first?.identifier == FocusSessionEvent.id(for: endDate))
        #expect(client.savedSessions.first?.startDate == endDate.addingTimeInterval(-25 * 60))
        #expect(client.savedSessions.first?.endDate == endDate)
        #expect(store.pendingSessionCount == 0)
    }

    @Test func healthFailureNeverDisablesOrEscapesTheTimerSideEffect() async {
        let defaults = makeDefaults()
        defaults.set(true, forKey: MindfulMinutesStore.enabledKey)
        let client = MockMindfulHealthClient(authorization: .authorized)
        client.saveError = TestError.saveFailed
        let store = MindfulMinutesStore(defaults: defaults, client: client)

        store.enqueueCompletedSession(endedAt: .now, durationMinutes: 50)
        await store.drainPendingSessions()

        #expect(store.isEnabled)
        #expect(client.saveAttempts == 1)
        #expect(store.pendingSessionCount == 1)
    }

    @Test func failedWriteRetriesAfterStoreReconstruction() async {
        let defaults = makeDefaults()
        defaults.set(true, forKey: MindfulMinutesStore.enabledKey)
        let failingClient = MockMindfulHealthClient(authorization: .authorized)
        failingClient.saveError = TestError.saveFailed
        let firstStore = MindfulMinutesStore(defaults: defaults, client: failingClient)
        let endDate = Date(timeIntervalSince1970: 75_000)

        firstStore.enqueueCompletedSession(endedAt: endDate, durationMinutes: 25)
        await firstStore.drainPendingSessions()

        let retryClient = MockMindfulHealthClient(authorization: .authorized)
        let retryStore = MindfulMinutesStore(defaults: defaults, client: retryClient)
        #expect(retryStore.pendingSessionCount == 1)

        await retryStore.drainPendingSessions()

        #expect(retryClient.savedSessions == [
            .init(
                identifier: FocusSessionEvent.id(for: endDate),
                startDate: endDate.addingTimeInterval(-25 * 60),
                endDate: endDate
            )
        ])
        #expect(retryStore.pendingSessionCount == 0)
    }

    @Test func authorizationRevocationClearsPendingWrites() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: MindfulMinutesStore.enabledKey)
        let client = MockMindfulHealthClient(authorization: .authorized)
        let store = MindfulMinutesStore(defaults: defaults, client: client)

        store.enqueueCompletedSession(endedAt: .now, durationMinutes: 25)
        #expect(store.pendingSessionCount == 1)

        client.authorization = .denied
        store.refreshAuthorization()

        #expect(!store.isEnabled)
        #expect(store.pendingSessionCount == 0)
    }

    @Test func disablingDuringSuspendedSaveDoesNotCrashOrRestoreQueue() async {
        let defaults = makeDefaults()
        defaults.set(true, forKey: MindfulMinutesStore.enabledKey)
        let client = MockMindfulHealthClient(authorization: .authorized)
        client.shouldSuspendSave = true
        let store = MindfulMinutesStore(defaults: defaults, client: client)
        store.enqueueCompletedSession(endedAt: .now, durationMinutes: 25)

        let drain = Task { await store.drainPendingSessions() }
        for _ in 0..<10 {
            if client.isSaveSuspended { break }
            await Task.yield()
        }
        #expect(client.isSaveSuspended)

        await store.setEnabled(false)
        client.resumeSave()
        await drain.value

        #expect(!store.isEnabled)
        #expect(store.pendingSessionCount == 0)
    }

    @Test func unsupportedDurationIsNotQueued() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: MindfulMinutesStore.enabledKey)
        let client = MockMindfulHealthClient(authorization: .authorized)
        let store = MindfulMinutesStore(defaults: defaults, client: client)

        store.enqueueCompletedSession(endedAt: .now, durationMinutes: Int.max)

        #expect(store.pendingSessionCount == 0)
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
        let identifier: String
        let startDate: Date
        let endDate: Date
    }

    var authorization: MindfulMinutesAuthorization
    var authorizationAfterRequest: MindfulMinutesAuthorization?
    var authorizationRequests = 0
    var saveAttempts = 0
    var savedSessions: [Session] = []
    var saveError: Error?
    var shouldSuspendSave = false
    private var saveContinuation: CheckedContinuation<Void, Never>?
    var isSaveSuspended: Bool { saveContinuation != nil }

    init(authorization: MindfulMinutesAuthorization) {
        self.authorization = authorization
    }

    func requestAuthorization() async throws {
        authorizationRequests += 1
        if let authorizationAfterRequest {
            authorization = authorizationAfterRequest
        }
    }

    func saveMindfulSession(identifier: String, startDate: Date, endDate: Date) async throws {
        saveAttempts += 1
        if shouldSuspendSave {
            await withCheckedContinuation { continuation in
                saveContinuation = continuation
            }
        }
        if let saveError {
            throw saveError
        }
        savedSessions.append(Session(identifier: identifier, startDate: startDate, endDate: endDate))
    }

    func resumeSave() {
        shouldSuspendSave = false
        saveContinuation?.resume()
        saveContinuation = nil
    }
}

private enum TestError: Error {
    case saveFailed
}
