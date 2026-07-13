//
//  MindfulMinutesStore.swift
//  Think
//

import Foundation
import HealthKit
import Observation

enum MindfulMinutesAuthorization: Equatable, Sendable {
    case unavailable
    case notDetermined
    case denied
    case authorized
}

@MainActor
protocol MindfulHealthClient: AnyObject {
    var authorization: MindfulMinutesAuthorization { get }

    func requestAuthorization() async throws
    func saveMindfulSession(identifier: String, startDate: Date, endDate: Date) async throws
}

@MainActor
final class HealthKitMindfulHealthClient: MindfulHealthClient {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    var authorization: MindfulMinutesAuthorization {
        guard HKHealthStore.isHealthDataAvailable(), let mindfulSessionType else {
            return .unavailable
        }

        switch healthStore.authorizationStatus(for: mindfulSessionType) {
        case .notDetermined:
            return .notDetermined
        case .sharingDenied:
            return .denied
        case .sharingAuthorized:
            return .authorized
        @unknown default:
            return .denied
        }
    }

    func requestAuthorization() async throws {
        guard let mindfulSessionType else { return }
        try await healthStore.requestAuthorization(toShare: [mindfulSessionType], read: [])
    }

    func saveMindfulSession(identifier: String, startDate: Date, endDate: Date) async throws {
        guard let mindfulSessionType else { return }
        let sample = HKCategorySample(
            type: mindfulSessionType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: startDate,
            end: endDate,
            metadata: [
                HKMetadataKeySyncIdentifier: "com.ivanterziev.Think.focus.\(identifier)",
                HKMetadataKeySyncVersion: 1
            ]
        )
        try await healthStore.save(sample)
    }

    private var mindfulSessionType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .mindfulSession)
    }
}

@MainActor
final class UnavailableMindfulHealthClient: MindfulHealthClient {
    let authorization = MindfulMinutesAuthorization.unavailable

    func requestAuthorization() async throws { }
    func saveMindfulSession(identifier: String, startDate: Date, endDate: Date) async throws { }
}

@MainActor
@Observable
final class MindfulMinutesStore {
    static let enabledKey = "health.mindfulMinutes.enabled"
    static let pendingSessionsKey = "health.mindfulMinutes.pendingSessions"
    static let supportedDurationMinutes = 5...120

    private struct PendingSession: Codable, Equatable {
        let id: String
        let endDate: Date
        let durationMinutes: Int
    }

    private let defaults: UserDefaults
    private let client: any MindfulHealthClient
    private var pendingSessions: [PendingSession]
    private var isDraining = false

    private(set) var authorization: MindfulMinutesAuthorization
    private(set) var isEnabled: Bool
    var pendingSessionCount: Int { pendingSessions.count }

    init(
        defaults: UserDefaults = .standard,
        client: any MindfulHealthClient = HealthKitMindfulHealthClient()
    ) {
        self.defaults = defaults
        self.client = client
        let decodedPendingSessions = defaults.data(forKey: Self.pendingSessionsKey)
            .flatMap { try? JSONDecoder().decode([PendingSession].self, from: $0) } ?? []
        pendingSessions = decodedPendingSessions.filter {
            !$0.id.isEmpty && Self.supportedDurationMinutes.contains($0.durationMinutes)
        }
        authorization = client.authorization
        isEnabled = defaults.bool(forKey: Self.enabledKey) && client.authorization == .authorized
        if client.authorization == .denied || client.authorization == .unavailable {
            defaults.set(false, forKey: Self.enabledKey)
        }
        if pendingSessions.count != decodedPendingSessions.count {
            persistPendingSessions()
        }
    }

    func refreshAuthorization() {
        authorization = client.authorization
        if authorization != .authorized {
            isEnabled = false
            if authorization == .denied || authorization == .unavailable {
                defaults.set(false, forKey: Self.enabledKey)
                pendingSessions.removeAll()
                persistPendingSessions()
            }
        } else {
            isEnabled = defaults.bool(forKey: Self.enabledKey)
        }
    }

    func setEnabled(_ enabled: Bool) async {
        guard enabled else {
            isEnabled = false
            defaults.set(false, forKey: Self.enabledKey)
            pendingSessions.removeAll()
            persistPendingSessions()
            return
        }

        refreshAuthorization()
        guard authorization != .unavailable else { return }

        if authorization == .notDetermined {
            do {
                try await client.requestAuthorization()
            } catch {
                isEnabled = false
                defaults.set(false, forKey: Self.enabledKey)
                refreshAuthorization()
                return
            }
        }

        refreshAuthorization()
        isEnabled = authorization == .authorized
        defaults.set(isEnabled, forKey: Self.enabledKey)
    }

    func enqueueCompletedSession(endedAt endDate: Date, durationMinutes: Int) {
        guard Self.supportedDurationMinutes.contains(durationMinutes) else { return }
        refreshAuthorization()
        guard isEnabled, authorization == .authorized else { return }

        let id = FocusSessionEvent.id(for: endDate)
        guard !pendingSessions.contains(where: { $0.id == id }) else { return }
        pendingSessions.append(
            PendingSession(id: id, endDate: endDate, durationMinutes: durationMinutes)
        )
        persistPendingSessions()
    }

    func drainPendingSessions() async {
        guard !isDraining else { return }
        refreshAuthorization()
        guard isEnabled, authorization == .authorized else { return }

        isDraining = true
        defer { isDraining = false }

        while let session = pendingSessions.first {
            let startDate = session.endDate.addingTimeInterval(-TimeInterval(session.durationMinutes) * 60)
            do {
                try await client.saveMindfulSession(
                    identifier: session.id,
                    startDate: startDate,
                    endDate: session.endDate
                )
                if let index = pendingSessions.firstIndex(where: { $0.id == session.id }) {
                    pendingSessions.remove(at: index)
                    persistPendingSessions()
                }
            } catch {
                // Preserve the pending sample for a later foreground retry.
                return
            }
        }
    }

    private func persistPendingSessions() {
        if pendingSessions.isEmpty {
            defaults.removeObject(forKey: Self.pendingSessionsKey)
        } else if let data = try? JSONEncoder().encode(pendingSessions) {
            defaults.set(data, forKey: Self.pendingSessionsKey)
        }
    }
}
