//
//  JournalView.swift
//  Think
//

import SwiftUI
import SwiftData

struct JournalView: View {
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]

    @State private var selectedKind = JournalEntry.kindNote
    @State private var composingNote = false

    private var filtered: [JournalEntry] {
        entries.filter { $0.kind == selectedKind }
    }

    var body: some View {
        List {
            Section {
                Picker("Entries", selection: $selectedKind) {
                    Text("Notes").tag(JournalEntry.kindNote)
                    Text("Daily questions").tag(JournalEntry.kindQuestion)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if filtered.isEmpty {
                Text(selectedKind == JournalEntry.kindNote
                     ? "Write anything on your mind. Tap + to start."
                     : "Your answers to the daily question will appear here.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filtered) { entry in
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
            }
        }
        .navigationTitle("Journal")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    composingNote = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New note")
            }
        }
        .sheet(isPresented: $composingNote) {
            NewNoteSheet()
        }
    }
}

private struct NewNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ProgressStore.self) private var progress

    @State private var text = ""

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding(8)
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
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(JournalEntry(prompt: "", text: trimmed, kind: JournalEntry.kindNote))
        progress.markTodayComplete()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        JournalView()
    }
    .environment(ProgressStore())
    .modelContainer(for: JournalEntry.self, inMemory: true)
}
