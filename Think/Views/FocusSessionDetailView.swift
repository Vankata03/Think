import SwiftUI

/// Timing is public progress; intention, outcomes and drafts require the journal gate.
struct FocusSessionDetailView: View {
    let session: FocusSessionRecord
    @Environment(JournalLock.self) private var lock
    @Environment(JournalRepository.self) private var repository
    @Environment(JournalDraftStore.self) private var drafts
    @State private var draft: JournalDraft?
    /// What the fields held right after `load()`: stored metadata, the saved
    /// note, or a recovered draft. Only a real change earns a draft file, so
    /// opening a completed session and leaving never creates a recovery ghost.
    @State private var baseline: JournalDraft?
    @State private var recoveredDraft = false
    @State private var note = ""
    @State private var intention = ""
    @State private var outcome = ""
    @State private var energy = ""
    @State private var loaded = false
    @State private var hasError = false
    @State private var saved = false
    @State private var noteRecordID: UUID?

    var body: some View {
        Form {
            Section {
                LabeledContent("Status", value: session.isCompleted ? String(localized: "Completed") : String(localized: "Partial effort"))
                LabeledContent("Planned duration", value: String(localized: "\(session.durationMinutes) min"))
                if let seconds = session.actualActiveSeconds {
                    LabeledContent("Active effort", value: Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond)))
                } else { Text("Actual duration wasn't recorded for this session.").foregroundStyle(.secondary) }
                Text(session.completedAt, format: .dateTime.year().month().day().hour().minute())
                    .foregroundStyle(.secondary)
            }
            if lock.isLocked {
                Section {
                    Button { Task { if await lock.authenticate() { load() } } } label: {
                        Label("Unlock private reflection", systemImage: "lock")
                    }
                }
            } else {
                if repository.storageWarning != nil {
                    Section { Text("Temporary storage: changes may be lost when the app closes.").foregroundStyle(.orange) }
                }
                Section("Private reflection") {
                    TextField("Intention", text: $intention, axis: .vertical)
                    Picker("Outcome", selection: $outcome) {
                        Text("Not recorded").tag("")
                        Text("Done").tag(FocusOutcome.done.rawValue)
                        Text("Moved forward").tag(FocusOutcome.movedForward.rawValue)
                        Text("Changed direction").tag(FocusOutcome.changedDirection.rawValue)
                    }
                    Picker("Energy", selection: $energy) {
                        Text("Not recorded").tag("")
                        Text("Low").tag(EnergyLevel.low.rawValue)
                        Text("Steady").tag(EnergyLevel.steady.rawValue)
                        Text("High").tag(EnergyLevel.high.rawValue)
                    }
                    TextField("How did it go?", text: $note, axis: .vertical)
                        .lineLimit(3...12).accessibilityIdentifier("FocusNoteInput")
                    Button("Save") { save() }.accessibilityIdentifier("SaveFocusNote")
                    if saved { Label("Saved", systemImage: "checkmark.circle") }
                }
            }
        }
        .navigationTitle("After the session")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if !lock.isLocked { load() } }
        .onChange(of: lock.isLocked) { _, locked in
            if locked { loaded = false; note = ""; intention = ""; outcome = ""; energy = ""; draft = nil; baseline = nil }
            else { load() }
        }
        .onChange(of: note) { persistDraft() }
        .onChange(of: intention) { persistDraft() }
        .onChange(of: outcome) { persistDraft() }
        .onChange(of: energy) { persistDraft() }
        .alert("Could not save", isPresented: $hasError) {
            Button("OK", role: .cancel) { }
        } message: { Text("Your draft is kept when possible. Please try again.") }
    }

    private func load() {
        guard !loaded, !lock.isLocked else { return }
        do {
            let metadata = try repository.sessionMetadata(sessionID: session.id)
            noteRecordID = metadata?.closingNoteRecordID
            let recovered = try drafts.drafts(kind: .focus).first { $0.context.sessionID == session.id && $0.context.editingRecordID == nil }
            recoveredDraft = recovered != nil
            let value = recovered ?? JournalDraft(kind: .focus, context: .init(civilDay: CivilDay(date: session.completedAt), sessionID: session.id))
            intention = recovered?.fields["intention"] ?? metadata?.intention ?? ""
            outcome = recovered?.outcome ?? metadata?.outcome ?? ""
            energy = recovered?.energy ?? metadata?.energy ?? ""
            if let recovered { note = recovered.text }
            else if let id = metadata?.closingNoteRecordID { note = try repository.entry(id: id)?.text ?? "" }
            draft = value
            baseline = composed(from: value)
            loaded = true
        } catch { hasError = true }
    }

    /// The draft as the fields currently read. Empty pickers are stored as
    /// nil so "not recorded" never counts as private content on its own.
    private func composed(from value: JournalDraft) -> JournalDraft {
        var result = value
        result.text = note
        result.fields["intention"] = intention
        result.outcome = outcome.isEmpty ? nil : outcome
        result.energy = energy.isEmpty ? nil : energy
        return result
    }

    private func persistDraft() {
        guard loaded, !lock.isLocked, let draft, let baseline else { return }
        let value = composed(from: draft)
        // `onChange` also fires for the assignments made in `load()`; those
        // match the baseline exactly and must not write anything.
        if value == baseline {
            // A recovered draft that is merely untouched stays on disk; a file
            // written earlier in this visit goes away once the fields revert.
            guard !recoveredDraft else { return }
            do { try drafts.delete(id: draft.id) } catch { hasError = true }
            return
        }
        saved = false
        do { try drafts.save(value); self.draft = value } catch { hasError = true }
    }

    private func save() {
        guard !lock.isLocked, let draft else { return }
        do {
            try drafts.save(composed(from: draft))
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                // The repository updates an existing row of the same identity in
                // place, so editing a saved closing note persists the new text.
                let receipt = try repository.saveFocusNote(text: trimmed, intention: intention,
                    sessionID: session.id, completedAt: session.completedAt, recordID: noteRecordID ?? draft.id)
                noteRecordID = receipt.recordID
            } else if let id = noteRecordID {
                try repository.deleteEntry(id: id)
                noteRecordID = nil
            }
            try repository.upsertSessionMetadata(sessionID: session.id, intention: intention.isEmpty ? nil : intention,
                outcome: FocusOutcome(rawValue: outcome), energy: EnergyLevel(rawValue: energy),
                closingNoteRecordID: noteRecordID, completedAt: session.completedAt)
            try drafts.delete(id: draft.id)
            recoveredDraft = false
            baseline = composed(from: draft)
            saved = true
        } catch { hasError = true }
    }
}
