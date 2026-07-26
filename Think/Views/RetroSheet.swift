//
//  RetroSheet.swift
//  Think
//

import SwiftUI
import SwiftData

/// Three-field evening retrospective. Edits today's retro in place if
/// one already exists, so reopening the sheet never duplicates.
struct RetroSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haptics) private var haptics
    @Environment(\.modelContext) private var modelContext
    @Environment(ProgressStore.self) private var progress
    @Query(sort: \DailyRetro.date, order: .reverse) private var retros: [DailyRetro]

    @State private var wentWell = ""
    @State private var improve = ""
    @State private var tomorrow = ""
    @State private var mood: Mood?
    @State private var loaded = false

    private var todaysRetro: DailyRetro? {
        retros.first { Calendar.current.isDateInToday($0.date) }
    }

    private var canSave: Bool {
        ![wentWell, improve, tomorrow]
            .allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Two honest minutes. Skip anything that doesn't apply.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    MoodPicker(selection: $mood)

                    retroField(
                        "What went well?",
                        systemImage: "checkmark.circle",
                        placeholder: "One thing you did right today…",
                        text: $wentWell
                    )
                    retroField(
                        "What can improve?",
                        systemImage: "arrow.up.circle",
                        placeholder: "One thing to do differently…",
                        text: $improve
                    )
                    retroField(
                        "Ideas & tomorrow",
                        systemImage: "sunrise",
                        placeholder: "Thoughts to keep, tasks for tomorrow…",
                        text: $tomorrow
                    )
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .navigationTitle("Retrospective")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    private func retroField(
        _ title: LocalizedStringKey,
        systemImage: String,
        placeholder: LocalizedStringKey,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(title)
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.accentColor)
            }
            .font(.subheadline.weight(.semibold))

            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.separator.opacity(0.6), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func loadExisting() {
        guard !loaded else { return }
        loaded = true
        if let retro = todaysRetro {
            wentWell = retro.wentWell
            improve = retro.improve
            tomorrow = retro.tomorrow
            mood = Mood(stored: retro.mood)
        }
    }

    private func save() {
        let well = wentWell.trimmingCharacters(in: .whitespacesAndNewlines)
        let better = improve.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = tomorrow.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !(well.isEmpty && better.isEmpty && next.isEmpty) else { return }

        if let retro = todaysRetro {
            retro.wentWell = well
            retro.improve = better
            retro.tomorrow = next
            retro.mood = mood?.rawValue
        } else {
            modelContext.insert(
                DailyRetro(wentWell: well, improve: better, tomorrow: next, mood: mood)
            )
        }
        progress.markTodayComplete()
        haptics.play(.success)
        dismiss()
    }
}

#Preview {
    RetroSheet()
        .environment(ProgressStore())
        .modelContainer(for: [JournalEntry.self, DailyRetro.self], inMemory: true)
}
