import SwiftUI

/// A once-a-week summary of practice plus one private reflection.
///
/// Reflection text and next-week intention are journal content: gated the
/// same way any other saved journal record is, fail closed when the lock
/// cannot be evaluated. Practice counts are aggregate, non-textual evidence
/// (matching FocusStatsView) and stay visible even while the journal is
/// locked. This screen shows a saved review read-only; editing it (text and
/// next-week intention) happens from the journal entry detail, which routes
/// through `JournalRepository.updateWeeklyReview`.
struct WeeklyReviewView: View {
    @Environment(JournalRepository.self) private var repository
    @Environment(JournalDraftStore.self) private var drafts
    @Environment(JournalLock.self) private var lock
    @Environment(ProgressStore.self) private var progress
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.haptics) private var haptics

    private let weekStart: Date
    private let weekInterval: DateInterval
    private let periodKey: String

    @State private var summary: WeeklyPracticeSummary?
    @State private var activity: JournalRepository.ActivitySummary?
    @State private var existingReview: JournalRepository.EntrySnapshot?
    @State private var draft: JournalDraft?
    @State private var requiresUnlock = false
    @State private var privateDataLoaded = false
    @State private var error: String?
    @State private var committed = false
    @State private var finished = false

    init(now: Date = .now) {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        weekStart = start
        weekInterval = DateInterval(start: start, end: end)
        periodKey = JournalIdentity.weekKey(for: start)
    }

    /// True whenever private content (an existing review, a recovered
    /// draft, or an unread failed load) must stay hidden: still locked and
    /// either nothing has been read yet or what was read is sensitive.
    /// A freshly created blank draft never sets `requiresUnlock`, so typing
    /// into it cannot lock the screen out from under the person writing.
    private var reflectionLocked: Bool { lock.isLocked && (!privateDataLoaded || requiresUnlock) }
    private var canSave: Bool {
        guard let draft, !committed else { return committed }
        return !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !(draft.tomorrowIntention ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        List {
            if let summary { practiceSection(summary) }
            if !lock.isLocked, let activity { moodSection(activity) }
            reflectionSection
        }
        .navigationTitle("Weekly review")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("WeeklyReviewView")
        .task { summary = progress.weeklySummary(containing: weekStart, calendar: isoCalendar); loadPrivateData() }
        .onChange(of: lock.isLocked) { _, locked in if !locked { loadPrivateData() } }
        .onChange(of: draft) { _, _ in persistDraft() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                persistDraft()
                if draft?.containsPrivateContent == true { requiresUnlock = true }
            }
        }
    }

    private var isoCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601); calendar.timeZone = .current; return calendar
    }

    private func practiceSection(_ summary: WeeklyPracticeSummary) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(summary.practiceDays) of \(summary.days.count) days")
                        .font(.title2.bold())
                    Text("Practiced").font(.subheadline).foregroundStyle(.secondary)
                }
                DisclosureGroup("This week") {
                    VStack(spacing: 12) {
                        if !lock.isLocked, let activity {
                            LabeledContent("Answers", value: activity.answers.formatted())
                            LabeledContent("Notes", value: activity.notes.formatted())
                            LabeledContent("Retrospectives", value: activity.retros.formatted())
                        }
                        LabeledContent("Completed focus sessions", value: summary.completedSessions.formatted())
                        LabeledContent("Completed focus minutes", value: summary.completedMinutes.formatted())
                        if summary.partialActiveSeconds > 0 {
                            LabeledContent("Partial effort, not completed", value: Duration.seconds(summary.partialActiveSeconds).formatted(.time(pattern: .minuteSecond)))
                        }
                        Text("Counts cover this calendar week only. Completed minutes use planned session lengths; partial effort is active time from sessions ended early.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }.padding(.top, 12)
                }.font(.subheadline)
            }.padding(.vertical, 8)
        }
    }

    private func moodSection(_ activity: JournalRepository.ActivitySummary) -> some View {
        Section {
            DisclosureGroup("Mood this week") {
                VStack(spacing: 12) {
                    ForEach(Mood.allCases) { mood in
                        LabeledContent(mood.label, value: (activity.taggedMoodCounts[mood.rawValue] ?? 0).formatted())
                    }
                    LabeledContent("Untagged", value: activity.untaggedCount.formatted())
                    Text("Categories, not a score. An entry either carries one of these tags or stays untagged.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(.top, 12)
            }.font(.subheadline)
        }
    }

    @ViewBuilder
    private var reflectionSection: some View {
        Section {
            if reflectionLocked {
                JournalGate()
                    .listRowInsets(EdgeInsets())
            } else if !privateDataLoaded {
                if let error {
                    Text(error).foregroundStyle(.red).accessibilityIdentifier("WeeklyReviewLoadError")
                    Button("Try again") { loadPrivateData() }
                } else {
                    ProgressView()
                }
            } else if let existingReview {
                Text(existingReview.text)
                    .accessibilityIdentifier("WeeklyReviewText")
                if let intention = existingReview.nextIntention, !intention.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next week").font(.subheadline.weight(.semibold))
                        Text(intention)
                    }
                }
            } else {
                composer
            }
        } header: { Text("Your reflection") } footer: {
            if privateDataLoaded && existingReview == nil && !reflectionLocked {
                Text("Drafts stay on this device until you save or discard them.")
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 16) {
            JournalStorageWarning()
            if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("WeeklyReviewSaveError") }
            VStack(alignment: .leading, spacing: 4) {
                Text("How was this week?").font(.subheadline.weight(.semibold))
                TextField("One reflection on the week…", text: Binding(
                    get: { draft?.text ?? "" },
                    set: { draft?.text = $0 }
                ), axis: .vertical)
                .lineLimit(4...10)
                .disabled(committed)
                .accessibilityLabel("This week's reflection")
                .accessibilityIdentifier("WeeklyReviewInput")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Next week (optional)").font(.subheadline.weight(.semibold))
                TextField("One intention for next week…", text: Binding(
                    get: { draft?.tomorrowIntention ?? "" },
                    set: { draft?.tomorrowIntention = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(2...6)
                .disabled(committed)
                .accessibilityLabel("Next week's intention")
                .accessibilityIdentifier("WeeklyReviewIntentionInput")
            }
            Button("Save weekly review") { save() }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .accessibilityIdentifier("SaveWeeklyReview")
        }
    }

    /// Reads repository/draft-store content. Never runs while the journal
    /// lock is engaged: this is the boundary that keeps mood counts,
    /// answer/note/retro counts, an existing review, and any recovered
    /// draft text from reaching the view before authentication.
    private func loadPrivateData() {
        guard !lock.isLocked else { return }
        do {
            activity = try repository.activitySummary(in: weekInterval)
            existingReview = try repository.weeklyReview(weekStart: weekStart)?.primary
            if existingReview != nil {
                requiresUnlock = true
            } else if draft == nil {
                if let recovered = try drafts.drafts(kind: .weeklyReview).first(where: { $0.context.periodKey == periodKey }) {
                    draft = recovered
                    requiresUnlock = recovered.containsPrivateContent
                } else {
                    draft = JournalDraft(kind: .weeklyReview, context: .init(civilDay: CivilDay(date: weekStart), periodKey: periodKey))
                    requiresUnlock = false
                }
            }
            privateDataLoaded = true
            error = nil
        } catch {
            self.error = String(localized: "Could not load your weekly review. Try again.")
        }
    }

    private func persistDraft() {
        guard let draft, !finished, !committed else { return }
        do {
            // Cleared text removes the file, so nothing blank resurfaces as "unsaved".
            if draft.containsPrivateContent { try drafts.save(draft) } else { try drafts.delete(id: draft.id) }
        } catch { self.error = String(localized: "Could not save this draft. Keep this screen open and try again.") }
    }

    private func save() {
        guard let draft, !reflectionLocked else { return }
        do {
            if !committed {
                try drafts.save(draft)
                // `recordID: draft.id` makes the saved entry's identity match the
                // draft's, so `draft.id` is always the right key to re-fetch by,
                // including on a cleanup-only retry below where committed is
                // already true and no new receipt is produced this call.
                // The draft's civil day is the week as captured when the draft
                // was created, in that zone, so a recovered draft keeps its week.
                _ = try repository.saveWeeklyReview(text: draft.text, nextIntention: draft.tomorrowIntention,
                                                    weekStart: draft.context.civilDay.start, timeZone: draft.context.civilDay.timeZone, recordID: draft.id)
                committed = true
            }
            try drafts.delete(id: draft.id)
            existingReview = try repository.entry(id: draft.id)
            requiresUnlock = true
            finished = true
            haptics.play(.success)
        } catch {
            self.error = committed
                ? String(localized: "Review saved. Could not remove its draft. Tap Save to retry cleanup.")
                : String(localized: "Could not save your weekly review. Your writing is still here. Try again.")
        }
    }
}
