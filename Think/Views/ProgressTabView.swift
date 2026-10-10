//
//  ProgressTabView.swift
//  Think
//

import Charts
import SwiftData
import SwiftUI

/// The Progress tab (`design/progress-settings.md` sections 1 and 2): the
/// streak hero, the weekly review, Practice, Achievements and Focus
/// history, top to bottom, with the gear pushing Settings. Named
/// `ProgressTabView` rather than the brief's `ProgressView` so it does not
/// shadow SwiftUI's `ProgressView` across the app module.
struct ProgressTabView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(JournalLock.self) private var lock
    @Environment(JournalRepository.self) private var repository
    @Environment(AppIntentRouter.self) private var router
    @Environment(\.haptics) private var haptics
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingStreakCalendar = false
    @State private var intentions: [String: String] = [:]

    var body: some View {
        let overview = ProgressOverview(progress: progress)
        NavigationStack {
            List {
                streakSection
                weeklyReviewSection(overview)
                practiceSection(overview)
                achievementsSection(overview)
                focusHistorySection(overview)
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: ThinkSymbol.settings)
                            .labelStyle(.iconOnly)
                    }
                    // Monochrome: the tab bar's accentInk tint stops here.
                    .tint(ThinkColor.label)
                    .accessibilityIdentifier("Settings")
                }
            }
            .accessibilityIdentifier("ProgressTab")
        }
        .sheet(isPresented: $showingStreakCalendar) {
            StreakCalendarSheet()
        }
        .task(id: IntentionRequest(sessionIDs: overview.recentSessions.map(\.id), isLocked: lock.isLocked)) {
            intentions = FocusHistoryIntentions.load(
                sessionIDs: overview.recentSessions.map(\.id), isLocked: lock.isLocked, repository: repository)
        }
        .onChange(of: lock.isLocked) { _, locked in
            if locked { intentions = [:] }
        }
    }

    // MARK: - Streak

    /// One `surface` row that opens the streak sheet, as Today's toolbar
    /// item does. At zero the two-state copy replaces the numeral.
    private var streakSection: some View {
        let count = progress.displayedStreak
        let presentation = StreakPresentation(
            streak: count, completedPracticeCount: 0, hasPractised: progress.lastCompletedDay != nil)
        return Section {
            Button {
                haptics.play(.selection)
                showingStreakCalendar = true
            } label: {
                HStack(spacing: ThinkSpacing.m) {
                    Image(systemName: ThinkSymbol.streak)
                        .font(.title)
                        .foregroundStyle(count > 0 ? ThinkColor.accent : ThinkColor.secondaryLabel)
                    VStack(alignment: .leading, spacing: ThinkSpacing.xs) {
                        if count > 0 {
                            Text(streakDays(count))
                        } else {
                            Text(presentation.streakText)
                                .font(.think(.heading))
                                .foregroundStyle(ThinkColor.label)
                        }
                        Text("View calendar")
                            .font(.think(.secondary))
                            .foregroundStyle(ThinkColor.accentInk)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(count > 0 ? String(localized: "\(count) day streak") : presentation.streakText)
            .accessibilityHint(Text("Shows your streak calendar"))
            .accessibilityIdentifier("ProgressStreak")
        }
    }

    /// "12 days" with the number in the numeral role and the word beside
    /// it, one pluralised string so every locale keeps its grammar.
    private func streakDays(_ count: Int) -> AttributedString {
        var text = AttributedString(localized: "streak.days \(count)")
        text.font = .think(.secondary)
        text.foregroundColor = ThinkColor.secondaryLabel
        if let range = text.range(of: String(count)) {
            text[range].font = .think(.numeral)
            text[range].foregroundColor = ThinkColor.label
        }
        return text
    }

    // MARK: - Weekly review

    private func weeklyReviewSection(_ overview: ProgressOverview) -> some View {
        Section {
            NavigationLink {
                WeeklyReviewView()
            } label: {
                LabeledContent {
                    Text("\(overview.week.practiceDays) of \(overview.week.days.count) days")
                } label: {
                    Label {
                        Text("Weekly review")
                    } icon: {
                        Image(systemName: ThinkSymbol.weeklyReview)
                            .foregroundStyle(ThinkColor.label)
                    }
                }
            }
            .accessibilityIdentifier("OpenWeeklyReview")
        }
    }

    // MARK: - Practice

    /// Three all-time values in one row, labelled rows at accessibility
    /// sizes (`PRO-2`, `PRO-3`), then this week's completed sessions.
    private func practiceSection(_ overview: ProgressOverview) -> some View {
        Section {
            if dynamicTypeSize.isAccessibilitySize {
                LabeledContent("Practice days", value: overview.practiceDays.formatted())
                    .accessibilityIdentifier("Practice.days")
                LabeledContent("Path steps", value: overview.completedPathSteps.formatted())
                    .accessibilityIdentifier("Practice.pathSteps")
                LabeledContent("Focus sessions", value: overview.completedFocusSessions.formatted())
                    .accessibilityIdentifier("Practice.focusSessions")
            } else {
                HStack(alignment: .top, spacing: ThinkSpacing.m) {
                    practiceValue(overview.practiceDays, label: "Practice days")
                        .accessibilityIdentifier("Practice.days")
                    practiceValue(overview.completedPathSteps, label: "Path steps")
                        .accessibilityIdentifier("Practice.pathSteps")
                    practiceValue(overview.completedFocusSessions, label: "Focus sessions")
                        .accessibilityIdentifier("Practice.focusSessions")
                }
            }
            PracticeWeekView(week: overview.week)
        } header: {
            Text("Practice")
        }
    }

    private func practiceValue(_ value: Int, label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: ThinkSpacing.xs) {
            Text(value, format: .number)
                .font(.think(.numeral))
                .foregroundStyle(ThinkColor.label)
            Text(label)
                .font(.think(.caption))
                .foregroundStyle(ThinkColor.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Achievements

    private func achievementsSection(_ overview: ProgressOverview) -> some View {
        Section {
            if overview.highlightedAchievements.isEmpty {
                Text("Medals you earn appear here.")
                    .foregroundStyle(ThinkColor.secondaryLabel)
            } else {
                EarnedMedalStrip(achievements: overview.highlightedAchievements)
            }
            NavigationLink("All achievements") {
                AchievementsView()
            }
            .accessibilityIdentifier("AllAchievements")
        } header: {
            Text("Achievements")
        }
    }

    // MARK: - Focus history

    private func focusHistorySection(_ overview: ProgressOverview) -> some View {
        Section {
            if overview.recentSessions.isEmpty {
                Text("No focus sessions yet.")
                    .foregroundStyle(ThinkColor.secondaryLabel)
                Button("Start a session") {
                    router.selectedTab = .focus
                }
                .thinkButton(.tertiary)
                .accessibilityIdentifier("StartFocusSession")
            } else {
                ForEach(overview.recentSessions) { record in
                    FocusSessionRow(record: record, intention: lock.isLocked ? nil : intentions[record.id])
                }
                NavigationLink("See all sessions") {
                    FocusHistoryView()
                }
                .accessibilityIdentifier("SeeAllSessions")
            }
        } header: {
            Text("Focus history")
        }
    }
}

/// Up to three earned medals with title and earned state. They sit side
/// by side while they fit and stack into rows when they do not, which
/// always happens at accessibility sizes.
private struct EarnedMedalStrip: View {
    let achievements: [ProgressAchievement]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            stacked
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: ThinkSpacing.m) {
                    ForEach(achievements) { achievement in
                        VStack(spacing: ThinkSpacing.s) {
                            AchievementMedal(achievement: achievement, isEarned: true)
                            caption(for: achievement, alignment: .center)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("EarnedMedal.\(achievement.id)")
                    }
                }
                stacked
            }
        }
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: ThinkSpacing.m) {
            ForEach(achievements) { achievement in
                HStack(spacing: ThinkSpacing.m) {
                    AchievementMedal(achievement: achievement, isEarned: true)
                    caption(for: achievement, alignment: .leading)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("EarnedMedal.\(achievement.id)")
            }
        }
    }

    private func caption(for achievement: ProgressAchievement, alignment: TextAlignment) -> some View {
        VStack(alignment: alignment == .center ? .center : .leading, spacing: 2) {
            Text(achievement.localizedLabel)
                .font(.think(.caption))
                .foregroundStyle(ThinkColor.label)
            Text("Earned")
                .font(.think(.caption))
                .foregroundStyle(ThinkColor.secondaryLabel)
        }
        .multilineTextAlignment(alignment)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// This week's completed Focus sessions, Monday to Sunday. A plain zero
/// line with no grid when there are none (`FST-1`), labelled day rows at
/// accessibility sizes.
private struct PracticeWeekView: View {
    let week: WeeklyPracticeSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 120

    private var topCount: Int { max(week.days.map(\.completedSessions).max() ?? 1, 1) }

    var body: some View {
        if week.completedSessions == 0 {
            Text("No completed focus sessions this week.")
                .foregroundStyle(ThinkColor.secondaryLabel)
                .accessibilityIdentifier("PracticeWeekEmpty")
        } else if dynamicTypeSize.isAccessibilitySize {
            ForEach(week.days, id: \.date) { day in
                LabeledContent {
                    Text(day.completedSessions, format: .number)
                } label: {
                    Text(day.date, format: .dateTime.weekday(.wide))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide)))
                .accessibilityValue(Text("focus.sessions.count \(day.completedSessions)"))
            }
        } else {
            VStack(alignment: .leading, spacing: ThinkSpacing.s) {
                Text("Focus sessions this week")
                    .font(.think(.caption))
                    .foregroundStyle(ThinkColor.secondaryLabel)
                Chart(week.days, id: \.date) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Sessions", day.completedSessions)
                    )
                    .foregroundStyle(ThinkColor.accent)
                    .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide)))
                    .accessibilityValue(Text("focus.sessions.count \(day.completedSessions)"))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    }
                }
                .chartYScale(domain: 0...topCount)
                .chartYAxis {
                    // Whole sessions only: never a fractional tick.
                    AxisMarks(position: .leading, values: topCount <= 4 ? Array(0...topCount) : [0, topCount / 2, topCount]) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: min(chartHeight, 180))
                .accessibilityIdentifier("PracticeWeekChart")
            }
            .padding(.vertical, ThinkSpacing.xs)
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: JournalDataStore.schema, configurations: JournalDataStore.configuration(for: .inMemory))
    ProgressTabView()
        .environment(ProgressStore())
        .environment(AppIntentRouter.shared)
        .environment(JournalLock(authenticator: UnavailableJournalAuthenticator()))
        .environment(JournalRepository(modelContext: container.mainContext, storage: .inMemory))
        .environment(MindfulMinutesStore(client: UnavailableMindfulHealthClient()))
        .environment(CloudBackupState(storage: .inMemory))
        .environment(PomodoroTimer())
        .modelContainer(container)
}
