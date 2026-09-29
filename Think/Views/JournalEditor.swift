import SwiftUI

/// The one editor for everything a person writes (`design/journal.md`
/// section 8): a new note, the day's answer, a retro, a weekly review, and
/// Edit on any stored record. Drafts autosave on every change; saving goes
/// through `JournalRepository.save(_:)`. Recovery remains bound to the
/// draft's original context.
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
    @FocusState private var focus: Field?
    @ThinkSpacing.Scaled(ThinkSpacing.l) private var blockGap
    @ThinkSpacing.Scaled(ThinkSpacing.xs) private var labelGap
    @ThinkSpacing.Scaled(ThinkSpacing.m) private var edgeGap

    init(draft: JournalDraft, notice: String? = nil) {
        _error = State(initialValue: notice)
        _draft = State(initialValue: draft)
        initial = draft
        _requiresUnlock = State(initialValue: draft.containsPrivateContent)
    }
    private var protected: Bool { requiresUnlock && lock.isLocked }
    private var isNew: Bool { draft.context.editingRecordID == nil }
    private var canSave: Bool { committed || draft.hasSomethingToSave }
    /// Swiping the sheet away is blocked only while it holds writing that
    /// has not been saved; Cancel stays available and keeps the draft.
    private var holdsUnsavedWriting: Bool { !finished && draft != initial && draft.containsPrivateContent }
    private var title: String {
        draft.kind == .note && isNew ? String(localized: "New note") : draft.kind.name
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
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { if persist() && cleanUpCommitted() { dismiss() } }
                        .accessibilityIdentifier("CancelJournalEditor")
                }
                if !protected {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .confirm) { save() }.disabled(!canSave)
                            .accessibilityIdentifier(draft.kind == .note ? "SaveNewNote" : "SaveJournalEntry")
                    }
                }
            }
        }
        .presentationDetents([.large])
        .onChange(of: draft) { _, _ in persist() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { persist(); if draft.containsPrivateContent { requiresUnlock = true } }
        }
        .interactiveDismissDisabled(holdsUnsavedWriting)
    }

    private var editor: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: blockGap) {
                    JournalStorageWarning()
                    if let error {
                        Text(error).font(.think(.secondary)).foregroundStyle(ThinkColor.destructive)
                            .accessibilityIdentifier("JournalSaveError")
                    }
                    Text(dayLine).font(.think(.caption)).foregroundStyle(ThinkColor.secondaryLabel)
                    if let prompt {
                        Text(prompt).font(.think(.question))
                            .foregroundStyle(draft.kind == .focus ? ThinkColor.secondaryLabel : ThinkColor.label)
                    }
                    if draft.kind != .weeklyReview {
                        JournalHeaderChips(mood: $draft.mood, themes: $draft.themes)
                    }
                    writingArea.disabled(committed)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .scenePadding(.horizontal)
                .padding(.vertical, edgeGap)
            }
            .scrollDismissesKeyboard(.interactively)
            // A growing field does not carry its caret above the keyboard by
            // itself (`JRN-4`). Typing at the end keeps the field's end in view;
            // an edit mid-text leaves the scroll where the person put it.
            .onChange(of: draft) { old, new in
                guard let focus, new.text(focus).hasPrefix(old.text(focus)), new.text(focus) != old.text(focus) else { return }
                proxy.scrollTo(focus, anchor: .bottom)
            }
        }
        .onAppear { if isNew && draft.kind != .retro { focus = .text } }
        .accessibilityIdentifier(draft.kind == .note ? "NewNoteSheet" : "JournalEditor")
    }

    /// The civil day in full; a new note adds the time it was started.
    private var dayLine: String {
        let zone = draft.context.civilDay.timeZone
        var dayStyle = Date.FormatStyle.dateTime.weekday(.wide).day().month(.wide)
        dayStyle.timeZone = zone
        let day = draft.context.civilDay.start.formatted(dayStyle)
        guard draft.kind == .note && isNew else { return day }
        var timeStyle = Date.FormatStyle(date: .omitted, time: .shortened)
        timeStyle.timeZone = zone
        return "\(day) · \(draft.createdAt.formatted(timeStyle))"
    }

    /// The question for an answer; the session intention for a focus note,
    /// which cannot be edited. Notes and retros have none.
    private var prompt: String? {
        let value: String?
        switch draft.kind {
        case .answer: value = draft.context.promptSnapshot
        case .focus: value = draft.fields["intention"] ?? draft.context.promptSnapshot
        case .note, .retro, .weeklyReview: value = nil
        }
        return value.flatMap { $0.isEmpty ? nil : $0 }
    }

    @ViewBuilder
    private var writingArea: some View {
        if draft.kind == .retro {
            retroField("What went well?", placeholder: "One thing you did right today…", field: .wentWell)
            retroField("What can improve?", placeholder: "One thing to do differently…", field: .improve)
            retroField("Ideas & tomorrow", placeholder: "Thoughts to keep, tasks for tomorrow…", field: .tomorrow)
            retroField("Intention for tomorrow", placeholder: "One intention to carry into tomorrow", field: .intention)
                .accessibilityIdentifier("TomorrowIntentionInput")
        } else {
            TextField("Start writing", text: binding(.text), axis: .vertical)
                .font(.think(.body))
                .lineLimit(6...)
                .focused($focus, equals: .text)
                .id(Field.text)
                .accessibilityIdentifier(draft.kind == .note ? "NewNoteInput" : "JournalEntryInput")
            if draft.kind == .weeklyReview {
                TextField("Next week (optional)", text: binding(.intention), axis: .vertical)
                    .font(.think(.body))
                    .focused($focus, equals: .intention)
                    .id(Field.intention)
            }
        }
    }

    private func retroField(_ title: LocalizedStringKey, placeholder: LocalizedStringKey, field: Field) -> some View {
        VStack(alignment: .leading, spacing: labelGap) {
            Text(title).font(.think(.secondary).weight(.semibold)).foregroundStyle(ThinkColor.secondaryLabel)
            TextField(placeholder, text: binding(field), axis: .vertical)
                .font(.think(.body))
                .lineLimit(2...)
                .focused($focus, equals: field)
        }
        .id(field)
    }

    private func binding(_ field: Field) -> Binding<String> {
        Binding(get: { draft.text(field) }, set: { draft.setText($0, for: field) })
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
    /// After a commit whose draft cleanup failed, Cancel retries the delete so
    /// the saved text cannot linger as an "unsaved" ghost.
    private func cleanUpCommitted() -> Bool {
        guard committed && !finished else { return true }
        do { try drafts.delete(id: draft.id); finished = true; return true } catch {
            self.error = String(localized: "Entry saved. Could not remove its draft. Tap Save to retry cleanup.")
            return false
        }
    }
    private func save() {
        guard !protected else { return }
        do {
            if !committed {
                try drafts.save(draft)
                let receipt = try repository.save(draft)
                committed = true
                if let receipt, isNew {
                    switch draft.kind {
                    case .answer: progress.recordActivity(.answer, id: receipt.recordID.uuidString, at: draft.createdAt)
                    case .retro: progress.recordActivity(.retro, id: receipt.recordID.uuidString, at: draft.createdAt)
                    case .note: progress.recordActivity(.note, id: receipt.recordID.uuidString, at: draft.createdAt)
                    case .focus, .weeklyReview: break
                    }
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

extension JournalEditor {
    /// The writing fields, one per text the draft holds. A retro's three
    /// answers are stored in `JournalDraft.fields` under the raw value.
    enum Field: String, Hashable {
        case text, wentWell, improve, tomorrow, intention
    }
}

private extension JournalDraft {
    func text(_ field: JournalEditor.Field) -> String {
        switch field {
        case .text: text
        case .wentWell, .improve, .tomorrow: fields[field.rawValue] ?? ""
        case .intention: tomorrowIntention ?? ""
        }
    }
    mutating func setText(_ value: String, for field: JournalEditor.Field) {
        switch field {
        case .text: text = value
        case .wentWell, .improve, .tomorrow: fields[field.rawValue] = value
        case .intention: tomorrowIntention = value.isEmpty ? nil : value
        }
    }
}

extension JournalDraft.Kind {
    /// The kind's name, used as the editor title when editing.
    var name: String {
        switch self {
        case .answer: String(localized: "Answer")
        case .note: String(localized: "Note")
        case .retro: String(localized: "Retro")
        case .focus: String(localized: "Focus note")
        case .weeklyReview: String(localized: "Weekly review")
        }
    }
}

// MARK: - Header chips

/// The Mood and Theme menu chips, side by side, stacked when they do not
/// fit. Nothing scrolls horizontally, so nothing clips (`JRN-3`).
struct JournalHeaderChips: View {
    @Binding var mood: String?
    @Binding var themes: ThemeSelection
    @ThinkSpacing.Scaled(ThinkSpacing.s) private var gap

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: gap) { moodChip; themeChip }
            VStack(alignment: .leading, spacing: gap) { moodChip; themeChip }
        }
    }

    private var selectedMood: Mood? { Mood(stored: mood) }

    private var moodChip: some View {
        Menu {
            Picker("Mood", selection: Binding(get: { selectedMood }, set: { mood = $0?.rawValue })) {
                Text("No mood").tag(Mood?.none)
                ForEach(Mood.allCases) { mood in
                    Label(mood.label, systemImage: mood.systemImage).tag(Optional(mood))
                }
            }
        } label: {
            Label(selectedMood?.label ?? String(localized: "Mood"), systemImage: selectedMood?.systemImage ?? ThinkSymbol.mood)
                .foregroundStyle(selectedMood == nil ? ThinkColor.secondaryLabel : ThinkColor.label)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(.secondary)
        .accessibilityLabel("Mood")
        .accessibilityValue(selectedMood?.label ?? String(localized: "No mood"))
        .accessibilityIdentifier("MoodChip")
    }

    private var themeChip: some View {
        Menu {
            Section("Up to two") {
                ForEach(Theme.allCases) { theme in
                    Toggle(theme.label, isOn: Binding(get: { themes.contains(theme) }, set: { _ in themes.toggle(theme) }))
                }
            }
        } label: {
            Text(themes.isEmpty ? String(localized: "Theme") : themeNames)
                .foregroundStyle(themes.isEmpty ? ThinkColor.secondaryLabel : ThinkColor.label)
        }
        // The menu stays open so a second theme is one more tap.
        .menuActionDismissBehavior(.disabled)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(.secondary)
        .accessibilityLabel("Theme")
        .accessibilityValue(themes.isEmpty ? String(localized: "No theme") : themeNames)
        .accessibilityIdentifier("ThemeChip")
    }

    private var themeNames: String { themes.themes.map(\.label).joined(separator: " · ") }
}

#Preview("Chips") {
    @Previewable @State var mood: String? = Mood.steady.rawValue
    @Previewable @State var themes = ThemeSelection(primary: .work, secondary: .people)
    VStack(alignment: .leading, spacing: ThinkSpacing.xl) {
        JournalHeaderChips(mood: $mood, themes: $themes)
        JournalHeaderChips(mood: .constant(nil), themes: .constant(ThemeSelection()))
    }
    .padding()
}

#Preview("Chips, AX3") {
    @Previewable @State var mood: String? = Mood.steady.rawValue
    @Previewable @State var themes = ThemeSelection(primary: .learning, secondary: .making)
    JournalHeaderChips(mood: $mood, themes: $themes)
        .padding()
        .dynamicTypeSize(.accessibility3)
}
