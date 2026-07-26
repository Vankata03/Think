//
//  JournalView.swift
//  Think
//

import SwiftUI
import SwiftData

struct JournalView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case notes = "Notes"
        case questions = "Questions"
        case focus = "Focus"
        case retros = "Retros"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .notes: String(localized: "Notes")
            case .questions: String(localized: "Questions")
            case .focus: String(localized: "Focus")
            case .retros: String(localized: "Retros")
            }
        }

        var entryKind: String? {
            switch self {
            case .notes: JournalEntry.kindNote
            case .questions: JournalEntry.kindQuestion
            case .focus: JournalEntry.kindFocus
            case .retros: nil
            }
        }

        var emptyMessage: String {
            switch self {
            case .notes:
                String(localized: "Write anything on your mind. Tap + to start.")
            case .questions:
                String(localized: "Your answers to the daily question will appear here.")
            case .focus:
                String(localized: "Start a focus session with an intention and your closing notes will appear here.")
            case .retros:
                String(localized: "Close each day with two honest minutes. Your evening retrospectives will appear here.")
            }
        }
    }

    @Environment(JournalLock.self) private var lock

    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @Query(sort: \DailyRetro.date, order: .reverse) private var retros: [DailyRetro]

    @State private var section = Section.notes
    @State private var composingNote = false
    @State private var composingRetro = false
    @State private var authenticating = false

    private var filtered: [JournalEntry] {
        guard let kind = section.entryKind else { return [] }
        return entries.filter { $0.kind == kind }
    }

    var body: some View {
        Group {
            if lock.isLocked {
                lockGate
            } else {
                entryList
            }
        }
        .navigationTitle("Journal")
        .accessibilityIdentifier("JournalView")
        .task {
            // Ask straight away: the gate's Unlock button is the retry
            // path, not the first step.
            await unlock()
        }
    }

    /// Deliberately holds no entry text — not even a count — so nothing
    /// private renders behind a failed authentication or in the app
    /// switcher snapshot.
    private var lockGate: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
            Text("Your journal is locked")
                .font(.headline)
            Text("Unlock to read your notes, answers, and retrospectives.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await unlock() }
            } label: {
                Text("Unlock")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(authenticating)
            .accessibilityIdentifier("UnlockJournal")
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("JournalLocked")
    }

    private var entryList: some View {
        List {
            SwiftUI.Section {
                Picker("Entries", selection: $section) {
                    ForEach(Section.allCases) { section in
                        Text(section.label).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            switch section {
            case .notes, .questions, .focus:
                if filtered.isEmpty {
                    Text(section.emptyMessage)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filtered) { entry in
                        entryRow(entry)
                    }
                }
            case .retros:
                if retros.isEmpty {
                    Text(section.emptyMessage)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(retros) { retro in
                        retroRow(retro)
                    }
                }
            }
        }
        .toolbar {
            // No + under Focus: a focus note is written when a session
            // ends, never composed from here.
            if section != .focus {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if section == .retros {
                            composingRetro = true
                        } else {
                            composingNote = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(section == .retros
                                        ? String(localized: "New retrospective")
                                        : String(localized: "New note"))
                    .accessibilityIdentifier("NewNote")
                }
            }
        }
        .sheet(isPresented: $composingNote) {
            NewNoteSheet()
        }
        .sheet(isPresented: $composingRetro) {
            RetroSheet()
        }
    }

    private func unlock() async {
        guard lock.isLocked, !authenticating else { return }
        authenticating = true
        await lock.authenticate()
        authenticating = false
    }

    private func entryRow(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                moodBadge(Mood(stored: entry.mood))
            }
            if !entry.prompt.isEmpty {
                Text(entry.prompt)
                    .font(.subheadline.weight(.medium))
            }
            Text(entry.text)
                .font(.subheadline)
                .foregroundStyle(entry.prompt.isEmpty ? .primary : .secondary)
        }
        .padding(.vertical, 4)
    }

    private func retroRow(_ retro: DailyRetro) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(retro.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                moodBadge(Mood(stored: retro.mood))
            }
            retroSection("Went well", systemImage: "checkmark.circle", text: retro.wentWell)
            retroSection("Improve", systemImage: "arrow.up.circle", text: retro.improve)
            retroSection("Tomorrow", systemImage: "sunrise", text: retro.tomorrow)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func moodBadge(_ mood: Mood?) -> some View {
        if let mood {
            Label(mood.label, systemImage: mood.systemImage)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel(mood.label)
        }
    }

    @ViewBuilder
    private func retroSection(_ title: LocalizedStringKey, systemImage: String, text: String) -> some View {
        if !text.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(text)
                    .font(.subheadline)
            }
        }
    }
}

private struct NewNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haptics) private var haptics
    @Environment(\.modelContext) private var modelContext
    @Environment(ProgressStore.self) private var progress

    @State private var text = ""
    @State private var mood: Mood?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Capture the thought while it is still clear.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                MoodPicker(selection: $mood)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(.primary)
                        .padding(12)
                        .accessibilityIdentifier("NewNoteInput")

                    if text.isEmpty {
                        Text("Start writing...")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 260)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.separator.opacity(0.6), lineWidth: 1)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("New note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("SaveNewNote")
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("NewNoteSheet")
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(
            JournalEntry(prompt: "", text: trimmed, kind: JournalEntry.kindNote, mood: mood)
        )
        progress.markTodayComplete()
        haptics.play(.success)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        JournalView()
    }
    .environment(ProgressStore())
    .environment(JournalLock(authenticator: UnavailableJournalAuthenticator()))
    .modelContainer(for: [JournalEntry.self, DailyRetro.self], inMemory: true)
}
