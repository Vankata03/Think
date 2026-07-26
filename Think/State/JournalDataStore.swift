//
//  JournalDataStore.swift
//  Think
//

import Foundation
import SwiftData

/// Builds the SwiftData container that backs the journal.
///
/// Normal runs mirror the store into the user's own CloudKit private
/// database, so a lost or replaced phone no longer erases the journal.
/// Test runs never mirror: UI tests get a throwaway in-memory store, and
/// unit tests — which run inside the app — get a plain on-disk store.
/// When CloudKit is unavailable — no account, missing
/// entitlement, exhausted quota — the container degrades to a local
/// store rather than failing, because journaling has to keep working
/// even when sync cannot.
enum JournalDataStore {
    static let cloudKitContainerIdentifier = "iCloud.com.ivanterziev.Think"

    /// How the journal store is backed for a given run.
    enum Storage: Equatable {
        /// On-disk store mirrored into the user's CloudKit private database.
        case cloudKit
        /// On-disk store with no mirroring.
        case localOnly
        /// Throwaway store used by UI tests and previews.
        case inMemory
    }

    /// Which CloudKit database, if any, a storage kind mirrors into.
    /// `ModelConfiguration.CloudKitDatabase` is not `Equatable`, so the
    /// choice is modelled here where it can be asserted in tests.
    enum Mirroring: Equatable {
        case none
        case privateDatabase(containerIdentifier: String)
    }

    static var schema: Schema {
        Schema([JournalEntry.self, DailyRetro.self])
    }

    /// True when the process is hosting an XCTest bundle. Unit tests run
    /// inside the app, so without this check every test run would spin up
    /// CloudKit mirroring against a simulator that has no iCloud account,
    /// which floods the log and stalls the test host.
    static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil {
            return true
        }
        // Swift Testing runs do not always export those variables, but the
        // XCTest runtime is linked into every test host.
        return NSClassFromString("XCTestCase") != nil
    }

    static func preferredStorage(isUITesting: Bool, isRunningTests: Bool = isRunningTests) -> Storage {
        if isUITesting { return .inMemory }
        if isRunningTests { return .localOnly }
        return .cloudKit
    }

    static func mirroring(for storage: Storage) -> Mirroring {
        switch storage {
        case .cloudKit: .privateDatabase(containerIdentifier: cloudKitContainerIdentifier)
        case .localOnly, .inMemory: .none
        }
    }

    static func isStoredInMemoryOnly(_ storage: Storage) -> Bool {
        storage == .inMemory
    }

    static func configuration(for storage: Storage) -> ModelConfiguration {
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = switch mirroring(for: storage) {
        case .none: .none
        case .privateDatabase(let identifier): .private(identifier)
        }

        // On-disk stores keep resolving the App Group container, which is
        // where the journal has always lived. A throwaway store needs no
        // container at all, and asking for one makes it collide with the
        // real store inside a test host.
        let groupContainer: ModelConfiguration.GroupContainer = switch storage {
        case .cloudKit, .localOnly: .automatic
        case .inMemory: .none
        }

        return ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly(storage),
            groupContainer: groupContainer,
            cloudKitDatabase: cloudKitDatabase
        )
    }

    /// Storage kinds to attempt, in order, for a preferred kind. CloudKit
    /// falls back to the same on-disk store the app used before backup
    /// existed; in-memory has nothing to fall back to.
    static func storageFallbackChain(from preferred: Storage) -> [Storage] {
        switch preferred {
        case .cloudKit: [.cloudKit, .localOnly]
        case .localOnly: [.localOnly]
        case .inMemory: [.inMemory]
        }
    }

    struct Result {
        let container: ModelContainer
        let storage: Storage
    }

    /// Creates the container, walking the fallback chain until one opens.
    /// - Throws: only when every candidate fails, which means the journal
    ///   cannot be opened at all.
    static func makeContainer(
        isUITesting: Bool,
        isRunningTests: Bool = isRunningTests
    ) throws -> Result {
        let preferred = preferredStorage(isUITesting: isUITesting, isRunningTests: isRunningTests)
        let chain = storageFallbackChain(from: preferred)
        var lastError: (any Error)?

        for storage in chain {
            do {
                let container = try ModelContainer(
                    for: schema,
                    configurations: configuration(for: storage)
                )
                return Result(container: container, storage: storage)
            } catch {
                lastError = error
            }
        }

        throw lastError ?? CocoaError(.fileReadUnknown)
    }
}
