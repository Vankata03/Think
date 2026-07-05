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
        case retros = "Retros"

        var id: String { rawValue }
    }

    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @Query(sort: \DailyRetro.date, order: .reverse) private var retros: [DailyRetro]

    @State private var section = Section.notes
    @State private var composingNote = false
    @State private var composingRetro = false

    private var filtered: [JournalEntry] {
        let kind = section == .notes ? JournalEntry.kindNote : JournalEntry.kindQuestion
        return entries.filter { $0.kind == kind }
    }

    var body: some View {
        List {
            SwiftUI.Section {
                Picker("Entries", selection: $section) {
                    ForEach(Section.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            switch section {
            case .notes, .questions:
                if filtered.isEmpty {
                    Text(section == .notes
                         ? "Write anything on your mind. Tap + to start."
                         : "Your answers to the daily question will appear here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filtered) { entry in
                        entryRow(entry)
                    }
                }
            case .retros:
                if retros.isEmpty {
                    Text("Close each day with two honest minutes. Your evening retrospectives will appear here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(retros) { retro in
                        retroRow(retro)
                    }
                }
            }
        }
        .navigationTitle("Journal")
        .toolbar {
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
                .accessibilityLabel(section == .retros ? "New retrospective" : "New note")
            }
        }
        .sheet(isPresented: $composingNote) {
            NewNoteSheet()
        }
        .sheet(isPresented: $composingRetro) {
            RetroSheet()
        }
    }

    private func entryRow(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
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
            Text(retro.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
            retroSection("Went well", systemImage: "checkmark.circle", text: retro.wentWell)
            retroSection("Improve", systemImage: "arrow.up.circle", text: retro.improve)
            retroSection("Tomorrow", systemImage: "sunrise", text: retro.tomorrow)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func retroSection(_ title: String, systemImage: String, text: String) -> some View {
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

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Capture the thought while it is still clear.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(.primary)
                        .padding(12)

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
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(JournalEntry(prompt: "", text: trimmed, kind: JournalEntry.kindNote))
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
    .modelContainer(for: [JournalEntry.self, DailyRetro.self], inMemory: true)
}
