//
//  SharedDefaults.swift
//  Think
//

import Foundation

nonisolated enum SharedDefaults {
    static let appGroupSuiteName = "group.com.ivanterziev.Think"

    static func appGroup() -> UserDefaults {
        make(suiteName: appGroupSuiteName, fallback: .standard)
    }

    static func make(suiteName: String, fallback: UserDefaults = .standard) -> UserDefaults {
        guard !suiteName.isEmpty, let defaults = UserDefaults(suiteName: suiteName) else {
            return fallback
        }
        return defaults
    }
}
