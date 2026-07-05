//
//  TodayView.swift
//  Think
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.haptics) private var haptics
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]

    @State private var answer = ""
    @State private var showingShareCard = false
    @State private var appeared = false
    @State private var savedPulse = false

    private var quote: Quote { ContentLibrary.dailyQuote() }
    private var question: String { ContentLibrary.dailyQuestion() }

    private var todaysEntry: JournalEntry? {
        entries.first { $0.kind == JournalEntry.kindQuestion && Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ritualHeader
                    quoteCard
                    questionCard
                    sectionHeader("Training log", detail: "today")
                    statsRow
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 110)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    streakBadge
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .onAppear {
                withAnimation(.easeOut(duration: 0.45)) {
                    appeared = true
                }
            }
        }
    }

    private var ritualHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Today's practice")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(progress.displayedStreak)")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(progress.displayedStreak > 0 ? Color.accentColor : .secondary)
                    Text(streakCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(progress.displayedStreak) day streak")
            }

            ProgressView(value: dailyProgress)
                .tint(.accentColor)

            HStack {
                Text("Daily practice")
                Spacer()
                Text("\(dailyProgressCount)/3")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }

    /// Streak-zero copy follows the "no guilt" principle: a fresh user
    /// is invited to start, a lapsed one to begin again.
    private var streakCaption: String {
        if progress.displayedStreak > 0 { return "streak" }
        return progress.lastCompletedDay == nil ? "start today" : "begin again"
    }

    private var dailyProgressCount: Int {
        var completed = 0
        if todaysEntry != nil { completed += 1 }
        if progress.focusSessionsToday > 0 { completed += 1 }
        if progress.completedPathStepToday { completed += 1 }
        return completed
    }

    private var dailyProgress: Double {
        Double(dailyProgressCount) / 3
    }

    private var streakBadge: some View {
        Label("\(progress.displayedStreak)", systemImage: "flame.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(progress.displayedStreak > 0 ? Color.accentColor : .secondary)
            .accessibilityLabel("\(progress.displayedStreak) day streak")
    }

    private var quoteCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 42, height: 4)
                .clipShape(Capsule())

            Text(quote.text)
                .font(.system(.title2, design: .serif).weight(.medium))
                .foregroundStyle(.primary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(quote.author)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    haptics.play(.selection)
                    showingShareCard = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.separator.opacity(0.6), lineWidth: 1)
        }
        .sheet(isPresented: $showingShareCard) {
            ShareCardSheet(quote: quote)
        }
    }

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                "Question of the day",
                detail: todaysEntry == nil ? "1 minute" : "complete"
            )

            Text(question)
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let entry = todaysEntry {
                answeredState(entry)
            } else {
                answerEditor
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.separator.opacity(0.6), lineWidth: 1)
        }
        .scaleEffect(savedPulse ? 1.015 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: savedPulse)
    }

    private func answeredState(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Answered", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
            Text(entry.text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var answerEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Write a few honest sentences…", text: $answer, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.plain)
                .foregroundStyle(.primary)
                .padding(14)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                saveAnswer()
            } label: {
                Label("Save answer", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.accentColor)
            .opacity(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            metricTile(
                value: "\(progress.focusSessionsToday)",
                label: "Focus sessions today",
                systemImage: "timer"
            )
            metricTile(
                value: progress.pathCompletedDays > 0 ? "Day \(progress.pathCompletedDays)" : "Not started",
                label: PathLibrary.deepFocus.name,
                systemImage: "point.topleft.down.to.point.bottomright.curvepath"
            )
        }
    }

    private func sectionHeader(_ title: String, detail: String? = nil) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption)
            }
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private func metricTile(value: String, label: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.separator.opacity(0.6), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func saveAnswer() {
        let text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        modelContext.insert(JournalEntry(prompt: question, text: text, kind: JournalEntry.kindQuestion))
        progress.markTodayComplete()
        haptics.play(.success)
        answer = ""
        savedPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            savedPulse = false
        }
    }
}

#Preview {
    TodayView()
        .environment(ProgressStore())
        .modelContainer(for: JournalEntry.self, inMemory: true)
}
