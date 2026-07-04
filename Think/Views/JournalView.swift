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
    .modelContainer(for: JournalEntry.self, inMemory: true)
}
