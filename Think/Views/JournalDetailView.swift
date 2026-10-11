//
//  JournalDetailView.swift
//  Think
//

import SwiftUI

// MARK: - Draft construction for editing stored records

extension JournalDraft {
    /// Builds an editing draft bound to a stored entry. Nil when the record
    /// predates identities (root runs `ensureRecordIdentities()` at launch,
    /// so this only happens if that pass failed).
    static func editing(_ entry: JournalRepository.EntrySnapshot) -> JournalDraft? {
        guard let recordID = entry.recordID else { return nil }
        let kind: Kind
        switch entry.kind {
        case JournalEntry.kindQuestion: kind = .answer
        case JournalEntry.kindFocus: kind = .focus
        case JournalEntry.kindWeeklyReview: kind = .weeklyReview
        default: kind = .note
        }
        let day = entry.day
        var draft = JournalDraft(
            kind: kind,
            context: Context(
                civilDay: day,
                practiceID: entry.practiceID,
                promptSnapshot: entry.prompt.isEmpty ? nil : entry.prompt,
                sessionID: entry.sessionID,
                editingRecordID: recordID,
                periodKey: entry.periodKey
            )
        )
        draft.text = entry.text
        draft.mood = entry.mood
        draft.themes = entry.themes
        draft.tomorrowIntention = entry.nextIntention
        return draft
    }

    static func editing(_ retro: JournalRepository.RetroSnapshot) -> JournalDraft? {
        guard let recordID = retro.recordID else { return nil }
        let day = retro.day
        var draft = JournalDraft(
            kind: .retro,
            context: Context(
                civilDay: day,
                practiceID: retro.practiceID,
                promptSnapshot: retro.promptSnapshot,
                editingRecordID: recordID
            )
        )
        draft.fields = ["wentWell": retro.wentWell, "improve": retro.improve, "tomorrow": retro.tomorrow]
        draft.mood = retro.mood
        draft.themes = retro.themes
        draft.tomorrowIntention = retro.tomorrowIntention
        return draft
    }

    var kindLabel: String {
        switch kind {
        case .answer: String(localized: "Question of the day")
        case .note: String(localized: "Note")
        case .retro: String(localized: "Retrospective")
        case .focus: String(localized: "Focus note")
        case .weeklyReview: String(localized: "Weekly review")
        }
    }

    /// First non-empty line of whatever the draft holds, for recovery rows.
    var recoveryPreview: String {
        let candidates = [text, fields["wentWell"] ?? "", fields["improve"] ?? "", fields["tomorrow"] ?? "", tomorrowIntention ?? ""]
        let line =
            candidates.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?
            .split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return line.isEmpty ? String(localized: "No text yet") : line
    }
}

extension JournalRepository.EntrySnapshot {
    var day: CivilDay { CivilDay(storedKey: civilDay, timeZoneIdentifier: timeZoneIdentifier) ?? CivilDay(date: date) }
}

extension JournalRepository.RetroSnapshot {
    var day: CivilDay { CivilDay(storedKey: civilDay, timeZoneIdentifier: timeZoneIdentifier) ?? CivilDay(date: date) }
}

/// Finds an unsaved edit already on disk for a record, so reopening Edit
/// never spawns a second draft file for the same row.
@MainActor
func existingEditingDraft(for recordID: UUID, in drafts: JournalDraftStore) throws -> JournalDraft? {
    try drafts.drafts().first { $0.context.editingRecordID == recordID }
}

// MARK: - Read detail

/// A record the read detail opens. Entries and retros live in separate
/// tables, so the ID alone does not say where to look.
enum JournalRecordID: Hashable {
    case entry(UUID)
    case retro(UUID)

    var uuid: UUID {
        switch self {
        case .entry(let id), .retro(let id): id
        }
    }
}

/// What the read detail says (`design/journal.md` section 5): the civil
/// day, the prompt, the writing, when it was written and edited, and its
/// mood and themes.
struct JournalDetailContent: Equatable {
    struct Prompt: Equatable {
        enum Style: Equatable {
            /// The question of the day, or the week a review is about.
            case question
            /// A focus note's session intention: read-only, so it reads
            /// in `secondaryLabel`.
            case intention
        }
        let text: String
        let style: Style
    }

    /// One block of writing, under its prompt when it has one (a retro's
    /// three prompts, "Intention for tomorrow", "Next week").
    struct Field: Equatable {
        let heading: String?
        let text: String
    }

    let kind: JournalRowContent.Kind
    /// The civil day in full. Nil for a weekly review, whose prompt
    /// already names its week.
    let day: String?
    let prompt: Prompt?
    let fields: [Field]
    /// "Written *time*", plus " · Edited *time*" after a later edit.
    let written: String?
    let mood: Mood?
    /// Mood, primary theme and secondary theme joined by " · ".
    let tags: String?

    var title: String { kind.name }

    var deleteTitle: String {
        kind == .retro ? String(localized: "Delete this retro?") : String(localized: "Delete this entry?")
    }

    init(_ entry: JournalRepository.EntrySnapshot) {
        kind = JournalRowContent.Kind(stored: entry.kind)
        let day = entry.day
        switch kind {
        case .weeklyReview:
            self.day = nil
            prompt = Prompt(text: JournalRowContent(entry).title, style: .question)
            fields = Self.fields([(nil, entry.text), (String(localized: "Next week"), entry.nextIntention ?? "")])
            written = Self.written(nil, updatedAt: entry.updatedAt, day: day)
        default:
            self.day = JournalTimeline.fullDate(day)
            // A note saved from a practice keeps its prompt too.
            prompt = entry.prompt.isEmpty ? nil : Prompt(text: entry.prompt, style: kind == .focusNote ? .intention : .question)
            fields = Self.fields([(nil, entry.text)])
            written = Self.written(entry.date, updatedAt: entry.updatedAt, day: day)
        }
        mood = Mood(stored: entry.mood)
        tags = Self.tags(mood, entry.themes)
    }

    init(_ retro: JournalRepository.RetroSnapshot) {
        kind = .retro
        let day = retro.day
        self.day = JournalTimeline.fullDate(day)
        prompt = nil
        fields = Self.fields([
            (String(localized: "What went well?"), retro.wentWell),
            (String(localized: "What can improve?"), retro.improve),
            (String(localized: "Ideas & tomorrow"), retro.tomorrow),
            (String(localized: "Intention for tomorrow"), retro.tomorrowIntention ?? ""),
        ])
        written = Self.written(retro.date, updatedAt: retro.updatedAt, day: day)
        mood = Mood(stored: retro.mood)
        tags = Self.tags(mood, retro.themes)
    }

    /// The non-empty blocks, in order.
    private static func fields(_ blocks: [(String?, String)]) -> [Field] {
        blocks
            .filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { Field(heading: $0.0, text: $0.1) }
    }

    /// Times read in the zone the day was captured in. An edit on a later
    /// day carries its date, so "Edited" never passes for the same day.
    private static func written(_ date: Date?, updatedAt: Date?, day: CivilDay) -> String? {
        var parts: [String] = []
        if let date {
            parts.append(String(localized: "Written \(format(date, zone: day.timeZone, withDate: false))"))
        }
        if let updatedAt, updatedAt != date {
            parts.append(String(localized: "Edited \(format(updatedAt, zone: day.timeZone, withDate: !day.contains(updatedAt)))"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func format(_ date: Date, zone: TimeZone, withDate: Bool) -> String {
        var style = Date.FormatStyle(date: withDate ? .abbreviated : .omitted, time: .shortened)
        style.timeZone = zone
        return date.formatted(style)
    }

    private static func tags(_ mood: Mood?, _ themes: ThemeSelection) -> String? {
        let parts = [mood?.label, themes.primary?.label, themes.secondary?.label].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Another record of the same day or week, as a row in the versions list.
struct JournalVersion: Identifiable {
    let record: JournalRecordID
    let row: JournalRowContent
    var id: UUID { record.uuid }
}

extension JournalRepository {
    /// The other versions of a record's day or week, newest edit first
    /// (`design/journal.md` section 6). Empty for a record that has none.
    func otherVersions(of record: JournalRecordID) throws -> [JournalVersion] {
        switch record {
        case .entry(let id):
            return try (selection(containingEntry: id)?.all ?? []).compactMap { entry in
                guard let other = entry.recordID, other != id else { return nil }
                return JournalVersion(record: .entry(other), row: JournalRowContent(entry))
            }
        case .retro(let id):
            return try (selection(containingRetro: id)?.all ?? []).compactMap { retro in
                guard let other = retro.recordID, other != id else { return nil }
                return JournalVersion(record: .retro(other), row: JournalRowContent(retro))
            }
        }
    }
}

/// The one read-only view of a journal record (`design/journal.md`
/// section 5), pushed from a Journal row, from Today's done answer and
/// retro rows and from the weekly review's saved reflection. Nothing
/// private renders while the lock is engaged: a detail that locks
/// underneath shows the Locked state (section 7).
struct JournalDetailView: View {
    let record: JournalRecordID
    /// Told when a delete succeeded but left something behind, after the
    /// view has popped. The presenting screen shows it.
    var onNotice: ((String) -> Void)?

    private struct Loaded {
        let content: JournalDetailContent
        /// The editor's draft for this record; nil only for a row that
        /// predates record identities.
        let draft: JournalDraft?
        let versions: [JournalVersion]
    }

    @Environment(JournalRepository.self) private var repository
    @Environment(JournalDraftStore.self) private var drafts
    @Environment(JournalLock.self) private var lock
    @Environment(\.dismiss) private var dismiss
    @ThinkSpacing.Scaled(ThinkSpacing.s) private var gap
    @ThinkSpacing.Scaled(ThinkSpacing.xs) private var tightGap
    @State private var loaded: Loaded?
    @State private var missing = false
    @State private var loadFailed = false
    /// Set once the record is gone, so the revision bump does not flash
    /// "Entry not found." while the view pops.
    @State private var deleted = false
    @State private var editing: JournalDraft?
    @State private var confirmingDelete = false
    @State private var error: String?

    var body: some View {
        Group {
            if lock.isLocked {
                JournalGate()
            } else if let loaded {
                content(loaded)
            } else if missing {
                unavailable("Entry not found.", action: "Close") { dismiss() }
                    .accessibilityIdentifier("JournalDetailMissing")
            } else if loadFailed {
                unavailable("Could not load this entry.", action: "Try again") { load() }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(loaded?.content.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("JournalDetail")
        .toolbar {
            if !lock.isLocked, loaded != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { edit() }
                        .accessibilityIdentifier("EditEntry")
                }
            }
        }
        .sheet(item: $editing) { draft in JournalEditor(draft: draft) }
        .task { load() }
        .onChange(of: repository.revision) { _, _ in load() }
        .onChange(of: lock.isLocked) { _, locked in if !locked { load() } }
    }

    private func content(_ loaded: Loaded) -> some View {
        List {
            if repository.storageWarning != nil || error != nil {
                Section {
                    JournalStorageWarning()
                    if let error {
                        Text(error).foregroundStyle(ThinkColor.destructive).accessibilityIdentifier("JournalDetailError")
                    }
                }
            }
            Section {
                recordRow(loaded.content)
                    .listRowBackground(Color.clear)
            }
            if !loaded.versions.isEmpty {
                Section { versionsLink(loaded.versions) }
            }
            Section {
                Button("Delete entry", role: .destructive) { confirmingDelete = true }
                    .accessibilityIdentifier("DeleteEntry")
                    // On the row, so the dialog points at what asked for it.
                    .confirmationDialog(loaded.content.deleteTitle, isPresented: $confirmingDelete, titleVisibility: .visible) {
                        Button("Delete entry", role: .destructive) { delete() }
                            .accessibilityIdentifier("ConfirmDeleteEntry")
                    } message: {
                        Text("It is removed from this device and your iCloud.")
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// The one clear content row. Each text stays its own element so
    /// VoiceOver reaches and selects the writing.
    private func recordRow(_ content: JournalDetailContent) -> some View {
        VStack(alignment: .leading, spacing: gap) {
            if let day = content.day {
                Text(day)
                    .font(.think(.caption))
                    .foregroundStyle(ThinkColor.secondaryLabel)
            }
            if let prompt = content.prompt {
                Text(prompt.text)
                    .font(.think(.question))
                    .foregroundStyle(prompt.style == .intention ? ThinkColor.secondaryLabel : ThinkColor.label)
                    .accessibilityIdentifier("JournalDetailPrompt")
            }
            ForEach(Array(content.fields.enumerated()), id: \.offset) { index, field in
                VStack(alignment: .leading, spacing: tightGap) {
                    if let heading = field.heading {
                        Text(heading)
                            .font(.think(.secondary))
                            .fontWeight(.semibold)
                            .foregroundStyle(ThinkColor.secondaryLabel)
                    }
                    Text(field.text)
                        .font(.think(.body))
                        .foregroundStyle(ThinkColor.label)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("JournalDetailText.\(index)")
                }
            }
            VStack(alignment: .leading, spacing: tightGap) {
                if let written = content.written {
                    Text(written)
                }
                if let tags = content.tags {
                    HStack(alignment: .firstTextBaseline, spacing: tightGap) {
                        if let mood = content.mood { Image(systemName: mood.systemImage).accessibilityHidden(true) }
                        // Wraps at accessibility sizes instead of truncating.
                        Text(tags).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .font(.think(.caption))
            .foregroundStyle(ThinkColor.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One version pushes its detail; more than one push a list of them.
    private func versionsLink(_ versions: [JournalVersion]) -> some View {
        NavigationLink {
            if versions.count == 1 {
                JournalDetailView(record: versions[0].record)
            } else {
                JournalVersionsView(record: record)
            }
        } label: {
            Text("Another version from this day")
        }
        .accessibilityIdentifier("AnotherVersion")
    }

    private func unavailable(_ title: LocalizedStringKey, action: LocalizedStringKey, perform: @escaping () -> Void) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: ThinkSymbol.unavailable)
        } actions: {
            Button(action, action: perform).thinkButton(.secondary)
        }
    }

    private func load() {
        guard !lock.isLocked, !deleted else { return }
        do {
            switch record {
            case .entry(let id):
                guard let entry = try repository.entry(id: id) else {
                    loaded = nil
                    missing = true
                    return
                }
                loaded = Loaded(
                    content: JournalDetailContent(entry), draft: JournalDraft.editing(entry),
                    versions: try repository.otherVersions(of: record))
            case .retro(let id):
                guard let retro = try repository.retro(id: id) else {
                    loaded = nil
                    missing = true
                    return
                }
                loaded = Loaded(
                    content: JournalDetailContent(retro), draft: JournalDraft.editing(retro),
                    versions: try repository.otherVersions(of: record))
            }
            missing = false
            loadFailed = false
        } catch {
            // What already loaded stays; the failure becomes a row above it.
            if loaded == nil {
                loadFailed = true
            } else {
                self.error = String(localized: "Could not load this entry. Try again.")
            }
        }
    }

    private func edit() {
        guard let loaded else { return }
        do {
            if let draft = try existingEditingDraft(for: record.uuid, in: drafts) {
                editing = draft
                return
            }
            guard let draft = loaded.draft else {
                error = String(localized: "This entry has no identity yet and cannot be edited.")
                return
            }
            editing = draft
        } catch {
            self.error = String(localized: "Could not read the saved edit. Your entry is unchanged. Try again.")
        }
    }

    /// Asks first (the dialog), then removes the record and any unsaved
    /// edit of it, and pops. The record being gone is what pops the view;
    /// a leftover edit is reported to the screen underneath, because this
    /// one is leaving (`design/journal.md` section 5).
    private func delete() {
        let outcome = JournalDeletion.delete(record, repository: repository, drafts: drafts)
        guard outcome.recordRemoved else {
            error = outcome.notice
            return
        }
        deleted = true
        if let notice = outcome.notice { onNotice?(notice) }
        dismiss()
    }
}

/// The other versions of a day, newest edit first, when there is more
/// than one (`design/journal.md` section 5). Each pushes its read detail.
struct JournalVersionsView: View {
    let record: JournalRecordID

    @Environment(JournalRepository.self) private var repository
    @Environment(JournalLock.self) private var lock
    @State private var versions: [JournalVersion] = []
    @State private var loadFailed = false

    var body: some View {
        Group {
            if lock.isLocked {
                JournalGate()
            } else {
                List {
                    if loadFailed {
                        Text("Could not load this entry. Try again.")
                            .foregroundStyle(ThinkColor.destructive)
                    }
                    ForEach(versions) { version in
                        NavigationLink {
                            JournalDetailView(record: version.record)
                        } label: {
                            JournalRow(content: version.row)
                        }
                        .accessibilityIdentifier("JournalVersion.\(version.id.uuidString)")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Versions")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("JournalVersions")
        .task { load() }
        .onChange(of: repository.revision) { _, _ in load() }
        .onChange(of: lock.isLocked) { _, locked in if locked { versions = [] } else { load() } }
    }

    private func load() {
        guard !lock.isLocked else { return }
        do {
            versions = try repository.otherVersions(of: record)
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }
}

// MARK: - Draft recovery

/// Unsaved writing found on disk. Reading it is a journal read, so the
/// list only fills once unlocked. Discard is explicit and per draft.
struct JournalRecoveryView: View {
    @Environment(JournalDraftStore.self) private var drafts
    @Environment(JournalLock.self) private var lock
    @State private var recoverable: [JournalDraft] = []
    @State private var unreadableCount = 0
    @State private var opening: JournalDraft?
    @State private var discarding: JournalDraft?
    @State private var error: String?

    var body: some View {
        Group {
            if lock.isLocked {
                JournalGate()
            } else {
                List {
                    if let error {
                        Section {
                            Text(error)
                                .font(.think(.secondary))
                                .foregroundStyle(ThinkColor.destructive)
                                .accessibilityIdentifier("JournalRecoveryError")
                        }
                    }
                    if unreadableCount > 0 {
                        Section {
                            Label {
                                Text("\(unreadableCount) draft file(s) could not be read. They were left untouched on this device.")
                            } icon: {
                                Image(systemName: ThinkSymbol.unavailable)
                            }
                            .font(.think(.secondary))
                            .foregroundStyle(ThinkColor.secondaryLabel)
                            .accessibilityIdentifier("JournalRecoveryUnreadable")
                        }
                    }
                    if recoverable.isEmpty {
                        Text("No unsaved drafts.").foregroundStyle(ThinkColor.secondaryLabel)
                            .accessibilityIdentifier("JournalRecoveryEmpty")
                    } else {
                        Section {
                            ForEach(recoverable) { draft in
                                Button {
                                    opening = draft
                                } label: {
                                    recoveryRow(draft)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("RecoverDraft.\(draft.id.uuidString)")
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        discarding = draft
                                    } label: {
                                        Label("Discard", systemImage: ThinkSymbol.delete)
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        opening = draft
                                    } label: {
                                        Label("Open", systemImage: ThinkSymbol.edit)
                                    }
                                    Button(role: .destructive) {
                                        discarding = draft
                                    } label: {
                                        Label("Discard", systemImage: ThinkSymbol.delete)
                                    }
                                }
                            }
                        } footer: {
                            Text("Drafts stay on this device until you save or discard them. Opening one continues it with its original day and prompt.")
                        }
                    }
                }
            }
        }
        .navigationTitle("Unsaved drafts")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("JournalRecovery")
        .sheet(item: $opening) { draft in JournalEditor(draft: draft) }
        .confirmationDialog("Discard this draft?", isPresented: Binding(get: { discarding != nil }, set: { if !$0 { discarding = nil } }), titleVisibility: .visible) {
            Button("Discard draft", role: .destructive) { discard() }
                .accessibilityIdentifier("ConfirmDiscardDraft")
            Button("Keep", role: .cancel) { discarding = nil }
        } message: {
            Text("The unsaved text is deleted from this device and cannot be recovered.")
        }
        .task { load() }
        .onChange(of: drafts.revision) { _, _ in load() }
        .onChange(of: lock.isLocked) { _, locked in
            if locked {
                recoverable = []
                unreadableCount = 0
            } else {
                load()
            }
        }
    }

    private func recoveryRow(_ draft: JournalDraft) -> some View {
        VStack(alignment: .leading, spacing: ThinkSpacing.xs) {
            HStack(spacing: ThinkSpacing.xs) {
                Text(draft.kindLabel)
                Text(draft.context.civilDay.key)
                if draft.context.editingRecordID != nil { Text("editing") }
            }
            .font(.think(.caption))
            .foregroundStyle(ThinkColor.secondaryLabel)
            if let prompt = draft.context.promptSnapshot, !prompt.isEmpty {
                Text(prompt).font(.think(.secondary).weight(.medium)).lineLimit(2)
            }
            Text(draft.recoveryPreview).font(.think(.body)).foregroundStyle(ThinkColor.label).lineLimit(2)
            Text("Last edited \(draft.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.think(.caption)).foregroundStyle(ThinkColor.tertiaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func load() {
        guard !lock.isLocked else { return }
        do {
            let listing = try drafts.recoverableListing()
            recoverable = listing.drafts
            unreadableCount = listing.unreadableCount
            error = nil
        } catch { self.error = String(localized: "Some drafts could not be read. They were left untouched.") }
    }

    private func discard() {
        guard let draft = discarding else { return }
        do {
            try drafts.delete(id: draft.id)
            discarding = nil
            load()
        } catch { self.error = String(localized: "Could not discard this draft. It is still here. Try again.") }
    }
}
