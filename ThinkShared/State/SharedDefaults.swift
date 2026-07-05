//
//  SharedDefaults.swift
//  Think
//

import Foundation

nonisolated enum SharedDefaults {
    static let appGroupSuiteName = "group.com.ivanterziev.Think"
    static let migrationMarkerKey = "didMigrateProgressFromStandardDefaults"

    static func appGroup() -> UserDefaults {
        let defaults = make(suiteName: appGroupSuiteName, fallback: .standard)
        migrateProgressIfNeeded(from: .standard, to: defaults)
        return defaults
    }

    /// Progress originally lived in `UserDefaults.standard`; the app group
    /// suite starts empty, which read as a progress reset after updating.
    /// Copies each progress key once, never overwriting a value the
    /// destination already has.
    static func migrateProgressIfNeeded(from source: UserDefaults, to destination: UserDefaults) {
        guard source !== destination else { return }
        guard !destination.bool(forKey: migrationMarkerKey) else { return }
        for key in ProgressStore.persistedKeys where destination.object(forKey: key) == nil {
            if let value = source.object(forKey: key) {
                destination.set(value, forKey: key)
            }
        }
        destination.set(true, forKey: migrationMarkerKey)
    }

    static func make(suiteName: String, fallback: UserDefaults = .standard) -> UserDefaults {
        guard !suiteName.isEmpty, let defaults = UserDefaults(suiteName: suiteName) else {
            return fallback
        }
        return defaults
    }
}
