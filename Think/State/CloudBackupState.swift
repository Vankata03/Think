//
//  CloudBackupState.swift
//  Think
//

import CloudKit
import CoreData
import Foundation
import Observation

/// Reports what is known about the journal's iCloud backup, for display
/// only.
///
/// Two independent signals feed it. `CKAccountStatus` says whether the
/// account can be used at all; it never says that mirroring has actually
/// run, so an available account is reported as *configured*, not as a
/// completed backup. `NSPersistentCloudKitContainer.eventChangedNotification`
/// — which SwiftData posts, because it mirrors through that container —
/// carries the real outcome of each setup, import, and export, and a
/// failure there downgrades the reported status.
///
/// There is no in-app on/off switch: SwiftData decides mirroring when the
/// container is built, so a mid-run toggle would mean tearing the
/// container down under a live `@Query`. iCloud settings are the switch;
/// this type explains what those settings currently mean for Think.
@Observable
@MainActor
final class CloudBackupState {
    enum Status: Equatable {
        /// The account is usable and the store is configured to mirror.
        /// Says nothing about whether a given entry has reached iCloud.
        case configured
        /// Mirroring reported a failure.
        case syncFailed
        /// The store opened locally; CloudKit is not mirroring it.
        case unavailable
        /// No iCloud account is signed in on this device.
        case signedOut
        /// The account exists but iCloud is restricted (for example by
        /// parental controls or a device management profile).
        case restricted
        /// Nothing on disk: the journal opened into a throwaway store.
        case temporaryStore
        /// Not applicable — tests and previews never mirror.
        case disabled
        /// Not looked up yet.
        case unknown
    }

    private(set) var status: Status = .unknown

    private let storage: JournalDataStore.Storage
    private let accountStatusProvider: @Sendable () async throws -> CKAccountStatus
    private var mirroringFailed = false
    // `deinit` is nonisolated, so the token it has to release cannot be
    // MainActor state. Only `startObservingMirroringEvents` (MainActor)
    // and `deinit` (exclusive by definition) ever touch it.
    private nonisolated(unsafe) var eventObserver: (any NSObjectProtocol)?

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

    deinit {
        if let eventObserver {
            NotificationCenter.default.removeObserver(eventObserver)
        }
    }

    func refresh() async {
        switch storage {
        case .inMemory:
            status = .disabled
            return
        case .emergencyInMemory:
            status = .temporaryStore
            return
        case .localOnly:
            status = .unavailable
            return
        case .cloudKit:
            break
        }

        do {
            status = Self.status(
                for: try await accountStatusProvider(),
                mirroringFailed: mirroringFailed
            )
        } catch {
            status = .unavailable
        }
    }

    /// Starts watching the mirroring events SwiftData posts through
    /// `NSPersistentCloudKitContainer`, so an account that looks fine but
    /// cannot actually sync stops being reported as configured.
    func startObservingMirroringEvents(center: NotificationCenter = .default) {
        guard storage == .cloudKit, eventObserver == nil else { return }

        eventObserver = center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event
            guard let event, event.endDate != nil else { return }
            // Read the outcome here: the event itself must not cross into
            // the MainActor region.
            let succeeded = event.succeeded

            MainActor.assumeIsolated {
                self?.recordMirroringOutcome(succeeded: succeeded)
            }
        }
    }

    /// Applies the outcome of one finished mirroring event. A failure is
    /// sticky until a later event succeeds, so a transient success does
    /// not hide a backup that keeps failing right after it.
    func recordMirroringOutcome(succeeded: Bool) {
        mirroringFailed = !succeeded

        switch status {
        case .configured, .syncFailed:
            status = succeeded ? .configured : .syncFailed
        case .unavailable, .signedOut, .restricted, .temporaryStore, .disabled, .unknown:
            // Account-level problems outrank event outcomes; the next
            // refresh re-reads the account and picks this up.
            break
        }
    }

    static func status(
        for accountStatus: CKAccountStatus,
        mirroringFailed: Bool = false
    ) -> Status {
        switch accountStatus {
        case .available: mirroringFailed ? .syncFailed : .configured
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
        case .configured:
            String(localized: "On — new entries copy to your iCloud")
        case .syncFailed:
            String(localized: "iCloud reported an error during the last backup")
        case .unavailable:
            String(localized: "Off — turn on iCloud Drive for Think in Settings")
        case .signedOut:
            String(localized: "Signed out of iCloud")
        case .restricted:
            String(localized: "iCloud is restricted on this device")
        case .temporaryStore:
            String(localized: "Off — this session is not being saved. Restart Think.")
        case .disabled:
            String(localized: "Off")
        case .unknown:
            String(localized: "Checking…")
        }
    }

    /// Whether entries written now are headed for the user's iCloud.
    var isCloudBacked: Bool {
        switch self {
        case .configured, .syncFailed: true
        case .unavailable, .signedOut, .restricted, .temporaryStore, .disabled, .unknown: false
        }
    }

    var systemImage: String {
        switch self {
        case .configured: "checkmark.icloud"
        case .syncFailed, .unavailable, .restricted, .temporaryStore: "exclamationmark.icloud"
        case .signedOut: "icloud.slash"
        case .disabled, .unknown: "icloud"
        }
    }
}
