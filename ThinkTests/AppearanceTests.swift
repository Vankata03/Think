//
//  AppearanceTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

@MainActor
struct AppearanceTests {
    @Test func freshInstallStartsInDark() {
        let defaults = makeDefaults()

        Appearance.seedDefault(in: defaults)

        #expect(defaults.string(forKey: Appearance.storageKey) == Appearance.dark.rawValue)
    }

    @Test func savedChoiceWins() {
        let defaults = makeDefaults()
        defaults.set(Appearance.light.rawValue, forKey: Appearance.storageKey)
        defaults.set(true, forKey: Onboarding.completedKey)

        Appearance.seedDefault(in: defaults)

        #expect(defaults.string(forKey: Appearance.storageKey) == Appearance.light.rawValue)
    }

    @Test func existingInstallWithoutAChoiceKeepsAuto() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: Onboarding.completedKey)

        Appearance.seedDefault(in: defaults)

        #expect(defaults.string(forKey: Appearance.storageKey) == Appearance.system.rawValue)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "ThinkTests.Appearance.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
