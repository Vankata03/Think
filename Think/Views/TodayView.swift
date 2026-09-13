//
//  TodayView.swift
//  Think
//

import Combine
import SwiftUI
import SwiftData

/// The day's practice at a glance. Today owns no unsaved text: every
/// answer is captured, resumed, and saved by `JournalEditor`, which is
/// handed an immutable draft context at the moment the sheet opens. The
/// view itself only reads — and every read of saved journal content is
/// gated by `JournalLock` before anything private reaches the screen.
struct TodayView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(FavoritesStore.self) private var favorites
    @Environment(AppIntentRouter.self) private var router
    @Environment(JournalRepository.self) private var repository
    @Environment(JournalDraftStore.self) private var drafts
    @Environment(JournalLock.self) private var lock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.haptics) private var haptics
    @Environment(\.scenePhase) private var scenePhase

    /// Wall clock, refreshed each minute and on foreground/time changes.
    /// The civil day and practice derive from it, so a midnight spent idle
    /// on this screen still rolls the question over.
    @State private var now = Date.now
    @State private var day = CivilDay.today()
    @State private var practice = ContentLibrary.dailyPractice()

    @State private var todaysAnswer: DailySelection<JournalRepository.EntrySnapshot>?
    @State private var todaysRetro: DailySelection<JournalRepository.RetroSnapshot>?
    @State private var carriedIntention: String?
    @State private var journalError: String?
    @State private var draftError: String?

    /// The draft handed to the editor sheet. Its context is frozen when
    /// the sheet opens; a day change underneath does not rewrite it.
    @State private var answerEditor: JournalDraft?
    @State private var showingShareCard = false
    @State private var showingRetro = false
    @State private var showingStreakCalendar = false
    @State private var appeared = false

    private enum NextAction { case answer, move, retro, focus, none }

    private static let activityOrder: [PracticeActivityKind] = [.answer, .move, .retro, .note, .focus, .path]

    private var quote: Quote { practice.quote }
    private var isEvening: Bool { Calendar.current.component(.hour, from: now) >= 20 }
    private var activities: Set<PracticeActivityKind> { progress.activities(on: now) }
    private var moveDone: Bool { progress.isMoveCompleted(practiceID: practice.id, at: now) }
    private var stacksVertically: Bool { dynamicTypeSize.isAccessibilitySize }

    /// Whether an answer exists today, for choosing the next action only.
    /// The progress ledger is not journal content, so it may inform this
    /// while locked; the saved text itself never shows without unlocking.
    private var answeredToday: Bool { todaysAnswer != nil || activities.contains(.answer) }
    private var retroWrittenToday: Bool { todaysRetro != nil || activities.contains(.retro) }
    private var showsRetroCard: Bool { isEvening || retroWrittenToday }

    private var nextAction: NextAction {
        if !answeredToday { return .answer }
        if !moveDone { return .move }
        if isEvening && !retroWrittenToday { return .retro }
        if !activities.contains(.focus) { return .focus }
        return .none
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
                            .transition(ThinkMotion.stateTransition(reduceMotion: reduceMotion))
                    }
                    sectionHeader("Training log", detail: "today")
                    activityLog
                    statsRow
                    if nextAction == .focus {
                        focusPrompt
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 110)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared || reduceMotion ? 0 : 16)
                .animation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion), value: showsRetroCard)
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
                    .accessibilityIdentifier("OpenJournal")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    streakBadge
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .onAppear {
                refreshClock(.now)
                reloadJournal()
                withAnimation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion)) {
                    appeared = true
                }
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
                refreshClock(date)
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                refreshClock(.now)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                refreshClock(.now)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    refreshClock(.now)
                    reloadJournal()
                }
            }
            .onChange(of: day) { _, _ in reloadJournal() }
            .onChange(of: lock.isLocked) { _, _ in reloadJournal() }
            .onChange(of: repository.revision) { _, _ in reloadJournal() }
            .sheet(item: $answerEditor) { draft in
                JournalEditor(draft: draft, notice: draftError)
            }
        }
    }

    // MARK: - Header

    private var ritualHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Today's practice")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)

            if let carriedIntention, !carriedIntention.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.footnote)
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Carried from yesterday")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(carriedIntention)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 4)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("CarriedIntention")
            }
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

    // MARK: - Quote and move

    /// Keeping a line is a quiet act: the fill change and the selection
    /// haptic are the whole feedback. No bounce, no particles.
    private var favoriteButton: some View {
        let isFavorite = favorites.isFavorite(quote)

        return Button {
            haptics.play(.selection)
            withAnimation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion)) {
                _ = favorites.toggle(quote)
            }
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.bordered)
        .tint(Color.accessibleAccent(for: colorScheme))
        .accessibilityLabel(isFavorite
                            ? String(localized: "Remove from saved lines")
                            : String(localized: "Save this line"))
        .accessibilityIdentifier("FavoriteQuote")
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

            adaptiveRow {
                HStack(spacing: 12) {
                    favoriteButton
                    if let attribution = quote.attribution {
                        Text(attribution)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Button {
                    haptics.play(.selection)
                    showingShareCard = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .tint(Color.accessibleAccent(for: colorScheme))
                .accessibilityIdentifier("ShareQuote")
            }

            NavigationLink {
                PracticeDetailView(practiceID: practice.id, version: practice.version)
            } label: {
                Label("About this practice", systemImage: "text.quote")
                    .font(.footnote.weight(.medium))
            }
            .tint(Color.accessibleAccent(for: colorScheme))
            .accessibilityIdentifier("PracticeSource")

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Label("Today's move", systemImage: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(practice.action)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                moveToggle
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

    /// Marking the move is reversible on purpose: a tap made by mistake,
    /// or a day that turned out differently, can be taken back.
    private var moveToggle: some View {
        let done = moveDone
        return actionButton(
            done ? "Done — undo" : "Mark the move done",
            systemImage: done ? "checkmark.circle.fill" : "circle",
            prominent: !done && nextAction == .move
        ) {
            haptics.play(done ? .selection : .success)
            withAnimation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion)) {
                progress.setMoveCompleted(!done, practiceID: practice.id, at: .now)
            }
        }
        .accessibilityLabel(done ? String(localized: "Today's move done. Undo") : String(localized: "Mark today's move done"))
        .accessibilityIdentifier("TodaysMoveToggle")
    }

    // MARK: - Question of the day

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                "Question of the day",
                detail: todaysAnswer == nil ? "1 minute" : "answered"
            )

            JournalStorageWarning()

            Text(practice.question)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let journalError {
                errorRow(journalError, identifier: "TodayJournalError") { reloadJournal() }
            }
            if let draftError {
                errorRow(draftError, identifier: "TodayDraftError") { openAnswerEditor() }
            }

            if lock.isLocked {
                lockedAnswerState
                    .transition(ThinkMotion.stateTransition(reduceMotion: reduceMotion))
            } else if let selection = todaysAnswer {
                answeredState(selection)
                    .transition(ThinkMotion.stateTransition(reduceMotion: reduceMotion))
            } else {
                writeAnswerButton(prominent: nextAction == .answer)
                    .transition(ThinkMotion.stateTransition(reduceMotion: reduceMotion))
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.separator.opacity(0.6), lineWidth: 1)
        }
        .animation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion), value: todaysAnswer?.primary.recordID)
        .animation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion), value: lock.isLocked)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("QuestionOfTheDayCard")
    }

    /// Locked: nothing saved is read or shown. Writing stays open through
    /// a blank draft — no repository or draft lookup happens on this path.
    private var lockedAnswerState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Journal locked", systemImage: "lock.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Unlock to see whether you have answered today. Writing never needs the lock.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            adaptiveRow {
                Button {
                    Task { _ = await lock.authenticate() }
                } label: {
                    Label("Unlock to read", systemImage: "lock.open")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.accessibleAccent(for: colorScheme))
                .disabled(!lock.canAuthenticate)
                .accessibilityIdentifier("UnlockToRead")

                writeAnswerButton(prominent: false)
            }
            if !lock.canAuthenticate {
                Text(lock.availability.settingSubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func writeAnswerButton(prominent: Bool) -> some View {
        actionButton("Write answer", systemImage: "square.and.pencil", prominent: prominent) {
            haptics.play(.selection)
            openAnswerEditor()
        }
        .accessibilityIdentifier("WriteDailyAnswer")
    }

    /// Saved text stays collapsed behind an explicit read. The detail view
    /// re-checks the lock itself, so nothing private renders on this card.
    private func answeredState(_ selection: DailySelection<JournalRepository.EntrySnapshot>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Answered", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
                .accessibilityIdentifier("DailyQuestionAnswered")
            Text(selection.primary.date.formatted(date: .omitted, time: .shortened))
                .font(.footnote)
                .foregroundStyle(.secondary)
            if selection.hasConflicts {
                Text("\(selection.all.count) versions were written for today. All are kept.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            NavigationLink {
                answerDestination(selection)
            } label: {
                Label(selection.hasConflicts ? "Read answers" : "Read answer", systemImage: "book")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.accessibleAccent(for: colorScheme))
            .accessibilityIdentifier("ReadDailyAnswer")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func answerDestination(_ selection: DailySelection<JournalRepository.EntrySnapshot>) -> some View {
        if !selection.hasConflicts, let id = selection.primary.recordID {
            JournalEntryDetailView(recordID: id)
        } else {
            JournalDayVariantsView(day: selection.primary.day, records: .answers(selection.all))
        }
    }

    // MARK: - Retrospective

    private var retroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                "Evening retrospective",
                detail: todaysRetro == nil ? "2 minutes" : "written"
            )

            if lock.isLocked {
                Text("Unlock to see today's retrospective. You can still begin one now.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                actionButton("Begin retrospective", systemImage: "moon.stars", prominent: nextAction == .retro) {
                    haptics.play(.selection)
                    showingRetro = true
                }
                .accessibilityIdentifier("BeginRetrospective")
            } else if let selection = todaysRetro {
                VStack(alignment: .leading, spacing: 12) {
                    retroSummaryRow("checkmark.circle", selection.primary.wentWell)
                    retroSummaryRow("arrow.up.circle", selection.primary.improve)
                    retroSummaryRow("sunrise", selection.primary.tomorrow)
                    if selection.hasConflicts {
                        Text("\(selection.all.count) versions were written for today. All are kept.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(spacing: 8) {
                    NavigationLink {
                        retroDestination(selection)
                    } label: {
                        Label("Read retrospective", systemImage: "book")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accessibleAccent(for: colorScheme))
                    .accessibilityIdentifier("ReadRetrospective")
                    Button {
                        haptics.play(.selection)
                        showingRetro = true
                    } label: {
                        Label("Edit retrospective", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accessibleAccent(for: colorScheme))
                    .accessibilityIdentifier("EditRetrospective")
                }
            } else {
                Text("How was the day? Close it honestly before it closes on you.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                actionButton("Begin retrospective", systemImage: "moon.stars", prominent: nextAction == .retro) {
                    haptics.play(.selection)
                    showingRetro = true
                }
                .accessibilityIdentifier("BeginRetrospective")
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
    private func retroDestination(_ selection: DailySelection<JournalRepository.RetroSnapshot>) -> some View {
        if !selection.hasConflicts, let id = selection.primary.recordID {
            JournalRetroDetailView(recordID: id)
        } else {
            JournalDayVariantsView(day: selection.primary.day, records: .retros(selection.all))
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
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Training log

    /// Named activities from the progress ledger. Opening the app records
    /// nothing, so an empty day reads as empty rather than as one of four.
    private var activityLog: some View {
        let done = activities
        return VStack(alignment: .leading, spacing: 12) {
            Text(done.isEmpty
                 ? String(localized: "Nothing logged yet today.")
                 : String(localized: "\(done.count) logged today"))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: stacksVertically ? 260 : 150), spacing: 10, alignment: .leading)],
                      alignment: .leading, spacing: 10) {
                ForEach(Self.activityOrder, id: \.self) { kind in
                    activityChip(kind, done: done.contains(kind))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.separator.opacity(0.6), lineWidth: 1)
        }
        .accessibilityIdentifier("ActivityLog")
    }

    private func activityChip(_ kind: PracticeActivityKind, done: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.green : Color.secondary)
            Text(activityLabel(kind))
                .font(.subheadline)
                .foregroundStyle(done ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? String(localized: "done") : String(localized: "not yet"))
        .accessibilityIdentifier("Activity.\(kind.rawValue)")
    }

    private func activityLabel(_ kind: PracticeActivityKind) -> String {
        switch kind {
        case .answer: String(localized: "Answered the question")
        case .note: String(localized: "Wrote a note")
        case .retro: String(localized: "Retrospective")
        case .move: String(localized: "Today's move")
        case .path: String(localized: "Path step")
        case .focus: String(localized: "Focus session")
        }
    }

    private var statsRow: some View {
        adaptiveRow {
            metricTile(
                value: "\(progress.focusSessionsToday)",
                label: String(localized: "Focus sessions today"),
                systemImage: "timer",
                hint: String(localized: "Opens Focus")
            ) { router.selectedTab = .focus }
            .accessibilityIdentifier("FocusMetric")
            metricTile(
                value: progress.pathCompletedDays > 0
                    ? String(localized: "Day \(progress.pathCompletedDays)")
                    : String(localized: "Not started"),
                label: PathLibrary.deepFocus.name,
                systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                hint: String(localized: "Opens Paths")
            ) { router.selectedTab = .paths }
            .accessibilityIdentifier("PathMetric")
        }
        .accessibilityIdentifier("TrainingLog")
    }

    /// Shown only once answer, move, and (in the evening) retro are done,
    /// so the day has a single obvious next step at any time.
    private var focusPrompt: some View {
        actionButton("Start a focus session", systemImage: "timer", prominent: true) {
            haptics.play(.selection)
            router.selectedTab = .focus
        }
        .accessibilityIdentifier("StartFocusFromToday")
    }

    // MARK: - Building blocks

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

    /// Side by side at regular sizes, stacked at accessibility sizes.
    private func adaptiveRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let layout = stacksVertically
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return layout { content() }
    }

    /// One action per card; only the day's next step is prominent.
    @ViewBuilder
    private func actionButton(_ title: LocalizedStringKey, systemImage: String, prominent: Bool,
                              action: @escaping () -> Void) -> some View {
        if prominent {
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(Color.prominentButtonForeground(for: colorScheme))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color("AccentColor"))
        } else {
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.accessibleAccent(for: colorScheme))
        }
    }

    private func errorRow(_ message: String, identifier: String, retry: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(identifier)
            Button("Try again", action: retry)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("\(identifier)Retry")
        }
    }

    private func metricTile(value: String, label: String, systemImage: String, hint: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(hint)
    }

    // MARK: - State

    /// Recomputes the civil day and practice from the clock. Only a real
    /// day or zone change replaces them, so the practice never flickers.
    private func refreshClock(_ date: Date) {
        now = date
        let current = CivilDay.today(now: date)
        guard current != day else { return }
        day = current
        practice = ContentLibrary.dailyPractice(for: date)
    }

    /// The only journal read on this screen. Locked means no read at all;
    /// a failed read clears stale snapshots and leaves a retryable error.
    private func reloadJournal() {
        guard !lock.isLocked else {
            todaysAnswer = nil
            todaysRetro = nil
            carriedIntention = nil
            journalError = nil
            return
        }
        do {
            todaysAnswer = try repository.answer(for: day)
            todaysRetro = try repository.retro(for: day)
            carriedIntention = try repository.carriedIntention(for: day)
            journalError = nil
        } catch {
            todaysAnswer = nil
            todaysRetro = nil
            carriedIntention = nil
            journalError = String(localized: "Your journal could not be read. Nothing was changed.")
        }
    }

    /// Captures today's context once and hands it to the editor. Locked:
    /// a blank draft, with no lookup of saved text or unsaved drafts.
    /// Unlocked: resume the day's answer draft if one exists. Unreadable
    /// draft files are reported but never block writing: a fresh draft has
    /// its own identity, so it cannot overwrite the file that failed to read.
    private func openAnswerEditor() {
        let context = JournalDraft.Context(civilDay: day, practiceID: practice.id, promptSnapshot: practice.question)
        guard !lock.isLocked else {
            answerEditor = JournalDraft(kind: .answer, context: context)
            return
        }
        do {
            let listing = try drafts.listing(kind: .answer)
            let pending = listing.drafts.first { $0.context.practiceID == practice.id && $0.context.civilDay.key == day.key }
            draftError = listing.unreadableCount > 0
                ? String(localized: "An unsaved draft could not be read. It was left untouched; check Drafts in Journal.")
                : nil
            answerEditor = pending ?? JournalDraft(kind: .answer, context: context)
        } catch {
            draftError = String(localized: "Unsaved drafts could not be checked. Your writing here starts fresh; earlier drafts were left untouched.")
            answerEditor = JournalDraft(kind: .answer, context: context)
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: JournalEntry.self, DailyRetro.self, FocusSessionMetadata.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return TodayView()
        .environment(ProgressStore())
        .environment(FavoritesStore(defaults: .standard))
        .environment(AppIntentRouter.shared)
        .environment(JournalLock(authenticator: UnavailableJournalAuthenticator()))
        .environment(JournalRepository(modelContext: ModelContext(container), storage: .emergencyInMemory))
        .environment(JournalDraftStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("TodayPreviewDrafts", isDirectory: true)))
        .environment(PracticePreferencesStore())
        .modelContainer(container)
}
