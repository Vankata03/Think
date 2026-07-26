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

    private(set) var isEnabled: Bool
    private(set) var isUnlocked = false
    private(set) var availability: JournalLockAvailability

    init(
        defaults: UserDefaults = .standard,
        authenticator: any JournalAuthenticator = DeviceOwnerJournalAuthenticator()
    ) {
        self.defaults = defaults
        self.authenticator = authenticator
        let availability = authenticator.availability
        self.availability = availability
        isEnabled = defaults.bool(forKey: Self.enabledKey) && availability.canEnable
    }

    /// Whether the journal must render the gate instead of entries.
    var isLocked: Bool { isEnabled && !isUnlocked }

    /// Re-reads what the device can do. The passcode can be removed while
    /// the app is in the background.
    func refreshAvailability() {
        availability = authenticator.availability
        if isEnabled, !availability.canEnable {
            // Stop gating a journal that can no longer be unlocked, but
            // keep the stored preference: the lock returns by itself once
            // a passcode is set again.
            isEnabled = false
            isUnlocked = false
        } else if !isEnabled, availability.canEnable, defaults.bool(forKey: Self.enabledKey) {
            isEnabled = true
        }
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled else {
            isEnabled = false
            isUnlocked = false
            backgroundedAt = nil
            defaults.set(false, forKey: Self.enabledKey)
            return
        }

        refreshAvailability()
        guard availability.canEnable else { return }
        isEnabled = true
        // Left locked on purpose: the next visit to the journal shows the
        // user what they just switched on.
        isUnlocked = false
        defaults.set(true, forKey: Self.enabledKey)
    }

    /// Unlocks for the lifetime of the foreground session. Returns `true`
    /// when the journal may be read, which includes the case where the
    /// lock is off.
    @discardableResult
    func authenticate() async -> Bool {
        guard isEnabled else { return true }
        let succeeded = await authenticator.authenticate(
            reason: String(localized: "Unlock your journal.")
        )
        if succeeded {
            isUnlocked = true
            backgroundedAt = nil
        }
        return succeeded
    }

    /// Export writes every entry to a file that leaves the app, so it
    /// authenticates every time regardless of the session unlock.
    func authenticateForExport() async -> Bool {
        guard isEnabled else { return true }
        return await authenticator.authenticate(
            reason: String(localized: "Unlock to export your journal.")
        )
    }

    func lock() {
        isUnlocked = false
        backgroundedAt = nil
    }

    /// Relocks after a background trip longer than the grace period.
    /// `.inactive` is ignored: the app passes through it for a control
    /// center pull or an incoming call banner.
    func scenePhaseChanged(to phase: ScenePhase, now: Date = .now) {
        switch phase {
        case .background:
            guard backgroundedAt == nil else { return }
            backgroundedAt = now
        case .active:
            refreshAvailability()
            guard let leftAt = backgroundedAt else { return }
            if now.timeIntervalSince(leftAt) >= Self.backgroundGrace {
                lock()
            } else {
                backgroundedAt = nil
            }
        default:
            break
        }
    }
}
