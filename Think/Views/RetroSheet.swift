//
//  RetroSheet.swift
//  Think
//

import SwiftUI

/// Evening retrospective entry point. Resolves today's context once —
/// captured civil day, practice, prompt — then hands a bound draft to the
/// shared editor. An existing retro is edited in place; a durable draft is
/// resumed; a blank one is captured without unlocking. The optional
/// "intention to carry" is its own field and is never merged into the
/// three narrative answers.
struct RetroSheet: View {
    @Environment(JournalRepository.self) private var repository
    @Environment(JournalDraftStore.self) private var drafts
    @Environment(JournalLock.self) private var lock
    @Environment(\.dismiss) private var dismiss
    @State private var draft: JournalDraft?
    @State private var conflicts: [JournalRepository.RetroSnapshot] = []
    @State private var error: String?

    var body: some View {
        Group {
            if let draft {
                JournalEditor(draft: draft, notice: error)
            } else if lock.isLocked {
                NavigationStack {
                    VStack {
                        JournalGate()
                        Button("Write a new retrospective") { beginBlank() }
                            .buttonStyle(.bordered)
                            .padding()
                            .accessibilityIdentifier("WriteBlankRetro")
                    }
                    .navigationTitle("Retrospective")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                    }
                }
            } else if !conflicts.isEmpty {
                conflictChooser
            } else if let error {
                errorState(error)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard !lock.isLocked else { return }
            resolve()
        }
        .onChange(of: lock.isLocked) { _, locked in
            if !locked { resolve() }
        }
    }

    /// Two devices wrote today's retro offline; the person picks which one
    /// to continue. Nothing is merged, nothing is discarded here.
    private var conflictChooser: some View {
        NavigationStack {
            Group {
                if lock.isLocked {
                    JournalGate()
                } else {
                    List {
                        if let error { Text(error).foregroundStyle(.red) }
                        Section {
                            ForEach(conflicts) { retro in
                                Button {
                                    do {
                                        draft = try existingEditingDraft(for: retro.recordID ?? UUID(), in: drafts) ?? JournalDraft.editing(retro)
                                    } catch {
                                        self.error = String(localized: "Could not read the saved edit. The retrospective is unchanged.")
                                    }
                                } label: {
                                    JournalRetroRow(retro: retro)
                                }
                                .buttonStyle(.plain)
                                .disabled(retro.recordID == nil)
                            }
                        } footer: {
                            Text("More than one retrospective exists for today. Choose one to edit; the others are kept and can be opened from the journal.")
                        }
                    }
                }
            }
            .navigationTitle("Which retrospective?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .accessibilityIdentifier("RetroConflictChooser")
        }
    }

    private func errorState(_ message: String) -> some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Could not open the retrospective", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") { error = nil; resolve() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }

    private func resolve() {
        guard draft == nil, !lock.isLocked else { return }
        let today = CivilDay.today()
        let practice = ContentLibrary.dailyPractice()
        do {
            if try drafts.listing(kind: .retro).unreadableCount > 0 {
                error = String(localized: "Some drafts could not be read. They were left untouched.")
            }
            if let selection = try repository.retro(for: today) {
                if selection.hasConflicts {
                    conflicts = selection.all
                    return
                }
                if let recordID = selection.primary.recordID,
                   let pending = try existingEditingDraft(for: recordID, in: drafts) {
                    draft = pending
                } else if let editing = JournalDraft.editing(selection.primary) {
                    draft = editing
                } else {
                    error = String(localized: "Today's retrospective has no identity yet and cannot be edited.")
                }
                return
            }
            if let pending = try drafts.retroDraft(day: today) {
                draft = pending
                return
            }
            draft = JournalDraft(
                kind: .retro,
                context: JournalDraft.Context(
                    civilDay: today,
                    practiceID: practice.id,
                    promptSnapshot: practice.question
                )
            )
        } catch {
            self.error = String(localized: "Today's retrospective could not be read. Nothing was changed.")
        }
    }

    private func beginBlank() {
        let day = CivilDay.today()
        let practice = ContentLibrary.dailyPractice()
        draft = JournalDraft(kind: .retro, context: .init(civilDay: day, practiceID: practice.id, promptSnapshot: practice.question))
    }
}
