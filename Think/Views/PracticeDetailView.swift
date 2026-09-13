import SwiftUI

struct PracticeDetailView: View {
    let practiceID: String
    var version: Int? = nil
    @Environment(FavoritesStore.self) private var favorites
    @Environment(PracticePreferencesStore.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingRetry = false
    @State private var sharing = false

    var body: some View {
        Group {
            if let practice = ContentLibrary.practice(id: practiceID, version: version) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(practice.quote.text).font(.system(.title, design: .serif))
                        if let attribution = practice.quote.attribution {
                            Text(attribution).font(.subheadline).foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Question").font(.headline)
                            Text(practice.question).font(.body)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Today's move").font(.headline)
                            Text(practice.action).font(.body)
                        }
                        Button("Try this again") { showingRetry = true }
                            .font(.headline)
                            .foregroundStyle(Color.prominentButtonForeground(for: colorScheme))
                            .buttonStyle(.borderedProminent).tint(Color("AccentColor"))
                            .accessibilityIdentifier("RetryPractice")
                        if let source = practice.quote.source {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Source").font(.headline)
                                Text("\(source.work), \(source.locator)")
                                Text(source.edition)
                                Text("Localized renditions are based on the cited English edition.")
                                    .font(.caption).foregroundStyle(.secondary)
                                if let url = URL(string: source.url) {
                                    Link("Read source", destination: url)
                                        .foregroundStyle(Color.accessibleAccent(for: colorScheme))
                                }
                            }.font(.subheadline)
                        } else {
                            Text("Original Think practice").font(.caption).foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Was this useful?").font(.headline)
                            Button {
                                preferences.setFeedback(preferences.feedback[practiceID] == .tried ? nil : .tried, for: practiceID)
                            } label: {
                                Label("I tried the action", systemImage: preferences.feedback[practiceID] == .tried ? "checkmark.circle.fill" : "circle")
                            }
                            Button {
                                preferences.setFeedback(preferences.feedback[practiceID] == .lessLikeThis ? nil : .lessLikeThis, for: practiceID)
                            } label: {
                                Label("Less like this in suggestions", systemImage: preferences.feedback[practiceID] == .lessLikeThis ? "checkmark.circle.fill" : "minus.circle")
                            }
                            Text("Feedback stays on this device. It does not change today's assigned practice.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.accessibleAccent(for: colorScheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(24)
                }
                .sheet(isPresented: $showingRetry) { PracticeRetrySheet(practice: practice) }
                .sheet(isPresented: $sharing) { ShareCardSheet(quote: practice.quote) }
                .toolbar {
                    Button { favorites.toggle(practice.quote) } label: {
                        Image(systemName: favorites.isFavorite(practice.quote) ? "heart.fill" : "heart")
                    }.accessibilityLabel("Save this line")
                    Button { sharing = true } label: { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Share")
                }
            } else {
                ContentUnavailableView("Practice unavailable", systemImage: "text.quote")
            }
        }
        .navigationTitle("Saved practice")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

private struct PracticeRetrySheet: View {
    let practice: DailyPractice
    @Environment(JournalRepository.self) private var repository
    @Environment(JournalDraftStore.self) private var drafts
    @Environment(JournalLock.self) private var lock
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft = JournalDraft(kind: .note)
    @State private var error: String?
    @State private var blankCapture = true
    @State private var loaded = false
    @State private var committed = false

    var body: some View {
        NavigationStack {
            Group {
                if lock.isLocked && !blankCapture {
                    Button("Unlock") { Task { await lock.authenticate() } }
                } else {
                    Form {
                        if repository.storageWarning != nil {
                            Text("Temporary storage: writing in this session will be lost when the app closes.").foregroundStyle(.red)
                        }
                        Section("Question") { Text(practice.question) }
                        Section("Today's move") { Text(practice.action) }
                        Section("Your reflection") {
                            TextEditor(text: $draft.text).frame(minHeight: 160).disabled(committed)
                        }
                        if let error { Text(error).foregroundStyle(.red) }
                    }
                    .onChange(of: draft.text) { _, _ in persistDraft() }
                }
            }
            .navigationTitle("Try this again")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (lock.isLocked && !blankCapture))
                }
            }
            .task {
                guard !loaded else { return }
                loaded = true
                draft = JournalDraft(kind: .note, context: .init(practiceID: practice.id, promptSnapshot: practice.question))
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { persistDraft(); blankCapture = false }
            }
        }
    }

    private func persistDraft() {
        guard loaded, !committed else { return }
        do {
            // Cleared text removes the file, so nothing blank resurfaces as "unsaved".
            if draft.containsPrivateContent { try drafts.save(draft) } else { try drafts.delete(id: draft.id) }
        } catch { self.error = String(localized: "Draft could not be saved. Keep this screen open and try again.") }
    }

    private func save() {
        do {
            if !committed {
                _ = try repository.savePracticeNote(text: draft.text, practiceID: practice.id,
                    prompt: draft.context.promptSnapshot ?? practice.question,
                    day: draft.context.civilDay, recordID: draft.id)
                progress.recordActivity(.note, id: draft.id.uuidString, at: draft.createdAt)
                committed = true
            }
            try drafts.delete(id: draft.id)
            dismiss()
        } catch {
            self.error = committed
                ? String(localized: "Saved. Recovery draft cleanup failed. Try again.")
                : String(localized: "Your writing could not be saved. Try again; your draft is still here.")
        }
    }
}
