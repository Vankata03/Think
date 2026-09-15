//
//  JournalLock.swift
//  Think
//

import Foundation
import LocalAuthentication
import Observation
import SwiftUI

/// What the device can offer for the journal lock, and therefore whether
/// the setting can be turned on at all.
enum JournalLockAvailability: Equatable, Sendable {
    case faceID
    case touchID
    case opticID
    /// Biometry is absent or locked out, but a passcode exists.
    case passcodeOnly
    /// No device passcode, so `.deviceOwnerAuthentication` has nothing to
    /// evaluate. The setting stays off and explains why.
    case passcodeNotSet
    case unavailable

    var canEnable: Bool {
        switch self {
        case .faceID, .touchID, .opticID, .passcodeOnly: true
        case .passcodeNotSet, .unavailable: false
        }
    }

    /// Subtitle for the Profile row. Names the mechanism the user will
    /// actually be shown, so the setting is not a mystery before it is on.
    var settingSubtitle: String {
        switch self {
        case .faceID:
            String(localized: "Face ID or your passcode opens the journal.")
        case .touchID:
            String(localized: "Touch ID or your passcode opens the journal.")
        case .opticID:
            String(localized: "Optic ID or your passcode opens the journal.")
        case .passcodeOnly:
            String(localized: "Your device passcode opens the journal.")
        case .passcodeNotSet:
            String(localized: "Set a device passcode to use the journal lock.")
        case .unavailable:
            String(localized: "The journal lock is unavailable on this device.")
        }
    }
}

/// Isolates `LAContext` so the gate logic can be tested without a device
/// owner.
@MainActor
protocol JournalAuthenticator: AnyObject {
    var availability: JournalLockAvailability { get }

    func authenticate(reason: String) async -> Bool
}

@MainActor
final class DeviceOwnerJournalAuthenticator: JournalAuthenticator {
    var availability: JournalLockAvailability {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if let error, error.code == LAError.passcodeNotSet.rawValue {
                return .passcodeNotSet
            }
            return .unavailable
        }

        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        case .none: return .passcodeOnly
        @unknown default: return .passcodeOnly
        }
    }

    /// `.deviceOwnerAuthentication` rather than `.deviceOwnerAuthenticationWithBiometrics`:
    /// a device without Face ID, or one whose biometry is locked out after
    /// failed attempts, still has the passcode fallback.
    ///
    /// A fresh `LAContext` per call is deliberate. A reused context can
    /// satisfy a later `evaluatePolicy` from an earlier success, which
    /// would defeat the export path's fresh-authentication requirement.
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }
}

/// Stands in wherever authentication must never be attempted — UI tests
/// and previews.
@MainActor
final class UnavailableJournalAuthenticator: JournalAuthenticator {
    let availability = JournalLockAvailability.unavailable

    func authenticate(reason: String) async -> Bool { false }
}

/// Gates *reading* the journal. Writing — the note composer, the retro
/// composer, the daily question — is never gated: a lock that stands
/// between someone and a thought they wanted to write down is a lock that
/// gets turned off.
@MainActor
@Observable
final class JournalLock {
    static let enabledKey = "journalLockEnabled"
    /// A share sheet or photo picker round trip backgrounds the app for a
    /// few seconds. Relocking on every such trip would make the lock
    /// hostile without making it safer.
    static let backgroundGrace: TimeInterval = 60

    private let defaults: UserDefaults
    private let authenticator: any JournalAuthenticator
    private var backgroundedAt: Date?
    private var generation = 0
    private var sceneIsActive = true
    private var inFlight: (id: UUID, generation: Int, purpose: Purpose, task: Task<Bool, Never>)?
    private enum Purpose { case unlock, export, disable }

    private(set) var isEnabled: Bool
    private(set) var isUnlocked = false
    private(set) var availability: JournalLockAvailability

    init(defaults: UserDefaults = .standard,
         authenticator: any JournalAuthenticator = DeviceOwnerJournalAuthenticator()) {
        self.defaults = defaults
        self.authenticator = authenticator
        self.availability = authenticator.availability
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)
    }

    var isLocked: Bool { isEnabled && !isUnlocked }
    var canAuthenticate: Bool { availability.canEnable }
    var isPrivacyCoverActive: Bool { isEnabled && !sceneIsActive }

    func refreshAvailability() {
        let next = authenticator.availability
        if next != availability { invalidateAttempt() }
        availability = next
        if isEnabled && !next.canEnable { isUnlocked = false }
    }

    /// Legacy synchronous callers may enable. Disabling always requires authentication.
    func setEnabled(_ enabled: Bool) {
        guard enabled else {
            Task { await disable() }
            return
        }
        refreshAvailability()
        guard availability.canEnable else { return }
        invalidateAttempt()
        isEnabled = true
        isUnlocked = false
        defaults.set(true, forKey: Self.enabledKey)
    }

    @discardableResult
    func requestEnabled(_ enabled: Bool) async -> Bool {
        if enabled { setEnabled(true); return isEnabled }
        return await disable()
    }

    @discardableResult
    func disable() async -> Bool {
        guard isEnabled else { return true }
        guard await attempt(.disable, reason: String(localized: "Unlock your journal.")) else { return false }
        invalidateAttempt()
        isEnabled = false
        isUnlocked = false
        backgroundedAt = nil
        defaults.set(false, forKey: Self.enabledKey)
        return true
    }

    @discardableResult
    func authenticate() async -> Bool {
        guard isEnabled else { return true }
        if isUnlocked { return true }
        guard await attempt(.unlock, reason: String(localized: "Unlock your journal.")) else { return false }
        isUnlocked = true
        return true
    }

    func authenticateForExport() async -> Bool {
        guard isEnabled else { return true }
        return await attempt(.export, reason: String(localized: "Unlock to export your journal."))
    }

    private func attempt(_ purpose: Purpose, reason: String) async -> Bool {
        refreshAvailability()
        guard availability.canEnable, sceneIsActive else { return false }
        if let pending = inFlight {
            if pending.purpose == purpose {
                let success = await pending.task.value
                return success && pending.generation == generation && isEnabled && authenticator.availability.canEnable
            }
            // A different operation needs its own fresh authentication, serialized behind this one.
            _ = await pending.task.value
            guard pending.generation == generation, isEnabled else { return false }
            if inFlight?.id == pending.id { inFlight = nil }
            return await attempt(purpose, reason: reason)
        }
        let epoch = generation
        let id = UUID()
        let task = Task { await authenticator.authenticate(reason: reason) }
        inFlight = (id, epoch, purpose, task)
        let success = await task.value
        if inFlight?.id == id { inFlight = nil }
        return success && epoch == generation && isEnabled && authenticator.availability.canEnable
    }

    private func invalidateAttempt() {
        generation += 1
        inFlight?.task.cancel()
        inFlight = nil
    }

    func lock() {
        invalidateAttempt()
        isUnlocked = false
        backgroundedAt = nil
    }

    func scenePhaseChanged(to phase: ScenePhase, now: Date = .now) {
        sceneIsActive = phase == .active
        switch phase {
        case .background:
            invalidateAttempt()
            if backgroundedAt == nil { backgroundedAt = now }
        case .active:
            refreshAvailability()
            guard let leftAt = backgroundedAt else { return }
            if now.timeIntervalSince(leftAt) >= Self.backgroundGrace { lock() }
            else { backgroundedAt = nil }
        default:
            break
        }
    }
}
