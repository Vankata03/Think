import Foundation
import Observation

/// One deletion boundary for the app and its external completion producers.
/// A failed store/draft removal is surfaced; retry remains safe after the
/// persisted Watch barrier has already stopped old work from reappearing.
@MainActor @Observable
final class AppDataResetCoordinator {
    private let journal: JournalRepository
    private let drafts: JournalDraftStore
    private let sync: SyncCoordinator
    private let mindfulMinutes: MindfulMinutesStore
    private let favorites: FavoritesStore
    private let lock: JournalLock
    private let defaults: UserDefaults
    private let preferences: PracticePreferencesStore?
    private(set) var generation = 0
    private(set) var isResetting = false

    init(journal: JournalRepository, drafts: JournalDraftStore, sync: SyncCoordinator,
         mindfulMinutes: MindfulMinutesStore, favorites: FavoritesStore,
         lock: JournalLock, preferences: PracticePreferencesStore? = nil, defaults: UserDefaults = .standard) {
        self.journal = journal; self.drafts = drafts; self.sync = sync
        self.mindfulMinutes = mindfulMinutes; self.favorites = favorites
        self.lock = lock; self.defaults = defaults
        self.preferences = preferences
    }

    func reset(at date: Date = .now) throws {
        guard !isResetting else { return }
        isResetting = true
        defer { isResetting = false }
        sync.prepareForDataReset(at: date)
        mindfulMinutes.resetForDataDeletion()
        defaults.set(false, forKey: DailyQuoteNotifier.enabledKey)
        defaults.set(false, forKey: RetroReminder.enabledKey)
        DailyQuoteNotifier.cancelSchedule()
        RetroReminder.cancelSchedule()
        try journal.deleteAllJournalData()
        try drafts.deleteAll()
        favorites.removeAll()
        preferences?.reset()
        defaults.removeObject(forKey: DailyQuoteNotifier.minutesKey)
        defaults.removeObject(forKey: RetroReminder.minutesKey)
        sync.finalizeDataReset()
        lock.lock()
        generation += 1
    }
}
