//
//  TodayView.swift
//  Think
//

import Combine
import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.haptics) private var haptics
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @Query(sort: \DailyRetro.date, order: .reverse) private var retros: [DailyRetro]

    @State private var answer = ""
    @State private var showingShareCard = false
    @State private var showingRetro = false
    @State private var showingStreakCalendar = false
    @State private var now = Date.now
    @State private var appeared = false
    @State private var savedPulse = false

    private var practice: DailyPractice { ContentLibrary.dailyPractice() }
    private var quote: Quote { practice.quote }
    private var question: String { practice.question }
    private var action: String { practice.action }

    private var todaysEntry: JournalEntry? {
        entries.first { $0.kind == JournalEntry.kindQuestion && Calendar.current.isDateInToday($0.date) }
    }

    private var todaysRetro: DailyRetro? {
        retros.first { Calendar.current.isDateInToday($0.date) }
    }

    /// The retrospective belongs to the evening; surface the card from
    /// 8pm on, or any time one was already written today. Depends on
    /// `now` state (refreshed each minute and on foregrounding) so the
    /// card appears while the app idles across the 8pm boundary.
    private var showsRetroCard: Bool {
        todaysRetro != nil || Calendar.current.component(.hour, from: now) >= 20
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ritualHeader
                    quoteCard
                    questionCard
                    if showsRetroCard {
                        retroCard
                    }
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
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        JournalView()
                    } label: {
                        Image(systemName: "book.closed")
                    }
                    .accessibilityLabel("Journal")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    streakBadge
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .onAppear {
                synchronizeDailyQuestionProgress()
                withAnimation(.easeOut(duration: 0.45)) {
                    appeared = true
                }
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
                now = date
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    now = .now
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
            }

            ProgressView(value: dailyProgress)
                .tint(.accentColor)

            HStack {
                Text("Daily practice")
                Spacer()
                Text("\(dailyProgressCount)/4")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }

    /// Streak-zero copy follows the "no guilt" principle: a fresh user
    /// is invited to start, a lapsed one to begin again.
    private var streakCaption: String {
        if progress.displayedStreak > 0 { return String(localized: "streak") }
        return progress.lastCompletedDay == nil
            ? String(localized: "start today")
            : String(localized: "begin again")
    }

    private var streakAccessibilityLabel: String {
        guard progress.displayedStreak > 0 else { return streakCaption }
        return String(localized: "\(progress.displayedStreak) day streak")
    }

    private var dailyProgressCount: Int {
        progress.dailyPracticeProgressCount
    }

    private var dailyProgress: Double {
        Double(dailyProgressCount) / 4
    }

    private var streakBadge: some View {
        Button {
            haptics.play(.selection)
            showingStreakCalendar = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.body)
                if progress.displayedStreak > 0 {
                    Text("\(progress.displayedStreak)")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .monospacedDigit()
                }
                Text(streakCaption)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(progress.displayedStreak > 0 ? Color.accentColor : .secondary)
        }
        .accessibilityLabel(streakAccessibilityLabel)
        .accessibilityHint("Shows your streak calendar")
        .sheet(isPresented: $showingStreakCalendar) {
            StreakCalendarSheet()
        }
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
                if let attribution = quote.attribution {
                    Text(attribution)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    haptics.play(.selection)
                    showingShareCard = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
                .accessibilityIdentifier("ShareQuote")
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Label("Today's move", systemImage: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(action)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("QuestionOfTheDayCard")
    }

    private func answeredState(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Answered", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
                .accessibilityIdentifier("DailyQuestionAnswered")
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
                .accessibilityIdentifier("DailyQuestionInput")

            Button {
                saveAnswer()
            } label: {
                Label("Save answer", systemImage: "checkmark")
                    .foregroundStyle(Color.prominentButtonForeground(for: colorScheme))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.accentColor)
            .opacity(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("SaveDailyAnswer")
        }
    }

    private var retroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                "Evening retrospective",
                detail: todaysRetro == nil ? "2 minutes" : "written"
            )

            if let retro = todaysRetro {
                VStack(alignment: .leading, spacing: 12) {
                    retroSummaryRow("checkmark.circle", retro.wentWell)
                    retroSummaryRow("arrow.up.circle", retro.improve)
                    retroSummaryRow("sunrise", retro.tomorrow)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Button {
                    haptics.play(.selection)
                    showingRetro = true
                } label: {
                    Label("Edit retrospective", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
            } else {
                Text("How was the day? Close it honestly before it closes on you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    haptics.play(.selection)
                    showingRetro = true
                } label: {
                    Label("Begin retrospective", systemImage: "moon.stars")
                        .foregroundStyle(Color.prominentButtonForeground(for: colorScheme))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.accentColor)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.separator.opacity(0.6), lineWidth: 1)
        }
        .sheet(isPresented: $showingRetro) {
            RetroSheet()
        }
    }

    @ViewBuilder
    private func retroSummaryRow(_ systemImage: String, _ text: String) -> some View {
        if !text.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.footnote)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 18)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            metricTile(
                value: "\(progress.focusSessionsToday)",
                label: String(localized: "Focus sessions today"),
                systemImage: "timer"
            )
            metricTile(
                value: progress.pathCompletedDays > 0
                    ? String(localized: "Day \(progress.pathCompletedDays)")
                    : String(localized: "Not started"),
                label: PathLibrary.deepFocus.name,
                systemImage: "point.topleft.down.to.point.bottomright.curvepath"
            )
        }
        .accessibilityIdentifier("TrainingLog")
    }

    private func sectionHeader(_ title: LocalizedStringKey, detail: LocalizedStringKey? = nil) -> some View {
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
            Text(verbatim: label)
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
        progress.recordDailyQuestionAnswer()
        haptics.play(.success)
        answer = ""
        savedPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            savedPulse = false
        }
    }

    private func synchronizeDailyQuestionProgress() {
        guard let todaysEntry else { return }
        progress.recordDailyQuestionAnswer(at: todaysEntry.date)
    }
}

#Preview {
    TodayView()
        .environment(ProgressStore())
        .modelContainer(for: [JournalEntry.self, DailyRetro.self], inMemory: true)
}
