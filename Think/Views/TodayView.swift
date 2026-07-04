//
//  TodayView.swift
//  Think
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]

    @State private var answer = ""
    @State private var showingShareCard = false

    private var quote: Quote { ContentLibrary.dailyQuote() }
    private var question: String { ContentLibrary.dailyQuestion() }

    private var todaysEntry: JournalEntry? {
        entries.first { $0.kind == JournalEntry.kindQuestion && Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    quoteCard
                    questionCard
                    statsRow
                }
                .padding()
            }
            .navigationTitle(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    streakBadge
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    private var streakBadge: some View {
        Label("\(progress.displayedStreak)", systemImage: "flame.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(progress.displayedStreak > 0 ? .orange : .secondary)
            .accessibilityLabel("\(progress.displayedStreak) day streak")
    }

    private var quoteCard: some View {
        VStack(spacing: 14) {
            Text(quote.text)
                .font(.title2)
                .fontDesign(.serif)
                .multilineTextAlignment(.center)
            Text(quote.author)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                showingShareCard = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.subheadline)
            }
            .buttonStyle(.glass)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showingShareCard) {
            ShareCardSheet(quote: quote)
        }
    }

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Question of the day")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(question)
                .font(.headline)

            if let entry = todaysEntry {
                Label("Answered", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
                Text(entry.text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                TextField("Write a few honest sentences…", text: $answer, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                Button("Save answer") {
                    saveAnswer()
                }
                .buttonStyle(.glassProminent)
                .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(value: "\(progress.focusSessionsToday)", label: "Focus sessions today")
            statCard(
                value: progress.pathCompletedDays > 0 ? "Day \(progress.pathCompletedDays)" : "—",
                label: PathLibrary.deepFocus.name
            )
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.medium))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func saveAnswer() {
        let text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        modelContext.insert(JournalEntry(prompt: question, text: text, kind: JournalEntry.kindQuestion))
        progress.markTodayComplete()
        answer = ""
    }
}

#Preview {
    TodayView()
        .environment(ProgressStore())
        .modelContainer(for: JournalEntry.self, inMemory: true)
}
