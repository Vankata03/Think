//
//  SharedDefaults.swift
//  Think
//

import Foundation

nonisolated enum SharedDefaults {
    static let appGroupSuiteName = "group.com.ivanterziev.Think"
    static let pomodoroTimerStateKey = "pomodoro.timer.state"
    static let pomodoroCustomWorkMinutesKey = "pomodoro.custom.workMinutes"
    static let pomodoroCustomRestMinutesKey = "pomodoro.custom.restMinutes"
    static let resetBoundaryKey = "sync.resetBoundary.v1"
    static let resetPendingKey = "sync.resetPending.v1"
    static let syncDeviceIDKey = "sync.deviceID"

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
        guard source !== destination, resetBoundary(in: destination) == nil else { return }
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

    static func resetBoundary(in defaults: UserDefaults) -> SyncResetBoundary? {
        guard let data = defaults.data(forKey: resetBoundaryKey) else { return nil }
        return try? SyncCodec.decode(SyncResetBoundary.self, from: data)
    }

    static func setResetBoundary(_ boundary: SyncResetBoundary, in defaults: UserDefaults) {
        guard let data = try? SyncCodec.encode(boundary) else { return }
        defaults.set(data, forKey: resetBoundaryKey)
        // Deletion barriers must reach disk before destructive state changes.
        defaults.synchronize()
    }

    static func syncDeviceID(in defaults: UserDefaults? = nil) -> UUID {
        let defaults = defaults ?? appGroup()
        if let stored = defaults.string(forKey: syncDeviceIDKey),
           let deviceID = UUID(uuidString: stored) {
            return deviceID
        }

        let deviceID = UUID()
        defaults.set(deviceID.uuidString, forKey: syncDeviceIDKey)
        return deviceID
    }
}
