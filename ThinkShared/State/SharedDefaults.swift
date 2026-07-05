//
//  SharedDefaults.swift
//  Think
//

import Foundation

nonisolated enum SharedDefaults {
    static let appGroupSuiteName = "group.com.ivanterziev.Think"

    static func appGroup() -> UserDefaults {
        let defaults = make(suiteName: appGroupSuiteName, fallback: .standard)
        migrateProgressIfNeeded(from: .standard, to: defaults)
        return defaults
    }

    /// Progress originally lived in `UserDefaults.standard`; the app group
    /// suite starts empty, which read as a progress reset after updating.
    /// Copies each progress key the destination doesn't have yet, never
    /// overwriting existing values. Per-key checks (rather than a one-shot
    /// marker) let keys added in future releases migrate too.
    static func migrateProgressIfNeeded(from source: UserDefaults, to destination: UserDefaults) {
        guard source !== destination else { return }
        for key in ProgressStore.persistedKeys where destination.object(forKey: key) == nil {
            if let value = source.object(forKey: key) {
                destination.set(value, forKey: key)
            }
        }
    }

    static func make(suiteName: String, fallback: UserDefaults = .standard) -> UserDefaults {
        guard !suiteName.isEmpty, let defaults = UserDefaults(suiteName: suiteName) else {
            return fallback
        }
        return defaults
    }
}
