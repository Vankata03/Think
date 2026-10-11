import Foundation
import Observation
import SwiftData

/// Every mutation uses its own autosave-disabled context. Failed work never leaks
/// into the UI context or a later autosave. UI awards progress only after receipt.
@MainActor @Observable
final class JournalRepository {
    enum RepositoryError: Error { case notFound, emptyContent, invalidIdentity }
    enum StorageWarning { case temporaryStore }
    enum MoodFilter: Equatable { case all, untagged, tagged(Mood) }
    struct Page { var offset = 0; var limit = 50 }
    struct JournalPage<Record> { let records: [Record]; let totalCount: Int; var hasMore: Bool; let nextOffset: Int }
    /// Kind, mood, theme and date run as a SwiftData predicate; search
    /// runs over the fetched rows (see `entries(matching:page:)`).
    struct EntryQuery {
        var search = ""
        var kind: String?
        var mood: MoodFilter = .all
        /// Matches the primary or the secondary theme.
        var theme: Theme?
        var dateRange: DateInterval?
        /// Records left out, such as the versions the unfiltered list hides.
        var excluding: Set<UUID> = []
    }
    struct RetroQuery {
        var search = ""; var mood: MoodFilter = .all; var theme: Theme?; var dateRange: DateInterval?
        var excluding: Set<UUID> = []
    }
    struct EntrySnapshot: Identifiable {
        let recordID: UUID?
        var id: PersistentIdentifier { persistentModelID }
        let persistentModelID: PersistentIdentifier
        let date: Date
        let prompt: String
        let text: String
        let kind: String
        let mood: String?
        let theme: String?
        let secondaryTheme: String?
        let civilDay: String?
        let timeZoneIdentifier: String?
        let practiceID: String?
        let sessionID: String?
        let updatedAt: Date?
        let periodKey: String?
        let nextIntention: String?
        init(_ value: JournalEntry) {
            recordID = value.recordID; persistentModelID = value.persistentModelID
            date = value.date; prompt = value.prompt; text = value.text; kind = value.kind; mood = value.mood
            theme = value.theme; secondaryTheme = value.secondaryTheme
            civilDay = value.civilDay; timeZoneIdentifier = value.timeZoneIdentifier
            practiceID = value.practiceID; sessionID = value.sessionID; updatedAt = value.updatedAt
            periodKey = value.periodKey; nextIntention = value.nextIntention
        }
        var themes: ThemeSelection { ThemeSelection(stored: theme, secondary: secondaryTheme) }
        /// When the record was last written: what picks the day's record.
        var latestEdit: Date { updatedAt ?? date }
    }
    struct RetroSnapshot: Identifiable {
        let recordID: UUID?
        var id: PersistentIdentifier { persistentModelID }
        let persistentModelID: PersistentIdentifier
        let date: Date
        let wentWell: String
        let improve: String
        let tomorrow: String
        let mood: String?
        let theme: String?
        let secondaryTheme: String?
        let civilDay: String?
        let timeZoneIdentifier: String?
        let practiceID: String?
        let promptSnapshot: String?
        let tomorrowIntention: String?
        let updatedAt: Date?
        init(_ value: DailyRetro) {
            recordID = value.recordID; persistentModelID = value.persistentModelID
            date = value.date; wentWell = value.wentWell; improve = value.improve; tomorrow = value.tomorrow
            mood = value.mood; theme = value.theme; secondaryTheme = value.secondaryTheme
            civilDay = value.civilDay; timeZoneIdentifier = value.timeZoneIdentifier
            practiceID = value.practiceID; promptSnapshot = value.promptSnapshot
            tomorrowIntention = value.tomorrowIntention; updatedAt = value.updatedAt
        }
        var themes: ThemeSelection { ThemeSelection(stored: theme, secondary: secondaryTheme) }
        /// When the record was last written: what picks the day's record.
        var latestEdit: Date { updatedAt ?? date }
    }
    struct SessionSnapshot {
        let sessionID: String
        let intention: String?
        let outcome: String?
        let energy: String?
        let closingNoteRecordID: UUID?
        let completedAt: Date?
        let civilDay: String?
        let timeZoneIdentifier: String?
        init(_ value: FocusSessionMetadata) {
            sessionID = value.sessionID; intention = value.intention; outcome = value.outcome; energy = value.energy
            closingNoteRecordID = value.closingNoteRecordID; completedAt = value.completedAt
            civilDay = value.civilDay; timeZoneIdentifier = value.timeZoneIdentifier
        }
    }
    struct SaveReceipt { let recordID: UUID; let persistentID: PersistentIdentifier; let civilDay: CivilDay }
    struct ActivitySummary {
        var answers = 0; var notes = 0; var focusNotes = 0; var retros = 0
        var taggedMoodCounts: [String: Int] = [:]
        var untaggedCount = 0
    }

    let storage: JournalDataStore.Storage
    private let container: ModelContainer
    private let diagnostics: LocalDiagnostics
    private let commitInterceptor: (() throws -> Void)?
    private(set) var revision = 0
    var storageWarning: StorageWarning? { storage == .emergencyInMemory ? .temporaryStore : nil }

    init(modelContext: ModelContext, storage: JournalDataStore.Storage = .localOnly,
         draftStore: JournalDraftStore? = nil, diagnostics: LocalDiagnostics? = nil,
         commitInterceptor: (() throws -> Void)? = nil) {
        self.container = modelContext.container
        self.storage = storage
        self.diagnostics = diagnostics ?? LocalDiagnostics()
        self.commitInterceptor = commitInterceptor
    }

    private func context() -> ModelContext {
        let result = ModelContext(container); result.autosaveEnabled = false; return result
    }
    private func commit<T>(_ operation: (ModelContext) throws -> T) throws -> T {
        try commit(operation, result: { $0 })
    }
    private func commit<T, R>(_ operation: (ModelContext) throws -> T, result: (T) -> R) throws -> R {
        let writer = context()
        let start = Date()
        do {
            let value = try operation(writer)
            try commitInterceptor?()
            try writer.save()
            revision += 1
            diagnostics.record(.save, duration: Date().timeIntervalSince(start))
            return result(value)
        } catch {
            writer.rollback()
            diagnostics.record(.save, category: LocalDiagnostics.category(for: error), duration: Date().timeIntervalSince(start))
            throw error
        }
    }

    // `themes: nil` on any save or update leaves the stored themes as they
    // are (a new record starts with none), so a caller without the Theme
    // chip never clears them; an empty selection clears them. Unlike
    // `mood: nil`, which clears the mood.
    @discardableResult
    func saveAnswer(text: String, practiceID: String? = nil, prompt: String, mood: Mood? = nil, themes: ThemeSelection? = nil,
                    day: CivilDay = .today(), date: Date = .now, recordID: UUID = UUID()) throws -> SaveReceipt {
        try saveEntry(text: text, prompt: prompt, kind: JournalEntry.kindQuestion, mood: mood, themes: themes,
                      day: day, date: date, recordID: recordID, practiceID: practiceID)
    }
    @discardableResult
    func saveNote(text: String, mood: Mood? = nil, themes: ThemeSelection? = nil, day: CivilDay? = nil, date: Date = .now,
                  recordID: UUID = UUID()) throws -> SaveReceipt {
        try saveEntry(text: text, prompt: "", kind: JournalEntry.kindNote, mood: mood, themes: themes,
                      day: day ?? CivilDay(date: date), date: date, recordID: recordID)
    }
    @discardableResult
    func savePracticeNote(text: String, practiceID: String, prompt: String, mood: Mood? = nil, themes: ThemeSelection? = nil,
                          day: CivilDay = .today(), recordID: UUID = UUID()) throws -> SaveReceipt {
        try saveEntry(text: text, prompt: prompt, kind: JournalEntry.kindNote, mood: mood, themes: themes,
                      day: day, date: day.contains(.now) ? .now : day.start, recordID: recordID, practiceID: practiceID)
    }
    /// `timeZone` is the zone the week was captured in (the draft's civil
    /// day), so a review recovered after a zone change still lands in the
    /// ISO week the person was writing about.
    @discardableResult
    func saveWeeklyReview(text: String, nextIntention: String?, weekStart: Date, timeZone: TimeZone = .current,
                          recordID: UUID = UUID()) throws -> SaveReceipt {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !(nextIntention ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RepositoryError.emptyContent }
        return try commit({ writer -> JournalEntry in
            if let existing = try entry(id: recordID, in: writer) {
                // Same identity resaved: keep its week, refresh the writing.
                if existing.text != text || existing.nextIntention != nextIntention {
                    existing.text = text; existing.nextIntention = nextIntention; existing.updatedAt = .now
                }
                return existing
            }
            let day = CivilDay(date: weekStart, timeZone: timeZone)
            let value = JournalEntry(date: weekStart, prompt: String(localized: "Weekly review"), text: text, kind: JournalEntry.kindWeeklyReview)
            value.recordID = recordID; value.periodKey = JournalIdentity.weekKey(for: weekStart, timeZone: timeZone)
            value.civilDay = day.key; value.timeZoneIdentifier = day.timeZoneIdentifier
            value.nextIntention = nextIntention
            writer.insert(value); return value
        }, result: receipt)
    }
    @discardableResult
    func updateWeeklyReview(id: UUID, text: String, nextIntention: String?) throws -> SaveReceipt {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !(nextIntention ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RepositoryError.emptyContent }
        return try commit({ writer -> JournalEntry in
            guard let value = try entry(id: id, in: writer) else { throw RepositoryError.notFound }
            value.text = text; value.nextIntention = nextIntention; value.updatedAt = .now; return value
        }, result: receipt)
    }
    func weeklyReview(weekStart: Date, timeZone: TimeZone = .current) throws -> DailySelection<EntrySnapshot>? {
        try weeklyReview(periodKey: JournalIdentity.weekKey(for: weekStart, timeZone: timeZone))
    }
    private func weeklyReview(periodKey period: String) throws -> DailySelection<EntrySnapshot>? {
        let kind = JournalEntry.kindWeeklyReview
        let reader = context()
        let descriptor = FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.kind == kind && $0.periodKey == period })
        let records = try withExtendedLifetime(reader) { try reader.fetch(descriptor).map(EntrySnapshot.init) }
        return Self.selectWeeklyReview(records)
    }
    @discardableResult
    func saveFocusNote(text: String, intention: String, sessionID: String, completedAt: Date = .now,
                       mood: Mood? = nil, themes: ThemeSelection? = nil, recordID: UUID = UUID()) throws -> SaveReceipt {
        try saveEntry(text: text, prompt: intention, kind: JournalEntry.kindFocus, mood: mood, themes: themes,
                      day: CivilDay(date: completedAt), date: completedAt, recordID: recordID, sessionID: sessionID)
    }
    private func saveEntry(text: String, prompt: String, kind: String, mood: Mood?, themes: ThemeSelection?, day: CivilDay,
                           date: Date, recordID: UUID, practiceID: String? = nil, sessionID: String? = nil) throws -> SaveReceipt {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RepositoryError.emptyContent }
        // Return identity after save; a SwiftData temporary identifier before save is not a receipt.
        return try commit({ writer -> JournalEntry in
            if let existing = try entry(id: recordID, in: writer) {
                // A draft resaved under its own identity (retry after a failed
                // cleanup, or an edited focus note) updates the writing in place.
                // Date, civil day, zone and links stay as first captured; an
                // identical resave is a no-op so nothing duplicates or churns.
                let intentionChanged = sessionID != nil && existing.prompt != prompt
                let themesChanged = themes.map { $0 != existing.themes } ?? false
                if existing.text != text || existing.mood != mood?.rawValue || intentionChanged || themesChanged {
                    existing.text = text; existing.mood = mood?.rawValue
                    if intentionChanged { existing.prompt = prompt }
                    if let themes { existing.themes = themes }
                    existing.updatedAt = .now
                }
                return existing
            }
            let value = JournalEntry(date: date, prompt: prompt, text: text, kind: kind, mood: mood, themes: themes ?? ThemeSelection())
            value.recordID = recordID; value.civilDay = day.key; value.timeZoneIdentifier = day.timeZoneIdentifier
            value.practiceID = practiceID; value.sessionID = sessionID
            writer.insert(value)
            if let sessionID {
                let metadata = try metadata(sessionID: sessionID, in: writer) ?? FocusSessionMetadata(sessionID: sessionID, intention: prompt, completedAt: date)
                if metadata.modelContext == nil { writer.insert(metadata) }
                metadata.closingNoteRecordID = recordID
            }
            return value
        }, result: receipt)
    }

    @discardableResult
    func saveRetro(wentWell: String, improve: String, tomorrow: String, mood: Mood? = nil, themes: ThemeSelection? = nil,
                   day: CivilDay = .today(), date: Date = .now, practiceID: String? = nil,
                   promptSnapshot: String? = nil, tomorrowIntention: String? = nil,
                   recordID: UUID = UUID()) throws -> SaveReceipt {
        guard [wentWell, improve, tomorrow, tomorrowIntention ?? ""].contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) || mood != nil else { throw RepositoryError.emptyContent }
        return try commit({ writer -> DailyRetro in
            if let existing = try retro(id: recordID, in: writer) {
                let themesChanged = themes.map { $0 != existing.themes } ?? false
                if existing.wentWell != wentWell || existing.improve != improve || existing.tomorrow != tomorrow
                    || existing.mood != mood?.rawValue || existing.tomorrowIntention != tomorrowIntention || themesChanged {
                    existing.wentWell = wentWell; existing.improve = improve; existing.tomorrow = tomorrow
                    existing.mood = mood?.rawValue; existing.tomorrowIntention = tomorrowIntention
                    if let themes { existing.themes = themes }
                    existing.updatedAt = .now
                }
                return existing
            }
            let value = DailyRetro(date: date, wentWell: wentWell, improve: improve, tomorrow: tomorrow, mood: mood,
                                   themes: themes ?? ThemeSelection())
            value.recordID = recordID; value.civilDay = day.key; value.timeZoneIdentifier = day.timeZoneIdentifier
            value.practiceID = practiceID; value.promptSnapshot = promptSnapshot; value.tomorrowIntention = tomorrowIntention
            writer.insert(value); return value
        }, result: receipt)
    }

    @discardableResult
    func updateEntry(id: UUID, text: String, mood: Mood?, themes: ThemeSelection? = nil) throws -> SaveReceipt {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RepositoryError.emptyContent }
        return try commit({ writer -> JournalEntry in
            guard let value = try entry(id: id, in: writer) else { throw RepositoryError.notFound }
            value.text = text; value.mood = mood?.rawValue
            if let themes { value.themes = themes }
            value.updatedAt = .now; return value
        }, result: receipt)
    }
    @discardableResult
    func updateRetro(id: UUID, wentWell: String, improve: String, tomorrow: String, mood: Mood?, themes: ThemeSelection? = nil,
                     tomorrowIntention: String? = nil) throws -> SaveReceipt {
        guard [wentWell, improve, tomorrow, tomorrowIntention ?? ""].contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) || mood != nil else { throw RepositoryError.emptyContent }
        return try commit({ writer -> DailyRetro in
            guard let value = try retro(id: id, in: writer) else { throw RepositoryError.notFound }
            value.wentWell = wentWell; value.improve = improve; value.tomorrow = tomorrow
            value.mood = mood?.rawValue; value.tomorrowIntention = tomorrowIntention
            if let themes { value.themes = themes }
            value.updatedAt = .now; return value
        }, result: receipt)
    }
    func deleteEntry(id: UUID) throws {
        try commit { writer in
            guard let value = try entry(id: id, in: writer) else { throw RepositoryError.notFound }
            writer.delete(value)
            for metadata in try writer.fetch(FetchDescriptor<FocusSessionMetadata>()) where metadata.closingNoteRecordID == id {
                metadata.closingNoteRecordID = nil
            }
        }
    }
    func deleteRetro(id: UUID) throws {
        try commit { writer in
            guard let value = try retro(id: id, in: writer) else { throw RepositoryError.notFound }
            writer.delete(value)
        }
    }
    func deleteAllJournalData() throws {
        try commit { writer in
            for value in try writer.fetch(FetchDescriptor<JournalEntry>()) { writer.delete(value) }
            for value in try writer.fetch(FetchDescriptor<DailyRetro>()) { writer.delete(value) }
            for value in try writer.fetch(FetchDescriptor<FocusSessionMetadata>()) { writer.delete(value) }
        }
    }

    func entry(id: UUID) throws -> EntrySnapshot? {
        let reader = context()
        return try withExtendedLifetime(reader) { try entry(id: id, in: reader).map(EntrySnapshot.init) }
    }
    func retro(id: UUID) throws -> RetroSnapshot? {
        let reader = context()
        return try withExtendedLifetime(reader) { try retro(id: id, in: reader).map(RetroSnapshot.init) }
    }
    private func entry(id: UUID, in context: ModelContext) throws -> JournalEntry? {
        var descriptor = FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.recordID == id })
        descriptor.fetchLimit = 1; return try context.fetch(descriptor).first
    }
    private func retro(id: UUID, in context: ModelContext) throws -> DailyRetro? {
        var descriptor = FetchDescriptor<DailyRetro>(predicate: #Predicate { $0.recordID == id })
        descriptor.fetchLimit = 1; return try context.fetch(descriptor).first
    }
    func answer(for day: CivilDay) throws -> DailySelection<EntrySnapshot>? {
        let key = day.key; let start = day.start; let end = day.next.start; let kind = JournalEntry.kindQuestion
        let descriptor = FetchDescriptor<JournalEntry>(predicate: #Predicate {
            $0.kind == kind && ($0.civilDay == key || ($0.civilDay == nil && $0.date >= start && $0.date < end))
        })
        let reader = context()
        let records = try withExtendedLifetime(reader) { try reader.fetch(descriptor).map(EntrySnapshot.init) }
        return Self.selectAnswer(records)
    }
    func retro(for day: CivilDay) throws -> DailySelection<RetroSnapshot>? {
        let key = day.key; let start = day.start; let end = day.next.start
        let descriptor = FetchDescriptor<DailyRetro>(predicate: #Predicate {
            $0.civilDay == key || ($0.civilDay == nil && $0.date >= start && $0.date < end)
        })
        let reader = context()
        let records = try withExtendedLifetime(reader) { try reader.fetch(descriptor).map(RetroSnapshot.init) }
        return Self.selectRetro(records)
    }
    /// Every record that shares this entry's day (an answer) or week (a
    /// weekly review), the entry included, newest edit first: what "Another
    /// version from this day" offers (`design/journal.md` sections 5 and
    /// 6). Nil for a missing entry and for notes and focus notes, which are
    /// not one per day.
    func selection(containingEntry id: UUID) throws -> DailySelection<EntrySnapshot>? {
        guard let entry = try entry(id: id) else { return nil }
        switch entry.kind {
        case JournalEntry.kindQuestion: return try answer(for: entry.day)
        case JournalEntry.kindWeeklyReview: return try entry.periodKey.flatMap(weeklyReview(periodKey:))
        default: return nil
        }
    }
    /// Every retro of this retro's day, itself included, newest edit first.
    func selection(containingRetro id: UUID) throws -> DailySelection<RetroSnapshot>? {
        guard let value = try retro(id: id) else { return nil }
        return try retro(for: value.day)
    }
    private static func selectAnswer(_ records: [EntrySnapshot]) -> DailySelection<EntrySnapshot>? {
        JournalIdentity.select(records, latestEdit: \.latestEdit, recordID: { $0.recordID }, tiebreak: { $0.prompt + $0.text })
    }
    private static func selectWeeklyReview(_ records: [EntrySnapshot]) -> DailySelection<EntrySnapshot>? {
        JournalIdentity.select(records, latestEdit: \.latestEdit, recordID: { $0.recordID }, tiebreak: { $0.text })
    }
    private static func selectRetro(_ records: [RetroSnapshot]) -> DailySelection<RetroSnapshot>? {
        JournalIdentity.select(records, latestEdit: \.latestEdit, recordID: { $0.recordID }, tiebreak: { $0.wentWell + $0.improve + $0.tomorrow })
    }

    /// Every answer, retro and weekly review that is not the primary of its
    /// day or week: the other versions of `design/journal.md` section 6,
    /// which the unfiltered Journal list leaves out. Grouped the way
    /// `answer(for:)`, `retro(for:)` and `weeklyReview(weekStart:)` group.
    func versionRecordIDs() throws -> Set<UUID> {
        let reader = context()
        return try withExtendedLifetime(reader) {
            let question = JournalEntry.kindQuestion; let weekly = JournalEntry.kindWeeklyReview
            let entries = try reader.fetch(FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.kind == question || $0.kind == weekly }))
                .map(EntrySnapshot.init)
            let retros = try reader.fetch(FetchDescriptor<DailyRetro>()).map(RetroSnapshot.init)
            func dayKey(_ stored: String?, _ zone: String?, _ date: Date) -> String {
                (CivilDay(storedKey: stored, timeZoneIdentifier: zone) ?? CivilDay(date: date)).key
            }
            let answers = Dictionary(grouping: entries.filter { $0.kind == question }) { dayKey($0.civilDay, $0.timeZoneIdentifier, $0.date) }
            let reviews = Dictionary(grouping: entries.filter { $0.kind == weekly && $0.periodKey != nil }) { $0.periodKey ?? "" }
            let days = Dictionary(grouping: retros) { dayKey($0.civilDay, $0.timeZoneIdentifier, $0.date) }
            let variants = answers.values.compactMap(Self.selectAnswer).flatMap(\.variants).map(\.recordID)
                + reviews.values.compactMap(Self.selectWeeklyReview).flatMap(\.variants).map(\.recordID)
                + days.values.compactMap(Self.selectRetro).flatMap(\.variants).map(\.recordID)
            return Set(variants.compactMap { $0 })
        }
    }

    /// Filters and exclusions run in the store; search runs over the
    /// filtered rows in bounded chunks, because post-filtering gives
    /// consistent localized matching across SQLite and in-memory stores.
    /// Only the requested page remains retained.
    func entries(matching query: EntryQuery = EntryQuery(), page: Page = Page()) throws -> JournalPage<EntrySnapshot> {
        let predicate = Self.predicate(query)
        let sort = [SortDescriptor(\JournalEntry.date, order: .reverse), SortDescriptor(\JournalEntry.prompt), SortDescriptor(\JournalEntry.text)]
        return try fetchPage(page, search: query.search, predicate: predicate, sort: sort, snapshot: EntrySnapshot.init,
                             searchFields: { [$0.prompt, $0.text, $0.nextIntention ?? ""] })
    }
    func retros(matching query: RetroQuery = RetroQuery(), page: Page = Page()) throws -> JournalPage<RetroSnapshot> {
        let predicate = Self.predicate(query)
        let sort = [SortDescriptor(\DailyRetro.date, order: .reverse), SortDescriptor(\DailyRetro.wentWell), SortDescriptor(\DailyRetro.improve)]
        return try fetchPage(page, search: query.search, predicate: predicate, sort: sort, snapshot: RetroSnapshot.init,
                             searchFields: { [$0.wentWell, $0.improve, $0.tomorrow, $0.promptSnapshot ?? "", $0.tomorrowIntention ?? ""] })
    }
    private func fetchPage<Model: PersistentModel, Snapshot>(
        _ page: Page, search: String, predicate: Predicate<Model>, sort: [SortDescriptor<Model>],
        snapshot: (Model) -> Snapshot, searchFields: (Snapshot) -> [String]
    ) throws -> JournalPage<Snapshot> {
        let reader = context()
        return try withExtendedLifetime(reader) {
            if search.isEmpty {
                let start = max(0, page.offset)
                let count = try reader.fetchCount(FetchDescriptor(predicate: predicate))
                var descriptor = FetchDescriptor(predicate: predicate, sortBy: sort)
                descriptor.fetchOffset = start
                descriptor.fetchLimit = min(200, max(1, page.limit))
                let records = try reader.fetch(descriptor).map(snapshot)
                return JournalPage(records: records, totalCount: count, hasMore: start + records.count < count, nextOffset: start + records.count)
            }
            return try scan(page: page, fetch: { offset in
                var descriptor = FetchDescriptor(predicate: predicate, sortBy: sort)
                descriptor.fetchOffset = offset; descriptor.fetchLimit = 200
                return try reader.fetch(descriptor).map(snapshot)
            }, matches: { Self.matchesSearch(search, fields: searchFields($0)) })
        }
    }
    private func scan<T>(page: Page, fetch: (Int) throws -> [T], matches: (T) -> Bool) throws -> JournalPage<T> {
        var records: [T] = []; var count = 0; var offset = 0
        let start = max(0, page.offset); let limit = min(200, max(1, page.limit))
        while true {
            let batch = try fetch(offset)
            for item in batch where matches(item) {
                if count >= start && records.count < limit { records.append(item) }
                count += 1
            }
            if batch.count < 200 { break }
            offset += batch.count
        }
        return JournalPage(records: records, totalCount: count, hasMore: start + records.count < count, nextOffset: start + records.count)
    }
    private static func matchesSearch(_ search: String, fields: [String]) -> Bool {
        search.isEmpty || fields.contains { $0.localizedStandardContains(search) }
    }

    // Each filter is its own small predicate, combined with `evaluate`, so
    // the type checker copes. A filter that is off reads as `true`. The two
    // models need their own copies: `#Predicate` takes no key-path
    // parameters, and captures only plain values.
    private static func predicate(_ query: EntryQuery) -> Predicate<JournalEntry> {
        let anyKind = query.kind == nil; let kind = query.kind ?? ""
        let byKind = #Predicate<JournalEntry> { anyKind || $0.kind == kind }
        let (anyMood, untagged, mood) = moodTerms(query.mood)
        let byMood = #Predicate<JournalEntry> { anyMood || untagged || $0.mood == mood }
        // SwiftData translates neither `??` nor `!` inside `contains`, so an
        // unknown value is "none of the five".
        let (low, flat, steady, good, sharp) = (Mood.low.rawValue, Mood.flat.rawValue, Mood.steady.rawValue, Mood.good.rawValue, Mood.sharp.rawValue)
        let byNoMood = #Predicate<JournalEntry> {
            !untagged || $0.mood == nil || ($0.mood != low && $0.mood != flat && $0.mood != steady && $0.mood != good && $0.mood != sharp)
        }
        let anyTheme = query.theme == nil; let theme: String? = query.theme?.rawValue
        let byTheme = #Predicate<JournalEntry> { anyTheme || $0.theme == theme || $0.secondaryTheme == theme }
        let anyDate = query.dateRange == nil
        let start = query.dateRange?.start ?? .distantPast; let end = query.dateRange?.end ?? .distantFuture
        let byDate = #Predicate<JournalEntry> { anyDate || ($0.date >= start && $0.date < end) }
        let excluded = Array(query.excluding)
        let byVersion = #Predicate<JournalEntry> { entry in entry.recordID.flatMap { !excluded.contains($0) } ?? true }
        return #Predicate<JournalEntry> {
            byKind.evaluate($0) && byMood.evaluate($0) && byNoMood.evaluate($0) && byTheme.evaluate($0) && byDate.evaluate($0) && byVersion.evaluate($0)
        }
    }
    private static func predicate(_ query: RetroQuery) -> Predicate<DailyRetro> {
        let (anyMood, untagged, mood) = moodTerms(query.mood)
        let byMood = #Predicate<DailyRetro> { anyMood || untagged || $0.mood == mood }
        // SwiftData translates neither `??` nor `!` inside `contains`, so an
        // unknown value is "none of the five".
        let (low, flat, steady, good, sharp) = (Mood.low.rawValue, Mood.flat.rawValue, Mood.steady.rawValue, Mood.good.rawValue, Mood.sharp.rawValue)
        let byNoMood = #Predicate<DailyRetro> {
            !untagged || $0.mood == nil || ($0.mood != low && $0.mood != flat && $0.mood != steady && $0.mood != good && $0.mood != sharp)
        }
        let anyTheme = query.theme == nil; let theme: String? = query.theme?.rawValue
        let byTheme = #Predicate<DailyRetro> { anyTheme || $0.theme == theme || $0.secondaryTheme == theme }
        let anyDate = query.dateRange == nil
        let start = query.dateRange?.start ?? .distantPast; let end = query.dateRange?.end ?? .distantFuture
        let byDate = #Predicate<DailyRetro> { anyDate || ($0.date >= start && $0.date < end) }
        let excluded = Array(query.excluding)
        let byVersion = #Predicate<DailyRetro> { retro in retro.recordID.flatMap { !excluded.contains($0) } ?? true }
        return #Predicate<DailyRetro> {
            byMood.evaluate($0) && byNoMood.evaluate($0) && byTheme.evaluate($0) && byDate.evaluate($0) && byVersion.evaluate($0)
        }
    }
    /// "No mood" also matches a raw value this version does not know,
    /// which `Mood(stored:)` reads back as untagged.
    private static func moodTerms(_ filter: MoodFilter) -> (any: Bool, untagged: Bool, raw: String?) {
        switch filter {
        case .all: (true, false, nil)
        case .untagged: (false, true, nil)
        case .tagged(let mood): (false, false, mood.rawValue)
        }
    }
    /// Whether anything is written at all, or, with `kind`, any entry of
    /// that kind.
    func hasRecords(kind: String? = nil) throws -> Bool {
        let reader = context()
        if let kind {
            var descriptor = FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.kind == kind })
            descriptor.fetchLimit = 1
            return try reader.fetchCount(descriptor) > 0
        }
        return try reader.fetchCount(FetchDescriptor<JournalEntry>()) + reader.fetchCount(FetchDescriptor<DailyRetro>()) > 0
    }
    func exportSnapshot() throws -> JournalExport {
        let reader = context()
        return JournalExport(entries: try reader.fetch(FetchDescriptor<JournalEntry>()), retrospectives: try reader.fetch(FetchDescriptor<DailyRetro>()))
    }
    func activitySummary(in interval: DateInterval) throws -> ActivitySummary {
        let reader = context(); let start = interval.start; let end = interval.end
        let entries = try reader.fetch(FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.date >= start && $0.date < end }))
        let retros = try reader.fetch(FetchDescriptor<DailyRetro>(predicate: #Predicate { $0.date >= start && $0.date < end }))
        var result = ActivitySummary()
        // The weekly review describes the week; it is not one of the week's entries.
        let counted = entries.filter { $0.kind != JournalEntry.kindWeeklyReview }
        for entry in counted {
            switch entry.kind { case JournalEntry.kindQuestion: result.answers += 1; case JournalEntry.kindFocus: result.focusNotes += 1; default: result.notes += 1 }
        }
        result.retros = retros.count
        for raw in counted.map(\.mood) + retros.map(\.mood) {
            if let mood = Mood(stored: raw) { result.taggedMoodCounts[mood.rawValue, default: 0] += 1 }
            else { result.untaggedCount += 1 }
        }
        return result
    }
    func sessionMetadata(sessionID: String) throws -> SessionSnapshot? {
        let reader = context()
        return try withExtendedLifetime(reader) { try metadata(sessionID: sessionID, in: reader).map(SessionSnapshot.init) }
    }
    private func metadata(sessionID: String, in context: ModelContext) throws -> FocusSessionMetadata? {
        let descriptor = FetchDescriptor<FocusSessionMetadata>(predicate: #Predicate { $0.sessionID == sessionID })
        return try context.fetch(descriptor).sorted { ($0.recordID?.uuidString ?? "") < ($1.recordID?.uuidString ?? "") }.first
    }
    func upsertSessionMetadata(sessionID: String, intention: String?, outcome: FocusOutcome? = nil,
                               energy: EnergyLevel? = nil, closingNoteRecordID: UUID? = nil, completedAt: Date? = nil) throws {
        try commit { writer in
            let value = try metadata(sessionID: sessionID, in: writer) ?? FocusSessionMetadata(sessionID: sessionID, intention: intention, completedAt: completedAt)
            if value.modelContext == nil { writer.insert(value) }
            value.intention = intention; value.outcome = outcome?.rawValue; value.energy = energy?.rawValue
            if let closingNoteRecordID { value.closingNoteRecordID = closingNoteRecordID }
            if let completedAt {
                value.completedAt = completedAt
                let day = CivilDay(date: completedAt); value.civilDay = day.key; value.timeZoneIdentifier = day.timeZoneIdentifier
            }
            value.updatedAt = .now
        }
    }
    func carriedIntention(for day: CivilDay) throws -> String? { try retro(for: day.previous)?.primary.tomorrowIntention }
    func ensureRecordIdentities() throws {
        try commit { writer in
            for value in try writer.fetch(FetchDescriptor<JournalEntry>()) where value.recordID == nil { value.recordID = UUID() }
            for value in try writer.fetch(FetchDescriptor<DailyRetro>()) where value.recordID == nil { value.recordID = UUID() }
            for value in try writer.fetch(FetchDescriptor<FocusSessionMetadata>()) where value.recordID == nil { value.recordID = UUID() }
        }
    }
    private func receipt(_ value: JournalEntry) -> SaveReceipt {
        SaveReceipt(recordID: value.recordID!, persistentID: value.persistentModelID,
                    civilDay: CivilDay(storedKey: value.civilDay, timeZoneIdentifier: value.timeZoneIdentifier) ?? CivilDay(date: value.date))
    }
    private func receipt(_ value: DailyRetro) -> SaveReceipt {
        SaveReceipt(recordID: value.recordID!, persistentID: value.persistentModelID,
                    civilDay: CivilDay(storedKey: value.civilDay, timeZoneIdentifier: value.timeZoneIdentifier) ?? CivilDay(date: value.date))
    }
}
