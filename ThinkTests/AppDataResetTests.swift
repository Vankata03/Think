import Foundation
import SwiftData
import Testing
@testable import Think

@MainActor struct AppDataResetTests {
    private final class UnavailableHealth: MindfulHealthClient {
        var authorization: MindfulMinutesAuthorization { .unavailable }
        func requestAuthorization() async throws {}
        func saveMindfulSession(identifier: String, startDate: Date, endDate: Date) async throws {}
    }

    @Test func failedJournalDeletionCanRetryWithoutResumingTimerOrLeavingDrafts() throws {
        let suite = "AppDataResetTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let container = try ModelContainer(for: JournalDataStore.schema,
                                          configurations: JournalDataStore.configuration(for: .inMemory))
        enum InjectedFailure: Error { case save }
        var fail = false
        let journal = JournalRepository(modelContext: container.mainContext, commitInterceptor: {
            if fail { throw InjectedFailure.save }
        })
        _ = try journal.saveNote(text: "Saved before reset")
        let drafts = JournalDraftStore(directory: directory)
        var draft = JournalDraft(kind: .note)
        draft.text = "Unfinished before reset"
        try drafts.save(draft)
        let timer = PomodoroTimer(systemSideEffectsEnabled: false, defaults: defaults)
        let progress = ProgressStore(defaults: defaults)
        let sync = SyncCoordinator(role: .phone, timer: timer, progress: progress,
                                   ledger: FocusEventLedger(defaults: defaults), transport: NoopSyncTransport())
        sync.activate()
        let preferences = PracticePreferencesStore(defaults: defaults)
        preferences.setFeedback(.tried, for: "practice.001")
        let reset = AppDataResetCoordinator(journal: journal, drafts: drafts, sync: sync,
            mindfulMinutes: MindfulMinutesStore(defaults: defaults, client: UnavailableHealth()),
            favorites: FavoritesStore(defaults: defaults), lock: JournalLock(defaults: defaults),
            preferences: preferences, defaults: defaults)
        timer.start()
        fail = true
        #expect(throws: InjectedFailure.self) { try reset.reset() }
        #expect(!timer.isRunning)
        #expect(reset.generation == 0 && !reset.isResetting)
        #expect(try journal.entries().totalCount == 1)
        #expect(try drafts.draft(id: draft.id) != nil)
        fail = false
        try reset.reset()
        #expect(reset.generation == 1)
        #expect(try journal.entries().totalCount == 0)
        #expect(try drafts.draft(id: draft.id) == nil)
        #expect(PracticePreferencesStore(defaults: defaults).feedback.isEmpty)
        #expect(!PomodoroTimer(systemSideEffectsEnabled: false, defaults: defaults).isRunning)
    }
}
