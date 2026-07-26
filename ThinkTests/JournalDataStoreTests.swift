//
//  JournalDataStoreTests.swift
//  ThinkTests
//

import CloudKit
import SwiftData
import Testing
@testable import Think

@MainActor
struct JournalDataStoreTests {

    @Test func testRunsNeverTouchCloudKit() {
        #expect(JournalDataStore.preferredStorage(isUITesting: true, isRunningTests: true) == .inMemory)
        #expect(JournalDataStore.preferredStorage(isUITesting: false, isRunningTests: true) == .localOnly)
        #expect(JournalDataStore.preferredStorage(isUITesting: false, isRunningTests: false) == .cloudKit)
        // The running process is a test host, so the live value must never
        // be the CloudKit one.
        #expect(JournalDataStore.isRunningTests)
    }

    @Test func inMemoryStorageDisablesMirroring() {
        #expect(JournalDataStore.mirroring(for: .inMemory) == .none)
        #expect(JournalDataStore.isStoredInMemoryOnly(.inMemory))
        #expect(JournalDataStore.configuration(for: .inMemory).isStoredInMemoryOnly)
    }

    @Test func localOnlyStorageDisablesMirroring() {
        #expect(JournalDataStore.mirroring(for: .localOnly) == .none)
        #expect(!JournalDataStore.isStoredInMemoryOnly(.localOnly))
        #expect(!JournalDataStore.configuration(for: .localOnly).isStoredInMemoryOnly)
    }

    @Test func cloudKitStorageUsesThePrivateDatabase() {
        #expect(
            JournalDataStore.mirroring(for: .cloudKit)
                == .privateDatabase(containerIdentifier: "iCloud.com.ivanterziev.Think")
        )
        #expect(!JournalDataStore.isStoredInMemoryOnly(.cloudKit))
    }

    @Test func cloudKitFallsBackToALocalStore() {
        #expect(JournalDataStore.storageFallbackChain(from: .cloudKit) == [.cloudKit, .localOnly])
        #expect(JournalDataStore.storageFallbackChain(from: .localOnly) == [.localOnly])
        #expect(JournalDataStore.storageFallbackChain(from: .inMemory) == [.inMemory])
    }

    @Test func uiTestContainerOpensInMemory() throws {
        let result = try JournalDataStore.makeContainer(isUITesting: true, isRunningTests: true)

        #expect(result.storage == .inMemory)

        let context = ModelContext(result.container)
        context.insert(JournalEntry(prompt: "", text: "Note.", kind: JournalEntry.kindNote))
        try context.save()

        #expect(try context.fetch(FetchDescriptor<JournalEntry>()).count == 1)
    }
}

@MainActor
struct CloudBackupStateTests {

    @Test func availableAccountReportsActiveBackup() async {
        let state = CloudBackupState(storage: .cloudKit) { .available }

        await state.refresh()

        #expect(state.status == .active)
    }

    @Test func missingAccountReportsSignedOut() async {
        let state = CloudBackupState(storage: .cloudKit) { .noAccount }

        await state.refresh()

        #expect(state.status == .signedOut)
    }

    @Test func accountLookupFailureReportsUnavailable() async {
        struct LookupFailure: Error {}
        let state = CloudBackupState(storage: .cloudKit) { throw LookupFailure() }

        await state.refresh()

        #expect(state.status == .unavailable)
    }

    @Test func localStoreReportsUnavailableWithoutAskingCloudKit() async {
        let state = CloudBackupState(storage: .localOnly) {
            Issue.record("Account status must not be queried for a local store.")
            return .available
        }

        await state.refresh()

        #expect(state.status == .unavailable)
    }

    @Test func inMemoryStoreReportsDisabled() async {
        let state = CloudBackupState(storage: .inMemory) {
            Issue.record("Account status must not be queried for an in-memory store.")
            return .available
        }

        await state.refresh()

        #expect(state.status == .disabled)
    }

    @Test func restrictedAndIndeterminateAccountsMapToStatuses() {
        #expect(CloudBackupState.status(for: .restricted) == .restricted)
        #expect(CloudBackupState.status(for: .couldNotDetermine) == .unavailable)
        #expect(CloudBackupState.status(for: .temporarilyUnavailable) == .unavailable)
    }
}
