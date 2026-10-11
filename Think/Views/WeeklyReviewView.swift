import SwiftUI

/// A once-a-week summary of practice plus one private reflection
/// (`design/progress-settings.md` section 9).
///
/// Practice counts are aggregate, non-textual evidence and stay visible
/// while the journal is locked. The journal's counts, the mood counts and
/// the reflection are private: nothing of them is read while
/// `JournalLock.isLocked`. The reflection is written in the Journal editor
/// ("Write reflection") and, once saved, read and edited through its
/// detail. The screen has no primary action.
struct WeeklyReviewView: View {
    @Environment(JournalRepository.self) private var repository
    @Environment(JournalDraftStore.self) private var drafts
    @Environment(JournalLock.self) private var lock
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let week: WeeklyReviewWeek

    @State private var summary: WeeklyPracticeSummary?
    @State private var journal: WeeklyReviewJournal?
    @State private var editorDraft: JournalDraft?
    @State private var editorNotice: String?
    @ThinkSpacing.Scaled(ThinkSpacing.s) private var gap

    init(now: Date = .now) {
        week = WeeklyReviewWeek(containing: now)
    }

    /// Private journal content, only once read while unlocked.
    private var activity: JournalRepository.ActivitySummary? {
        lock.isLocked ? nil : journal?.activity
    }

    var body: some View {
        List {
            if let summary { practiceSection(summary) }
            if let activity { moodSection(activity) }
            reflectionSection
        }
        .navigationTitle("Weekly review")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("WeeklyReviewView")
        .sheet(item: $editorDraft) { draft in
            JournalEditor(draft: draft, notice: editorNotice)
        }
        .task {
            summary = progress.weeklySummary(containing: week.interval.start, calendar: week.calendar)
            load()
        }
        .onChange(of: lock.isLocked) { _, _ in load() }
        .onChange(of: repository.revision) { _, _ in load() }
    }

    // MARK: Practice

    private func practiceSection(_ summary: WeeklyPracticeSummary) -> some View {
        Section {
            VStack(alignment: .leading, spacing: gap) {
                Text("\(summary.practiceDays) of \(summary.days.count) days")
                    .font(.think(.numeral))
                    .foregroundStyle(ThinkColor.label)
                Text("Practiced")
                    .font(.think(.secondary))
                    .foregroundStyle(ThinkColor.secondaryLabel)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("WeeklyReviewPracticeDays")
            DisclosureGroup("This week") {
                if let activity {
                    count("Answers", value: activity.answers.formatted())
                    count("Notes", value: activity.notes.formatted())
                    count("Retrospectives", value: activity.retros.formatted())
                }
                count("Completed focus sessions", value: summary.completedSessions.formatted())
                count("Completed focus minutes", value: summary.completedMinutes.formatted())
                if summary.partialActiveSeconds > 0 {
                    count("Partial effort, not completed",
                          value: Duration.seconds(summary.partialActiveSeconds).formatted(.time(pattern: .minuteSecond)))
                }
                footnote("Counts cover this calendar week only. Completed minutes use planned session lengths; partial effort is active time from sessions ended early.")
            }
            .accessibilityIdentifier("WeeklyReviewThisWeek")
        }
    }

    private func moodSection(_ activity: JournalRepository.ActivitySummary) -> some View {
        Section {
            DisclosureGroup("Mood this week") {
                ForEach(Mood.allCases) { mood in
                    count(Text(mood.label), value: (activity.taggedMoodCounts[mood.rawValue] ?? 0).formatted())
                }
                count("Untagged", value: activity.untaggedCount.formatted())
                footnote("Categories, not a score. An entry either carries one of these tags or stays untagged.")
            }
            .accessibilityIdentifier("WeeklyReviewMood")
        }
    }

    /// A label beside its value, the label over the value at accessibility
    /// sizes (design-system section 3.2).
    @ViewBuilder
    private func count(_ label: Text, value: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: gap) {
                label.foregroundStyle(ThinkColor.label)
                Text(value).foregroundStyle(ThinkColor.secondaryLabel)
            }
            .font(.think(.body))
            .accessibilityElement(children: .combine)
        } else {
            LabeledContent { Text(value) } label: { label }
        }
    }

    private func count(_ label: LocalizedStringKey, value: String) -> some View {
        count(Text(label), value: value)
    }

    private func footnote(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.think(.caption))
            .foregroundStyle(ThinkColor.secondaryLabel)
    }

    // MARK: Reflection

    /// Locked wins over whatever an earlier read found.
    private var reflection: WeeklyReviewJournal.Reflection? {
        lock.isLocked ? .locked : journal?.reflection
    }

    private var reflectionSection: some View {
        Section("Your reflection") {
            switch reflection {
            case .locked:
                JournalGate(isRow: true)
            case .unavailable:
                VStack(alignment: .leading, spacing: gap) {
                    Text("Could not load your weekly review.")
                        .foregroundStyle(ThinkColor.label)
                    Button("Try again") { load() }
                        .thinkButton(.tertiary)
                }
                .font(.think(.body))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("WeeklyReviewLoadError")
            case .saved(let id):
                if let review = journal?.review {
                    if let id {
                        NavigationLink {
                            JournalDetailView(record: .entry(id))
                        } label: {
                            JournalRow(content: JournalRowContent(review))
                        }
                        .accessibilityIdentifier("WeeklyReviewSaved")
                    } else {
                        JournalRow(content: JournalRowContent(review))
                            .accessibilityIdentifier("WeeklyReviewSaved")
                    }
                }
            case .notWritten:
                Button("Write reflection") { writeReflection() }
                    .thinkButton(.tertiary)
                    .font(.think(.body))
                    .accessibilityIdentifier("WriteReflection")
            case nil:
                ProgressView()
            }
        }
    }

    /// Reads the private half. Locked, it reads nothing and drops what an
    /// earlier unlocked read left behind.
    private func load() {
        journal = WeeklyReviewJournal.load(week: week, locked: lock.isLocked, repository: repository)
    }

    /// A new weekly review of this week, or this week's unsaved draft.
    private func writeReflection() {
        let opened = JournalEditorOpening.weeklyReview(week: week.start, locked: lock.isLocked, drafts: drafts)
        editorNotice = opened.notice
        editorDraft = opened.draft
    }
}
