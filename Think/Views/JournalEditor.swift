import SwiftUI

/// Shared explicit-save composer. Recovery remains bound to its original context.
struct JournalEditor: View {
    @Environment(JournalRepository.self) private var repository
    @Environment(JournalDraftStore.self) private var drafts
    @Environment(JournalLock.self) private var lock
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.haptics) private var haptics
    @State private var draft: JournalDraft
    /// The draft as handed in. An untouched editing draft is never written
    /// to disk, so opening Edit and closing leaves no recovery ghost.
    private let initial: JournalDraft
    @State private var requiresUnlock: Bool
    @State private var error: String?
    @State private var committed = false
    @State private var finished = false
    @State private var touched = false

    init(draft: JournalDraft, notice: String? = nil) {
        _error = State(initialValue: notice)
        _draft = State(initialValue: draft)
        initial = draft
        _requiresUnlock = State(initialValue: draft.containsPrivateContent)
    }
    private var protected: Bool { requiresUnlock && lock.isLocked }
    private var canSave: Bool {
        if committed || recoveringFocusSession { return true }
        let intention = (draft.tomorrowIntention ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (draft.kind == .weeklyReview && !intention.isEmpty)
            || (draft.kind == .retro && (draft.fields.values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                                        || draft.mood != nil || !intention.isEmpty))
            || (recoveringFocusSession && (!(draft.fields["intention"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                           || draft.outcome != nil || draft.energy != nil))
    }
    /// A focus draft written from a session screen carries intention,
    /// outcome and energy alongside the note. Recovering it here must keep
    /// all of them; an Edit of a stored focus entry has only the text.
    private var recoveringFocusSession: Bool {
        draft.kind == .focus && draft.context.editingRecordID == nil && draft.context.sessionID != nil
    }
    private var title: String {
        if draft.context.editingRecordID != nil { return String(localized: "Edit entry") }
        switch draft.kind {
        case .answer: return String(localized: "Question of the day")
        case .retro: return String(localized: "Retrospective")
        case .focus: return String(localized: "After the session")
        case .weeklyReview: return String(localized: "Weekly review")
        case .note: return String(localized: "New note")
        }
    }
    var body: some View {
        NavigationStack {
            Group {
                if protected { JournalGate() }
                else { editor }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { if persist() && cleanUpCommitted() { dismiss() } } }
                if !protected {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }.disabled(!canSave)
                            .accessibilityIdentifier(draft.kind == .note ? "SaveNewNote" : "SaveJournalEntry")
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .onChange(of: draft) { _, _ in persist() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { persist(); if draft.containsPrivateContent { requiresUnlock = true } }
        }
        .interactiveDismissDisabled(!finished && draft.containsPrivateContent)
    }
    private var editor: some View {
        Form {
            Section {
                JournalStorageWarning()
                Text(draft.context.civilDay.key).font(.caption).foregroundStyle(.secondary)
                if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("JournalSaveError") }
                if let prompt = draft.context.promptSnapshot, !prompt.isEmpty { Text(prompt).font(.headline) }
            }
            Section {
                if draft.kind != .weeklyReview && !recoveringFocusSession {
                    MoodPicker(selection: Binding(get: { Mood(stored: draft.mood) }, set: { draft.mood = $0?.rawValue }))
                }
                if draft.kind == .retro {
                    field("What went well?", key: "wentWell", placeholder: "One thing you did right today…")
                    field("What can improve?", key: "improve", placeholder: "One thing to do differently…")
                    field("Ideas & tomorrow", key: "tomorrow", placeholder: "Thoughts to keep, tasks for tomorrow…")
                    TextField("One intention to carry into tomorrow", text: Binding(get: { draft.tomorrowIntention ?? "" }, set: { draft.tomorrowIntention = $0.isEmpty ? nil : $0 }), axis: .vertical)
                        .accessibilityIdentifier("TomorrowIntentionInput")
                } else {
                    if recoveringFocusSession {
                        TextField("Intention", text: Binding(get: { draft.fields["intention"] ?? "" }, set: { draft.fields["intention"] = $0 }), axis: .vertical)
                        Picker("Outcome", selection: Binding(get: { draft.outcome ?? "" }, set: { draft.outcome = $0.isEmpty ? nil : $0 })) {
                            Text("Not recorded").tag("")
                            Text("Done").tag(FocusOutcome.done.rawValue)
                            Text("Moved forward").tag(FocusOutcome.movedForward.rawValue)
                            Text("Changed direction").tag(FocusOutcome.changedDirection.rawValue)
                        }
                        Picker("Energy", selection: Binding(get: { draft.energy ?? "" }, set: { draft.energy = $0.isEmpty ? nil : $0 })) {
                            Text("Not recorded").tag("")
                            Text("Low").tag(EnergyLevel.low.rawValue)
                            Text("Steady").tag(EnergyLevel.steady.rawValue)
                            Text("High").tag(EnergyLevel.high.rawValue)
                        }
                    }
                    TextField("Start writing...", text: $draft.text, axis: .vertical)
                        .lineLimit(8...20).font(.body).foregroundStyle(.primary)
                        .accessibilityIdentifier(draft.kind == .note ? "NewNoteInput" : "JournalEntryInput")
                    if draft.kind == .weeklyReview {
                        TextField("Next week (optional)", text: Binding(get: { draft.tomorrowIntention ?? "" }, set: { draft.tomorrowIntention = $0.isEmpty ? nil : $0 }), axis: .vertical)
                    }
                }
            }.disabled(committed)
            Section { Text("Drafts stay on this device until you save or discard them.").font(.footnote).foregroundStyle(.secondary) }
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier(draft.kind == .note ? "NewNoteSheet" : "JournalEditor")
    }
    private func field(_ title: LocalizedStringKey, key: String, placeholder: LocalizedStringKey) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.subheadline.weight(.semibold))
            TextField(placeholder, text: Binding(get: { draft.fields[key] ?? "" }, set: { draft.fields[key] = $0 }), axis: .vertical)
                .lineLimit(2...6).font(.body).foregroundStyle(.primary)
        }
    }
    @discardableResult
    private func persist() -> Bool {
        guard !finished && !committed else { return true }
        if draft != initial { touched = true }
        // Editing drafts start full of stored text; only a real change earns a file.
        guard touched || draft.context.editingRecordID == nil else { return true }
        do {
            if draft.containsPrivateContent { try drafts.save(draft) }
            else { try drafts.delete(id: draft.id) }
            return true
        } catch {
            self.error = String(localized: "Could not save this draft. Keep this screen open and try again.")
            return false
        }
    }
    /// After a commit whose draft cleanup failed, Close retries the delete so
    /// the saved text cannot linger as an "unsaved" ghost.
    private func cleanUpCommitted() -> Bool {
        guard committed && !finished else { return true }
        do { try drafts.delete(id: draft.id); finished = true; return true } catch {
            self.error = String(localized: "Entry saved. Could not remove its draft. Tap Save to retry cleanup.")
            return false
        }
    }
    /// Recovered focus drafts write the note under the session's existing
    /// closing-note identity (never a second row) and restore the session's
    /// intention, outcome and energy, including when only those were set.
    private func saveFocusSession() throws -> JournalRepository.SaveReceipt? {
        let sessionID = draft.context.sessionID ?? draft.id.uuidString
        let metadata = try repository.sessionMetadata(sessionID: sessionID)
        let intention = draft.fields["intention"] ?? draft.context.promptSnapshot ?? ""
        let completedAt = metadata?.completedAt ?? draft.createdAt
        var receipt: JournalRepository.SaveReceipt?
        if !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            receipt = try repository.saveFocusNote(text: draft.text, intention: intention, sessionID: sessionID,
                                                   completedAt: completedAt, recordID: metadata?.closingNoteRecordID ?? draft.id)
        } else if let noteID = metadata?.closingNoteRecordID {
            try repository.deleteEntry(id: noteID)
        }
        try repository.upsertSessionMetadata(sessionID: sessionID, intention: intention.isEmpty ? nil : intention,
            outcome: FocusOutcome(rawValue: draft.outcome ?? ""), energy: EnergyLevel(rawValue: draft.energy ?? ""),
            closingNoteRecordID: receipt?.recordID, completedAt: completedAt)
        return receipt
    }
    private func save() {
        guard !protected else { return }
        do {
            if !committed {
                try drafts.save(draft)
                let receipt: JournalRepository.SaveReceipt?
                let mood = Mood(stored: draft.mood)
                if let id = draft.context.editingRecordID {
                    switch draft.kind {
                    case .retro:
                        receipt = try repository.updateRetro(id: id, wentWell: draft.fields["wentWell"] ?? "", improve: draft.fields["improve"] ?? "", tomorrow: draft.fields["tomorrow"] ?? "", mood: mood, tomorrowIntention: draft.tomorrowIntention)
                    case .weeklyReview:
                        receipt = try repository.updateWeeklyReview(id: id, text: draft.text, nextIntention: draft.tomorrowIntention)
                    default:
                        receipt = try repository.updateEntry(id: id, text: draft.text, mood: mood)
                    }
                } else {
                    switch draft.kind {
                    case .answer:
                        receipt = try repository.saveAnswer(text: draft.text, practiceID: draft.context.practiceID, prompt: draft.context.promptSnapshot ?? "", mood: mood, day: draft.context.civilDay, date: draft.createdAt, recordID: draft.id)
                    case .retro:
                        receipt = try repository.saveRetro(wentWell: draft.fields["wentWell"] ?? "", improve: draft.fields["improve"] ?? "", tomorrow: draft.fields["tomorrow"] ?? "", mood: mood, day: draft.context.civilDay, date: draft.createdAt, practiceID: draft.context.practiceID, promptSnapshot: draft.context.promptSnapshot, tomorrowIntention: draft.tomorrowIntention, recordID: draft.id)
                    case .focus:
                        receipt = try saveFocusSession()
                    case .weeklyReview:
                        // The draft's civil day carries the zone the week was captured in.
                        receipt = try repository.saveWeeklyReview(text: draft.text, nextIntention: draft.tomorrowIntention, weekStart: draft.context.civilDay.start, timeZone: draft.context.civilDay.timeZone, recordID: draft.id)
                    case .note:
                        if let practiceID = draft.context.practiceID {
                            receipt = try repository.savePracticeNote(text: draft.text, practiceID: practiceID, prompt: draft.context.promptSnapshot ?? "", mood: mood, day: draft.context.civilDay, recordID: draft.id)
                        } else { receipt = try repository.saveNote(text: draft.text, mood: mood, day: draft.context.civilDay, date: draft.createdAt, recordID: draft.id) }
                    }
                }
                committed = true
                if let receipt, draft.context.editingRecordID == nil && draft.kind != .focus && draft.kind != .weeklyReview {
                    let kind: PracticeActivityKind = draft.kind == .answer ? .answer : (draft.kind == .retro ? .retro : .note)
                    progress.recordActivity(kind, id: receipt.recordID.uuidString, at: draft.createdAt)
                }
            }
            try drafts.delete(id: draft.id)
            finished = true
            haptics.play(.success)
            dismiss()
        } catch {
            self.error = committed
                ? String(localized: "Entry saved. Could not remove its draft. Tap Save to retry cleanup.")
                : String(localized: "Could not save. Your writing is still here. Try again.")
        }
    }
}
