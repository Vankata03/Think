import Foundation
import CloudKit
import Testing
@testable import Think

@MainActor struct CloudBackupEventTests {
    @Test func configuredIsNotACompletedExport() async {
        let state = CloudBackupState(storage: .cloudKit, accountStatusProvider: { .available })
        await state.refresh()
        #expect(state.status == .configured && state.lastSuccessfulExportDate == nil)
        let id = UUID(); let start = Date(timeIntervalSince1970: 10)
        state.recordMirroringEvent(.init(id: id, kind: .exportRecords, startedAt: start, succeeded: false))
        #expect(state.isSyncing)
        state.recordMirroringEvent(.init(id: id, kind: .exportRecords, startedAt: start, endedAt: start.addingTimeInterval(1), succeeded: true))
        #expect(!state.isSyncing)
        #expect(state.lastSuccessfulExportDate == start.addingTimeInterval(1))
        #expect(state.lastSuccessfulImportDate == nil)
        state.recordMirroringEvent(.init(id: UUID(), kind: .importRecords, startedAt: start, endedAt: start.addingTimeInterval(2), succeeded: false))
        #expect(state.status == .syncFailed)
        #expect(state.lastSuccessfulExportDate == start.addingTimeInterval(1))
    }
    @Test func overlappingEventsStayInProgressUntilBothFinish() {
        let state = CloudBackupState(storage: .cloudKit)
        let first = UUID(); let second = UUID()
        state.recordMirroringEvent(.init(id: first, kind: .importRecords, startedAt: .now, succeeded: false))
        state.recordMirroringEvent(.init(id: second, kind: .exportRecords, startedAt: .now, succeeded: false))
        state.recordMirroringEvent(.init(id: first, kind: .importRecords, startedAt: .now, endedAt: .now, succeeded: true))
        #expect(state.isSyncing)
        state.recordMirroringEvent(.init(id: second, kind: .exportRecords, startedAt: .now, endedAt: .now, succeeded: false))
        #expect(!state.isSyncing && state.lastFailureDate != nil)
    }
}
