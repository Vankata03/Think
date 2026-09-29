//
//  Appearance.swift
//  Think
//

import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appearance"
    /// Dark is the shipped default (design-system section 1).
    static let defaultChoice = Appearance.dark

    /// Stores the starting appearance once. A new installation starts in
    /// Dark; an installation that finished onboarding before Dark became
    /// the default keeps Auto, which is what it has been showing. A saved
    /// choice is never touched.
    static func seedDefault(in defaults: UserDefaults) {
        guard defaults.object(forKey: storageKey) == nil else { return }
        let existingInstall = defaults.bool(forKey: Onboarding.completedKey)
        defaults.set((existingInstall ? Appearance.system : defaultChoice).rawValue, forKey: storageKey)
    }

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: String(localized: "Auto")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
