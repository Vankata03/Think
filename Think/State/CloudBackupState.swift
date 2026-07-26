//
//  CloudBackupState.swift
//  Think
//

import CloudKit
import Foundation
import Observation

/// Reports whether the journal is currently backing up to the user's
/// iCloud, for display only.
///
/// There is no in-app on/off switch: SwiftData decides mirroring when the
/// container is built, so a mid-run toggle would mean tearing the
/// container down under a live `@Query`. iCloud settings are the switch;
/// this type explains what those settings currently mean for Think.
@Observable
@MainActor
final class CloudBackupState {
    enum Status: Equatable {
        /// Backup is on and the account is usable.
        case active
        /// The store opened locally; CloudKit is not mirroring it.
        case unavailable
        /// No iCloud account is signed in on this device.
        case signedOut
        /// The account exists but iCloud is restricted (for example by
        /// parental controls or a device management profile).
        case restricted
        /// Not applicable — tests and previews never mirror.
        case disabled
        /// Not looked up yet.
        case unknown
    }

    private(set) var status: Status = .unknown

    private let storage: JournalDataStore.Storage
    private let accountStatusProvider: @Sendable () async throws -> CKAccountStatus

    init(
        storage: JournalDataStore.Storage,
        accountStatusProvider: (@Sendable () async throws -> CKAccountStatus)? = nil
    ) {
        self.storage = storage
        let identifier = JournalDataStore.cloudKitContainerIdentifier
        self.accountStatusProvider = accountStatusProvider ?? {
            try await CKContainer(identifier: identifier).accountStatus()
        }
    }

    func refresh() async {
        switch storage {
        case .inMemory:
            status = .disabled
            return
        case .localOnly:
            status = .unavailable
            return
        case .cloudKit:
            break
        }

        do {
            status = Self.status(for: try await accountStatusProvider())
        } catch {
            status = .unavailable
        }
    }

    static func status(for accountStatus: CKAccountStatus) -> Status {
        switch accountStatus {
        case .available: .active
        case .noAccount: .signedOut
        case .restricted: .restricted
        case .couldNotDetermine, .temporarilyUnavailable: .unavailable
        @unknown default: .unavailable
        }
    }
}

extension CloudBackupState.Status {
    var summary: String {
        switch self {
        case .active:
            String(localized: "On — your journal syncs with your iCloud")
        case .unavailable:
            String(localized: "Off — turn on iCloud Drive for Think in Settings")
        case .signedOut:
            String(localized: "Signed out of iCloud")
        case .restricted:
            String(localized: "iCloud is restricted on this device")
        case .disabled:
            String(localized: "Off")
        case .unknown:
            String(localized: "Checking…")
        }
    }

    var systemImage: String {
        switch self {
        case .active: "checkmark.icloud"
        case .unavailable, .restricted: "exclamationmark.icloud"
        case .signedOut: "icloud.slash"
        case .disabled, .unknown: "icloud"
        }
    }
}
