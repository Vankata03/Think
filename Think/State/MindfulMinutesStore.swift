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
    func saveMindfulSession(startDate: Date, endDate: Date) async throws
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

    func saveMindfulSession(startDate: Date, endDate: Date) async throws {
        guard let mindfulSessionType else { return }
        let sample = HKCategorySample(
            type: mindfulSessionType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: startDate,
            end: endDate
        )
        try await healthStore.save(sample)
    }

    private var mindfulSessionType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .mindfulSession)
    }
}

@MainActor
@Observable
final class MindfulMinutesStore {
    static let enabledKey = "health.mindfulMinutes.enabled"

    private let defaults: UserDefaults
    private let client: any MindfulHealthClient

    private(set) var authorization: MindfulMinutesAuthorization
    private(set) var isEnabled: Bool

    init(
        defaults: UserDefaults = .standard,
        client: any MindfulHealthClient = HealthKitMindfulHealthClient()
    ) {
        self.defaults = defaults
        self.client = client
        authorization = client.authorization
        isEnabled = defaults.bool(forKey: Self.enabledKey) && client.authorization == .authorized
        if client.authorization == .denied || client.authorization == .unavailable {
            defaults.set(false, forKey: Self.enabledKey)
        }
    }

    func refreshAuthorization() {
        authorization = client.authorization
        if authorization != .authorized {
            isEnabled = false
            if authorization == .denied || authorization == .unavailable {
                defaults.set(false, forKey: Self.enabledKey)
            }
        } else {
            isEnabled = defaults.bool(forKey: Self.enabledKey)
        }
    }

    func setEnabled(_ enabled: Bool) async {
        guard enabled else {
            isEnabled = false
            defaults.set(false, forKey: Self.enabledKey)
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

    func logCompletedSession(endedAt endDate: Date, durationMinutes: Int) async {
        guard durationMinutes > 0 else { return }
        refreshAuthorization()
        guard isEnabled, authorization == .authorized else { return }

        let startDate = endDate.addingTimeInterval(-TimeInterval(durationMinutes * 60))
        do {
            try await client.saveMindfulSession(startDate: startDate, endDate: endDate)
        } catch {
            // Health logging is best effort and must never affect the timer.
        }
    }
}
