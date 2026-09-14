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
        let day = CivilDay(storedKey: entry.civilDay, timeZoneIdentifier: entry.timeZoneIdentifier)
            ?? CivilDay(date: entry.date)
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
        draft.tomorrowIntention = entry.nextIntention
        return draft
    }

    static func editing(_ retro: JournalRepository.RetroSnapshot) -> JournalDraft? {
        guard let recordID = retro.recordID else { return nil }
        let day = CivilDay(storedKey: retro.civilDay, timeZoneIdentifier: retro.timeZoneIdentifier)
            ?? CivilDay(date: retro.date)
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
        let line = candidates.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?
            .split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return line.isEmpty ? String(localized: "No text yet") : line
    }
}

extension JournalRepository.EntrySnapshot {
    var kindLabel: String {
        switch kind {
        case JournalEntry.kindQuestion: String(localized: "Question of the day")
        case JournalEntry.kindFocus: String(localized: "Focus note")
        case JournalEntry.kindWeeklyReview: String(localized: "Weekly review")
        default: String(localized: "Note")
        }
    }
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

// MARK: - Shared rows

struct JournalMoodBadge: View {
    let mood: Mood?
    var body: some View {
        if let mood {
            Label(mood.label, systemImage: mood.systemImage)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel(mood.label)
        }
    }
}

struct JournalEntryRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let entry: JournalRepository.EntrySnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            metadataLayout {
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                Text(entry.kindLabel)
                JournalMoodBadge(mood: Mood(stored: entry.mood))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if !entry.prompt.isEmpty {
                Text(entry.prompt).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
            }
            Text(entry.text)
                .font(.body)
                .foregroundStyle(entry.prompt.isEmpty ? .primary : .secondary)
                .lineLimit(4)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
    private var metadataLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 6))
    }
}

struct JournalRetroRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let retro: JournalRepository.RetroSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            metadataLayout {
                Text(retro.date.formatted(date: .abbreviated, time: .omitted))
                Text("Retrospective")
                JournalMoodBadge(mood: Mood(stored: retro.mood))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            RetroFieldText("Went well", systemImage: "checkmark.circle", text: retro.wentWell, lineLimit: 2)
            RetroFieldText("Improve", systemImage: "arrow.up.circle", text: retro.improve, lineLimit: 2)
            RetroFieldText("Tomorrow", systemImage: "sunrise", text: retro.tomorrow, lineLimit: 2)
            RetroFieldText("Intention", systemImage: "arrow.turn.down.right", text: retro.tomorrowIntention ?? "", lineLimit: 2)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
    private var metadataLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 6))
    }
}

struct RetroFieldText: View {
    let title: LocalizedStringKey
    let systemImage: String
    let text: String
    var lineLimit: Int? = nil
    init(_ title: LocalizedStringKey, systemImage: String, text: String, lineLimit: Int? = nil) {
        self.title = title; self.systemImage = systemImage; self.text = text; self.lineLimit = lineLimit
    }
    var body: some View {
        if !text.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(text).font(.body).foregroundStyle(.primary).lineLimit(lineLimit)
            }
        }
    }
}

// MARK: - Entry detail

/// Authenticated reader for one stored entry. Nothing private renders
/// while the lock is engaged; the gate is the only content then.
struct JournalEntryDetailView: View {
    let recordID: UUID
    @Environment(JournalRepository.self) private var repository
    @Environment(JournalDraftStore.self) private var drafts
    @Environment(JournalLock.self) private var lock
    @Environment(\.dismiss) private var dismiss
    @State private var entry: JournalRepository.EntrySnapshot?
    @State private var variants: [JournalRepository.EntrySnapshot] = []
    @State private var editing: JournalDraft?
    @State private var confirmingDelete = false
    @State private var error: String?
    @State private var missing = false

    var body: some View {
        Group {
            if lock.isLocked {
                JournalGate()
            } else if let entry {
                content(entry)
            } else if missing {
                ContentUnavailableView("Entry not found", systemImage: "doc.questionmark")
            } else {
                ProgressView()
            }
        }
        .navigationTitle(entry?.kindLabel ?? String(localized: "Entry"))
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .accessibilityIdentifier("JournalEntryDetail")
        .toolbar {
            if !lock.isLocked, entry != nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { edit() } label: { Label("Edit", systemImage: "pencil") }
                            .accessibilityIdentifier("EditEntry")
                        Button(role: .destructive) { confirmingDelete = true } label: { Label("Delete", systemImage: "trash") }
                            .accessibilityIdentifier("DeleteEntry")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Entry actions")
                    .accessibilityIdentifier("EntryActions")
                }
            }
        }
        .confirmationDialog("Delete this entry?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete entry", role: .destructive) { delete() }
                .accessibilityIdentifier("ConfirmDeleteEntry")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the entry from this device. Other versions of the same day are kept.")
        }
        .sheet(item: $editing) { draft in JournalEditor(draft: draft) }
        .task { load() }
        .onChange(of: repository.revision) { _, _ in load() }
        .onChange(of: lock.isLocked) { _, locked in if !locked { load() } }
    }

    private func content(_ entry: JournalRepository.EntrySnapshot) -> some View {
        List {
            Section {
                JournalStorageWarning()
                if let error {
                    Text(error).foregroundStyle(.red).accessibilityIdentifier("JournalDetailError")
                }
                LabeledContent("Date", value: entry.date.formatted(date: .long, time: .shortened))
                LabeledContent("Day", value: entry.day.key)
                if let mood = Mood(stored: entry.mood) {
                    LabeledContent("Mood") { JournalMoodBadge(mood: mood) }
                }
                if let updated = entry.updatedAt {
                    LabeledContent("Edited", value: updated.formatted(date: .abbreviated, time: .shortened))
                }
            }
            if !entry.prompt.isEmpty {
                Section("Prompt") {
                    Text(entry.prompt).font(.body).foregroundStyle(.primary)
                }
            }
            Section {
                Text(entry.text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("JournalEntryText")
            }
            if let intention = entry.nextIntention, !intention.isEmpty {
                Section("Intention for next week") { Text(intention).font(.body) }
            }
            if let practiceID = entry.practiceID {
                Section {
                    NavigationLink {
                        PracticeDetailView(practiceID: practiceID)
                    } label: {
                        Label("View this practice", systemImage: "text.quote")
                    }
                    .accessibilityIdentifier("ViewSourcePractice")
                }
            }
            if !variants.isEmpty {
                Section {
                    ForEach(variants) { variant in
                        if let id = variant.recordID {
                            NavigationLink { JournalEntryDetailView(recordID: id) } label: { JournalEntryRow(entry: variant) }
                        } else {
                            JournalEntryRow(entry: variant)
                        }
                    }
                } header: {
                    Text("Other answers for this day")
                } footer: {
                    Text("Both versions are kept. Open one to edit or delete it explicitly.")
                }
            }
        }
    }

    private func load() {
        guard !lock.isLocked else { return }
        do {
            guard let value = try repository.entry(id: recordID) else { entry = nil; missing = true; return }
            entry = value
            missing = false
            if value.kind == JournalEntry.kindQuestion, let selection = try repository.answer(for: value.day) {
                variants = selection.all.filter { $0.recordID != recordID }
            } else {
                variants = []
            }
        } catch {
            self.error = String(localized: "Could not load this entry. Try again.")
        }
    }

    private func edit() {
        guard let entry else { return }
        do {
            if let draft = try existingEditingDraft(for: recordID, in: drafts) { editing = draft; return }
            guard let draft = JournalDraft.editing(entry) else {
                error = String(localized: "This entry has no identity yet and cannot be edited.")
                return
            }
            editing = draft
        } catch {
            self.error = String(localized: "Could not read the saved edit. Your entry is unchanged. Try again.")
        }
    }

    private func delete() {
        do {
            try repository.deleteEntry(id: recordID)
        } catch {
            self.error = String(localized: "Could not delete this entry. It is still here. Try again.")
            return
        }
        do {
            if let draft = try existingEditingDraft(for: recordID, in: drafts) {
                try drafts.delete(id: draft.id)
            }
        } catch {
            self.error = String(localized: "Entry deleted. Its unsaved edit is still here; retry cleanup from Drafts.")
            return
        }
        dismiss()
    }
}

// MARK: - Retro detail

struct JournalRetroDetailView: View {
    let recordID: UUID
    @Environment(JournalRepository.self) private var repository
    @Environment(JournalDraftStore.self) private var drafts
    @Environment(JournalLock.self) private var lock
    @Environment(\.dismiss) private var dismiss
    @State private var retro: JournalRepository.RetroSnapshot?
    @State private var variants: [JournalRepository.RetroSnapshot] = []
    @State private var editing: JournalDraft?
    @State private var confirmingDelete = false
    @State private var error: String?
    @State private var missing = false

    var body: some View {
        Group {
            if lock.isLocked {
                JournalGate()
            } else if let retro {
                content(retro)
            } else if missing {
                ContentUnavailableView("Retrospective not found", systemImage: "doc.questionmark")
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Retrospective")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .accessibilityIdentifier("JournalRetroDetail")
        .toolbar {
            if !lock.isLocked, retro != nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { edit() } label: { Label("Edit", systemImage: "pencil") }
                            .accessibilityIdentifier("EditRetro")
                        Button(role: .destructive) { confirmingDelete = true } label: { Label("Delete", systemImage: "trash") }
                            .accessibilityIdentifier("DeleteRetro")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Retrospective actions")
                    .accessibilityIdentifier("RetroActions")
                }
            }
        }
        .confirmationDialog("Delete this retrospective?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete retrospective", role: .destructive) { delete() }
                .accessibilityIdentifier("ConfirmDeleteRetro")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the retrospective from this device. Other versions of the same day are kept.")
        }
        .sheet(item: $editing) { draft in JournalEditor(draft: draft) }
        .task { load() }
        .onChange(of: repository.revision) { _, _ in load() }
        .onChange(of: lock.isLocked) { _, locked in if !locked { load() } }
    }

    private func content(_ retro: JournalRepository.RetroSnapshot) -> some View {
        List {
            Section {
                JournalStorageWarning()
                if let error {
                    Text(error).foregroundStyle(.red).accessibilityIdentifier("JournalDetailError")
                }
                LabeledContent("Date", value: retro.date.formatted(date: .long, time: .shortened))
                LabeledContent("Day", value: retro.day.key)
                if let mood = Mood(stored: retro.mood) {
                    LabeledContent("Mood") { JournalMoodBadge(mood: mood) }
                }
                if let updated = retro.updatedAt {
                    LabeledContent("Edited", value: updated.formatted(date: .abbreviated, time: .shortened))
                }
            }
            if let prompt = retro.promptSnapshot, !prompt.isEmpty {
                Section("Question that day") { Text(prompt).font(.body) }
            }
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    RetroFieldText("What went well?", systemImage: "checkmark.circle", text: retro.wentWell)
                    RetroFieldText("What can improve?", systemImage: "arrow.up.circle", text: retro.improve)
                    RetroFieldText("Ideas & tomorrow", systemImage: "sunrise", text: retro.tomorrow)
                    RetroFieldText("Intention carried into the next day", systemImage: "arrow.turn.down.right", text: retro.tomorrowIntention ?? "")
                }
                .textSelection(.enabled)
                .accessibilityIdentifier("JournalRetroText")
            }
            if let practiceID = retro.practiceID {
                Section {
                    NavigationLink {
                        PracticeDetailView(practiceID: practiceID)
                    } label: {
                        Label("View this practice", systemImage: "text.quote")
                    }
                    .accessibilityIdentifier("ViewSourcePractice")
                }
            }
            if !variants.isEmpty {
                Section {
                    ForEach(variants) { variant in
                        if let id = variant.recordID {
                            NavigationLink { JournalRetroDetailView(recordID: id) } label: { JournalRetroRow(retro: variant) }
                        } else {
                            JournalRetroRow(retro: variant)
                        }
                    }
                } header: {
                    Text("Other retrospectives for this day")
                } footer: {
                    Text("Both versions are kept. Open one to edit or delete it explicitly.")
                }
            }
        }
    }

    private func load() {
        guard !lock.isLocked else { return }
        do {
            guard let value = try repository.retro(id: recordID) else { retro = nil; missing = true; return }
            retro = value
            missing = false
            variants = try repository.retro(for: value.day)?.all.filter { $0.recordID != recordID } ?? []
        } catch {
            self.error = String(localized: "Could not load this retrospective. Try again.")
        }
    }

    private func edit() {
        guard let retro else { return }
        do {
            if let draft = try existingEditingDraft(for: recordID, in: drafts) { editing = draft; return }
            guard let draft = JournalDraft.editing(retro) else {
                error = String(localized: "This entry has no identity yet and cannot be edited.")
                return
            }
            editing = draft
        } catch {
            self.error = String(localized: "Could not read the saved edit. Your retrospective is unchanged. Try again.")
        }
    }

    private func delete() {
        do {
            try repository.deleteRetro(id: recordID)
        } catch {
            self.error = String(localized: "Could not delete this retrospective. It is still here. Try again.")
            return
        }
        do {
            if let draft = try existingEditingDraft(for: recordID, in: drafts) {
                try drafts.delete(id: draft.id)
            }
        } catch {
            self.error = String(localized: "Retrospective deleted. Its unsaved edit is still here; retry cleanup from Drafts.")
            return
        }
        dismiss()
    }
}

// MARK: - Same-day conflict chooser

/// Lists every record that claims one day so the person picks which to
/// open. Nothing is merged or discarded on their behalf.
struct JournalDayVariantsView: View {
    enum Records {
        case answers([JournalRepository.EntrySnapshot])
        case retros([JournalRepository.RetroSnapshot])
    }
    let day: CivilDay
    let records: Records
    @Environment(JournalLock.self) private var lock

    var body: some View {
        Group {
            if lock.isLocked {
                JournalGate()
            } else {
                List {
                    Section {
                        switch records {
                        case .answers(let entries):
                            ForEach(entries) { entry in
                                if let id = entry.recordID {
                                    NavigationLink { JournalEntryDetailView(recordID: id) } label: { JournalEntryRow(entry: entry) }
                                } else {
                                    JournalEntryRow(entry: entry)
                                }
                            }
                        case .retros(let retros):
                            ForEach(retros) { retro in
                                if let id = retro.recordID {
                                    NavigationLink { JournalRetroDetailView(recordID: id) } label: { JournalRetroRow(retro: retro) }
                                } else {
                                    JournalRetroRow(retro: retro)
                                }
                            }
                        }
                    } footer: {
                        Text("More than one version was written for \(day.key), usually from two devices. All are kept; open one to edit or delete it.")
                    }
                }
            }
        }
        .navigationTitle("Versions for this day")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("JournalDayVariants")
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
                        Section { Text(error).foregroundStyle(.red).accessibilityIdentifier("JournalRecoveryError") }
                    }
                    if unreadableCount > 0 {
                        Section {
                            Text("\(unreadableCount) draft file(s) could not be read. They were left untouched on this device.")
                                .foregroundStyle(.orange)
                                .accessibilityIdentifier("JournalRecoveryUnreadable")
                        }
                    }
                    if recoverable.isEmpty {
                        Text("No unsaved drafts.").foregroundStyle(.secondary)
                            .accessibilityIdentifier("JournalRecoveryEmpty")
                    } else {
                        Section {
                            ForEach(recoverable) { draft in
                                Button { opening = draft } label: { recoveryRow(draft) }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("RecoverDraft.\(draft.id.uuidString)")
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) { discarding = draft } label: { Label("Discard", systemImage: "trash") }
                                    }
                                    .contextMenu {
                                        Button { opening = draft } label: { Label("Open", systemImage: "pencil") }
                                        Button(role: .destructive) { discarding = draft } label: { Label("Discard", systemImage: "trash") }
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
        .onChange(of: lock.isLocked) { _, locked in if locked { recoverable = []; unreadableCount = 0 } else { load() } }
    }

    private func recoveryRow(_ draft: JournalDraft) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(draft.kindLabel)
                Text(draft.context.civilDay.key)
                if draft.context.editingRecordID != nil { Text("editing") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let prompt = draft.context.promptSnapshot, !prompt.isEmpty {
                Text(prompt).font(.subheadline.weight(.medium)).lineLimit(2)
            }
            Text(draft.recoveryPreview).font(.body).foregroundStyle(.primary).lineLimit(2)
            Text("Last edited \(draft.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2).foregroundStyle(.tertiary)
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
        do { try drafts.delete(id: draft.id); discarding = nil; load() }
        catch { self.error = String(localized: "Could not discard this draft. It is still here. Try again.") }
    }
}
