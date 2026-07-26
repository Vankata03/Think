//
//  JournalLockTests.swift
//  ThinkTests
//

import Foundation
import SwiftUI
import Testing
@testable import Think

@MainActor
struct JournalLockTests {

    @Test func successfulAuthenticationUnlocksTheSession() async {
        let authenticator = StubJournalAuthenticator(availability: .faceID, succeeds: true)
        let lock = makeLock(authenticator: authenticator, enabled: true)

        #expect(lock.isLocked)
        #expect(await lock.authenticate())
        #expect(lock.isUnlocked)
        #expect(!lock.isLocked)
        #expect(authenticator.attempts == 1)
    }

    @Test func failedAuthenticationLeavesTheGateUp() async {
        let authenticator = StubJournalAuthenticator(availability: .faceID, succeeds: false)
        let lock = makeLock(authenticator: authenticator, enabled: true)

        #expect(await lock.authenticate() == false)
        #expect(!lock.isUnlocked)
        #expect(lock.isLocked)
    }

    @Test func aDisabledLockNeverGatesAndNeverAuthenticates() async {
        let authenticator = StubJournalAuthenticator(availability: .faceID, succeeds: false)
        let lock = makeLock(authenticator: authenticator, enabled: false)

        #expect(!lock.isLocked)
        // Returns true even though the stub would refuse: with the lock
        // off there is nothing to authenticate against.
        #expect(await lock.authenticate())
        #expect(await lock.authenticateForExport())
        #expect(authenticator.attempts == 0)
    }

    @Test func aShortBackgroundTripKeepsTheUnlock() async {
        let lock = makeLock(
            authenticator: StubJournalAuthenticator(availability: .faceID, succeeds: true),
            enabled: true
        )
        await lock.authenticate()

        let left = Date(timeIntervalSince1970: 1_700_000_000)
        lock.scenePhaseChanged(to: .background, now: left)
        lock.scenePhaseChanged(to: .active, now: left.addingTimeInterval(30))

        #expect(lock.isUnlocked)
    }

    @Test func aLongBackgroundTripRelocks() async {
        let lock = makeLock(
            authenticator: StubJournalAuthenticator(availability: .faceID, succeeds: true),
            enabled: true
        )
        await lock.authenticate()

        let left = Date(timeIntervalSince1970: 1_700_000_000)
        lock.scenePhaseChanged(to: .background, now: left)
        lock.scenePhaseChanged(to: .active, now: left.addingTimeInterval(90))

        #expect(!lock.isUnlocked)
        #expect(lock.isLocked)
    }

    @Test func passingThroughInactiveDoesNotStartTheGracePeriod() async {
        let lock = makeLock(
            authenticator: StubJournalAuthenticator(availability: .faceID, succeeds: true),
            enabled: true
        )
        await lock.authenticate()

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        // A share sheet or control center pull; the app never backgrounds.
        lock.scenePhaseChanged(to: .inactive, now: now)
        lock.scenePhaseChanged(to: .active, now: now.addingTimeInterval(600))

        #expect(lock.isUnlocked)
    }

    @Test func exportAuthenticatesEvenInsideAnUnlockedSession() async {
        let authenticator = StubJournalAuthenticator(availability: .faceID, succeeds: true)
        let lock = makeLock(authenticator: authenticator, enabled: true)

        await lock.authenticate()
        #expect(await lock.authenticateForExport())
        #expect(await lock.authenticateForExport())

        // One session unlock plus one call per export.
        #expect(authenticator.attempts == 3)
    }

    @Test func aRefusedExportDoesNotRelockTheSession() async {
        let authenticator = StubJournalAuthenticator(availability: .faceID, succeeds: true)
        let lock = makeLock(authenticator: authenticator, enabled: true)
        await lock.authenticate()

        authenticator.succeeds = false
        #expect(await lock.authenticateForExport() == false)
        #expect(lock.isUnlocked)
    }

    @Test func theSettingCannotBeTurnedOnWithoutADevicePasscode() {
        let authenticator = StubJournalAuthenticator(availability: .passcodeNotSet, succeeds: true)
        let defaults = makeDefaults()
        let lock = JournalLock(defaults: defaults, authenticator: authenticator)

        lock.setEnabled(true)

        #expect(!lock.isEnabled)
        #expect(!lock.isLocked)
        #expect(!defaults.bool(forKey: JournalLock.enabledKey))
    }

    @Test func removingThePasscodeStopsGatingButKeepsThePreference() {
        let authenticator = StubJournalAuthenticator(availability: .faceID, succeeds: true)
        let defaults = makeDefaults()
        let lock = JournalLock(defaults: defaults, authenticator: authenticator)
        lock.setEnabled(true)

        authenticator.availability = .passcodeNotSet
        lock.refreshAvailability()

        // An unlockable-by-nobody journal would be a lockout, not privacy.
        #expect(!lock.isEnabled)
        #expect(!lock.isLocked)
        #expect(defaults.bool(forKey: JournalLock.enabledKey))

        // Setting a passcode again brings the lock back on its own.
        authenticator.availability = .faceID
        lock.refreshAvailability()
        #expect(lock.isEnabled)
        #expect(lock.isLocked)
    }

    @Test func thePreferenceSurvivesAStoreRebuild() {
        let defaults = makeDefaults()
        let first = JournalLock(
            defaults: defaults,
            authenticator: StubJournalAuthenticator(availability: .faceID, succeeds: true)
        )
        first.setEnabled(true)

        let second = JournalLock(
            defaults: defaults,
            authenticator: StubJournalAuthenticator(availability: .faceID, succeeds: true)
        )

        #expect(second.isEnabled)
        // A new launch is a new session: nothing carries the unlock over.
        #expect(second.isLocked)
    }

    @Test func turningTheLockOffClearsTheSessionState() async {
        let defaults = makeDefaults()
        let lock = JournalLock(
            defaults: defaults,
            authenticator: StubJournalAuthenticator(availability: .faceID, succeeds: true)
        )
        lock.setEnabled(true)
        await lock.authenticate()

        lock.setEnabled(false)

        #expect(!lock.isEnabled)
        #expect(!lock.isUnlocked)
        #expect(!defaults.bool(forKey: JournalLock.enabledKey))
    }

    @Test func everyAvailabilityExplainsItself() {
        let cases: [JournalLockAvailability] = [
            .faceID, .touchID, .opticID, .passcodeOnly, .passcodeNotSet, .unavailable,
        ]

        for availability in cases {
            #expect(!availability.settingSubtitle.isEmpty)
        }
        #expect(JournalLockAvailability.passcodeOnly.canEnable)
        #expect(!JournalLockAvailability.passcodeNotSet.canEnable)
        #expect(!JournalLockAvailability.unavailable.canEnable)
    }

    private func makeLock(
        authenticator: StubJournalAuthenticator,
        enabled: Bool
    ) -> JournalLock {
        let lock = JournalLock(defaults: makeDefaults(), authenticator: authenticator)
        lock.setEnabled(enabled)
        return lock
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "ThinkTests.JournalLock.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

@MainActor
private final class StubJournalAuthenticator: JournalAuthenticator {
    var availability: JournalLockAvailability
    var succeeds: Bool
    private(set) var attempts = 0
    private(set) var reasons: [String] = []

    init(availability: JournalLockAvailability, succeeds: Bool) {
        self.availability = availability
        self.succeeds = succeeds
    }

    func authenticate(reason: String) async -> Bool {
        attempts += 1
        reasons.append(reason)
        return succeeds
    }
}
