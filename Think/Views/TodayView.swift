//
//  TodayView.swift
//  Think
//

import Combine
import SwiftData
import SwiftUI

/// Today walks the person through the ritual (`design/today.md`): the day
/// arc, the daily line, one panel for the act that is next, and a section
/// for the acts done or later. Today owns no unsaved text: answers and
/// retros are written in `JournalEditor`, and saved journal content is only
/// ever shown on the Journal's read detail, behind `JournalLock`.
struct TodayView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(FavoritesStore.self) private var favorites
    @Environment(JournalRepository.self) private var repository
    @Environment(JournalDraftStore.self) private var drafts
    @Environment(JournalLock.self) private var lock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.haptics) private var haptics
    @Environment(\.scenePhase) private var scenePhase

    /// Wall clock, refreshed each minute and on foreground or time changes.
    /// The civil day and practice derive from it, so a midnight spent idle
    /// on this screen still rolls the question over.
    @State private var now = TodayClock.now()
    @State private var day = CivilDay.today(now: TodayClock.now())
    @State private var practice = ContentLibrary.dailyPractice(for: TodayClock.now())

    @State private var todaysAnswer: DailySelection<JournalRepository.EntrySnapshot>?
    @State private var todaysRetro: DailySelection<JournalRepository.RetroSnapshot>?
    @State private var journalError: String?
    @State private var draftError: String?
    @State private var retroError: String?

    /// The answer or retro draft handed to the editor sheet. Its context is
    /// frozen when the sheet opens; a day change underneath does not
    /// rewrite it.
    @State private var editorDraft: JournalDraft?
    @State private var editorNotice: String?
    @State private var openRecord: OpenRecord?
    @State private var showingShareCard = false
    @State private var showingStreakCalendar = false

    @ThinkSpacing.Scaled(ThinkSpacing.s) private var rowSpacing
    @ThinkSpacing.Scaled(ThinkSpacing.m) private var panelSpacing

    /// A written answer or retro pushed onto the Journal's read detail.
    private enum OpenRecord: Hashable {
        case answer(UUID)
        case retro(UUID)
    }

    private var quote: Quote { practice.quote }

    /// Whether an answer or retro exists today. The progress ledger is not
    /// journal content, so it may decide this while locked; the saved text
    /// itself never shows on this screen.
    private var ritual: TodayRitual {
        let activities = progress.activities(on: now)
        return TodayRitual(
            answered: todaysAnswer != nil || activities.contains(.answer),
            moveDone: progress.isMoveCompleted(practiceID: practice.id, at: now),
            retroWritten: todaysRetro != nil || activities.contains(.retro),
            hour: DayArcGeometry.hour(of: now)
        )
    }

    private var stateAnimation: Animation? { ThinkMotion.stateAnimation(reduceMotion: reduceMotion) }

    var body: some View {
        let ritual = ritual
        NavigationStack {
            List {
                Section {
                    DayArcView(hour: ritual.hour, states: ritual.arcStates, now: now)
                        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? ThinkSpacing.l : 0)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .accessibilityIdentifier("TodayDayArc")
                    dailyLine
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    JournalStorageWarning()
                    if let journalError {
                        errorRow(journalError, identifier: "TodayJournalError") { reloadJournal() }
                    }
                    if let draftError {
                        errorRow(draftError, identifier: "TodayDraftError") { openAnswerEditor() }
                    }
                    if let retroError {
                        errorRow(retroError, identifier: "TodayRetroError") { openRetroEditor() }
                    }
                    switch ritual.panel {
                    case .act(let act): nextActPanel(act)
                    case .complete: completeRow
                    }
                }

                Section {
                    ForEach(ritual.otherActs, id: \.self) { act in
                        actRow(act, done: ritual.isDone(act))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .labelStyle(TodayRowLabelStyle())
            // Compact so the next act's button stays above the fold on a
            // 6.1-inch phone with a long `de` move (today.md section 2).
            .listSectionSpacing(.compact)
            .animation(stateAnimation, value: ritual)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbar }
            .navigationDestination(item: $openRecord) { record in
                switch record {
                case .answer(let id): JournalEntryDetailView(recordID: id)
                case .retro(let id): JournalRetroDetailView(recordID: id)
                }
            }
            .onAppear {
                refreshClock(TodayClock.now())
                reloadJournal()
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                refreshClock(TodayClock.now())
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                refreshClock(TodayClock.now())
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                refreshClock(TodayClock.now())
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    refreshClock(TodayClock.now())
                    reloadJournal()
                }
            }
            .onChange(of: day) { _, _ in reloadJournal() }
            .onChange(of: lock.isLocked) { _, _ in reloadJournal() }
            .onChange(of: repository.revision) { _, _ in reloadJournal() }
            .sheet(item: $editorDraft) { draft in
                JournalEditor(draft: draft, notice: editorNotice)
            }
            .sheet(isPresented: $showingShareCard) {
                ShareCardSheet(quote: quote)
            }
            .sheet(isPresented: $showingStreakCalendar) {
                StreakCalendarSheet()
            }
        }
    }

    // MARK: - Toolbar

    /// Bookmark, fixed spacer, streak (design-system 13.3). No leading item.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink {
                SavedLinesView()
            } label: {
                Label("Saved lines", systemImage: ThinkSymbol.savedLine)
            }
            .tint(ThinkColor.label)
            .accessibilityIdentifier("OpenSavedLines")
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            streakItem
        }
    }

    private var streak: StreakPresentation {
        StreakPresentation(
            streak: progress.displayedStreak,
            completedPracticeCount: 0,
            hasPractised: progress.lastCompletedDay != nil
        )
    }

    /// The flame and the numeral in `accentInk` while the streak is alive.
    /// At zero the flame alone, in `secondaryLabel`, titled with the
    /// two-state copy ("Start today." or "Begin again.").
    private var streakItem: some View {
        let count = progress.displayedStreak
        return Button {
            haptics.play(.selection)
            showingStreakCalendar = true
        } label: {
            HStack(spacing: ThinkSpacing.xs) {
                Image(systemName: ThinkSymbol.streak)
                if count > 0 {
                    Text(count, format: .number)
                        .font(.think(.numeral))
                }
            }
            .foregroundStyle(count > 0 ? ThinkColor.accentInk : ThinkColor.secondaryLabel)
        }
        .accessibilityLabel(count > 0 ? String(localized: "\(count) day streak") : streak.streakText)
        .accessibilityHint(Text("Shows your streak calendar"))
        .accessibilityIdentifier("TodayStreak")
    }

    // MARK: - Daily line

    /// The line, then its attribution with save and share. No link anywhere
    /// on the line: practice detail left the app.
    private var dailyLine: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            Text(quote.text)
                .font(.think(.lineLarge))
                .foregroundStyle(ThinkColor.label)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("TodayDailyLine")
            let layout =
                dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: rowSpacing))
                : AnyLayout(HStackLayout(alignment: .center, spacing: rowSpacing))
            layout {
                if let attribution = quote.attribution {
                    Text(attribution)
                        .font(.think(.caption))
                        .foregroundStyle(ThinkColor.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                HStack(spacing: rowSpacing) {
                    saveButton
                    Button("Share", systemImage: ThinkSymbol.share) {
                        haptics.play(.selection)
                        showingShareCard = true
                    }
                    .accessibilityIdentifier("ShareQuote")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .font(.body)
                .foregroundStyle(ThinkColor.label)
            }
        }
        .padding(.vertical, ThinkSpacing.xs)
    }

    /// Keeping a line is a quiet act: the fill change and the selection
    /// haptic are the whole feedback.
    private var saveButton: some View {
        let isSaved = favorites.isFavorite(quote)
        return Button(
            isSaved ? String(localized: "Remove from saved lines") : String(localized: "Save this line"),
            systemImage: isSaved ? "\(ThinkSymbol.savedLine).fill" : ThinkSymbol.savedLine
        ) {
            haptics.play(.selection)
            withAnimation(stateAnimation) {
                _ = favorites.toggle(quote)
            }
        }
        .contentTransition(.symbolEffect(.replace))
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityIdentifier("FavoriteQuote")
    }

    // MARK: - Next act

    /// The panel for the act that is next, with the screen's one primary.
    private func nextActPanel(_ act: TodayRitual.Act) -> some View {
        VStack(alignment: .leading, spacing: panelSpacing) {
            Label {
                Text("Next · \(Text(actName(act)))")
            } icon: {
                Image(systemName: symbol(act))
            }
            .font(.think(.caption))
            .fontWeight(.semibold)
            .foregroundStyle(ThinkColor.accentInk)

            Text(panelText(act))
                .font(act == .question ? .think(.question) : .think(.body))
                .foregroundStyle(ThinkColor.label)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                perform(act)
            } label: {
                Label(buttonTitle(act), systemImage: symbol(act))
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
            }
            .thinkButton(.primary)
            // At AX sizes the title alone fills the row and wraps between
            // words; a capsule around wrapped text would balloon.
            .labelStyle(.adaptiveTitleOnly(dynamicTypeSize.isAccessibilitySize))
            .buttonBorderShape(dynamicTypeSize.isAccessibilitySize ? .roundedRectangle : .automatic)
            .controlSize(dynamicTypeSize.isAccessibilitySize ? .regular : .large)
            .accessibilityIdentifier(buttonIdentifier(act))
        }
        .padding(.vertical, ThinkSpacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("NextActPanel")
    }

    private var completeRow: some View {
        Label {
            VStack(alignment: .leading, spacing: ThinkSpacing.xs) {
                Text("Practice complete")
                    .font(.think(.heading))
                    .foregroundStyle(ThinkColor.label)
                Text("Day \(progress.displayedStreak) of your streak.")
                    .font(.think(.secondary))
                    .foregroundStyle(ThinkColor.secondaryLabel)
            }
        } icon: {
            Image(systemName: ThinkSymbol.done)
                .foregroundStyle(ThinkColor.success)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("PracticeComplete")
    }

    // MARK: - Acts done or later

    /// Done answer and retro rows push the read detail; the move's done row
    /// is a fact, not a door, with a trailing-swipe Undo for a mistaken tap.
    /// Row text never shows journal content.
    @ViewBuilder
    private func actRow(_ act: TodayRitual.Act, done: Bool) -> some View {
        if !done {
            Label {
                Text(laterText(act))
                    .foregroundStyle(ThinkColor.secondaryLabel)
            } icon: {
                Image(systemName: symbol(act))
                    .foregroundStyle(ThinkColor.secondaryLabel)
            }
            .accessibilityIdentifier("Act.\(identifier(act)).later")
        } else if act == .move {
            doneLabel(act)
                .accessibilityIdentifier("Act.move.done")
                .swipeActions(edge: .trailing) {
                    Button("Undo", systemImage: "arrow.uturn.backward") {
                        haptics.play(.selection)
                        withAnimation(stateAnimation) {
                            progress.setMoveCompleted(false, practiceID: practice.id, at: TodayClock.now())
                        }
                    }
                    .accessibilityIdentifier("UndoMove")
                }
        } else {
            Button {
                open(act)
            } label: {
                HStack {
                    doneLabel(act)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(ThinkColor.tertiaryLabel)
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Act.\(identifier(act)).done")
        }
    }

    private func doneLabel(_ act: TodayRitual.Act) -> some View {
        Label {
            Text(doneText(act))
                .foregroundStyle(ThinkColor.label)
        } icon: {
            Image(systemName: ThinkSymbol.done)
                .foregroundStyle(ThinkColor.success)
        }
    }

    // MARK: - Copy

    private func symbol(_ act: TodayRitual.Act) -> String {
        switch act {
        case .question: ThinkSymbol.question
        case .move: ThinkSymbol.move
        case .retro: ThinkSymbol.retro
        }
    }

    private func actName(_ act: TodayRitual.Act) -> LocalizedStringResource {
        switch act {
        case .question: "Question of the day"
        case .move: "Today's move"
        case .retro: "Evening retro"
        }
    }

    private func panelText(_ act: TodayRitual.Act) -> String {
        switch act {
        case .question: practice.question
        case .move: practice.action
        case .retro: String(localized: "Close the day. Two honest minutes.")
        }
    }

    private func buttonTitle(_ act: TodayRitual.Act) -> LocalizedStringKey {
        switch act {
        case .question: "Write answer"
        case .move: "Done"
        case .retro: "Begin retro"
        }
    }

    private func buttonIdentifier(_ act: TodayRitual.Act) -> String {
        switch act {
        case .question: "WriteDailyAnswer"
        case .move: "MarkMoveDone"
        case .retro: "BeginRetro"
        }
    }

    private func identifier(_ act: TodayRitual.Act) -> String {
        switch act {
        case .question: "question"
        case .move: "move"
        case .retro: "retro"
        }
    }

    private func doneText(_ act: TodayRitual.Act) -> LocalizedStringKey {
        switch act {
        case .question: "Question answered"
        case .move: "Move done"
        case .retro: "Retro written"
        }
    }

    private func laterText(_ act: TodayRitual.Act) -> String {
        switch act {
        case .question: String(localized: "Question of the day")
        case .move: String(localized: "Today's move · after the question")
        case .retro: String(localized: "Evening retro · \(retroOpening.formatted(.dateTime.hour().minute()))")
        }
    }

    /// 20:00 today, written in the device's clock format.
    private var retroOpening: Date {
        Calendar.current.date(bySettingHour: Int(TodayRitual.retroOpeningHour), minute: 0, second: 0, of: now) ?? now
    }

    private func errorRow(_ message: String, identifier: String, retry: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            Text(message)
                .font(.think(.caption))
                .foregroundStyle(ThinkColor.destructive)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(identifier)
            Button("Try again", action: retry)
                .thinkButton(.secondary)
                .controlSize(.small)
                .accessibilityIdentifier("\(identifier)Retry")
        }
    }

    // MARK: - Actions

    private func perform(_ act: TodayRitual.Act) {
        switch act {
        case .question:
            haptics.play(.selection)
            openAnswerEditor()
        case .move:
            haptics.play(.success)
            withAnimation(stateAnimation) {
                progress.setMoveCompleted(true, practiceID: practice.id, at: TodayClock.now())
            }
        case .retro:
            haptics.play(.selection)
            openRetroEditor()
        }
    }

    /// Opening an answer or retro asks Face ID first; the detail re-checks
    /// the lock itself, so nothing private renders without it.
    private func open(_ act: TodayRitual.Act) {
        haptics.play(.selection)
        Task {
            if lock.isLocked {
                guard await lock.authenticate() else { return }
            }
            reloadJournal()
            switch act {
            case .question:
                if let id = todaysAnswer?.primary.recordID { openRecord = .answer(id) }
            case .retro:
                if let id = todaysRetro?.primary.recordID { openRecord = .retro(id) }
            case .move:
                break
            }
        }
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
            journalError = nil
            return
        }
        do {
            todaysAnswer = try repository.answer(for: day)
            todaysRetro = try repository.retro(for: day)
            journalError = nil
        } catch {
            todaysAnswer = nil
            todaysRetro = nil
            journalError = String(localized: "Your journal could not be read. Nothing was changed.")
        }
    }

    /// Captures today's context once and hands the answer to the editor.
    private func openAnswerEditor() {
        let opened = JournalEditorOpening.answer(
            day: day, practiceID: practice.id, prompt: practice.question,
            locked: lock.isLocked, drafts: drafts)
        draftError = opened.notice
        editorNotice = opened.notice
        editorDraft = opened.draft
    }

    /// Opens a new retro, or an unsaved one resumed. A retro that cannot be
    /// read opens nothing.
    private func openRetroEditor() {
        do {
            let opened = try JournalEditorOpening.retro(
                day: day, practiceID: practice.id, prompt: practice.question,
                locked: lock.isLocked, repository: repository, drafts: drafts)
            retroError = nil
            editorNotice = opened.notice
            editorDraft = opened.draft
        } catch {
            retroError = String(localized: "Today's retrospective could not be read. Nothing was changed.")
        }
    }
}

/// Today's clock. UI tests pin the hour with `-ui-today-hour <hour>` so a
/// whole day can be walked: `-ui-today-hour 20.5` is 20:30 today.
enum TodayClock {
    private static let pinnedHour: Double? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-ui-testing"),
            let index = arguments.firstIndex(of: "-ui-today-hour"),
            arguments.indices.contains(index + 1)
        else { return nil }
        return Double(arguments[index + 1])
    }()

    static func now() -> Date {
        let date = Date.now
        guard let pinnedHour else { return date }
        let minutes = Int((pinnedHour * 60).rounded())
        return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: date) ?? date
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
        .environment(JournalLock(authenticator: UnavailableJournalAuthenticator()))
        .environment(JournalRepository(modelContext: ModelContext(container), storage: .emergencyInMemory))
        .environment(JournalDraftStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("TodayPreviewDrafts", isDirectory: true)))
        .modelContainer(container)
}

/// Today's row labels: the system label at regular sizes; at accessibility
/// sizes the symbol stacks above its text, so "Today's move · after the
/// question" keeps the full row width and wraps between words
/// (design-system 3.2).
private struct TodayRowLabelStyle: LabelStyle {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeBody(configuration: Configuration) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: ThinkSpacing.xs) {
                configuration.icon
                configuration.title
            }
        } else {
            Label(configuration)
        }
    }
}

private struct AdaptiveTitleOnlyLabelStyle: LabelStyle {
    var titleOnly: Bool

    func makeBody(configuration: Configuration) -> some View {
        if titleOnly {
            configuration.title
        } else {
            Label(configuration)
        }
    }
}

extension LabelStyle where Self == AdaptiveTitleOnlyLabelStyle {
    fileprivate static func adaptiveTitleOnly(_ titleOnly: Bool) -> AdaptiveTitleOnlyLabelStyle {
        AdaptiveTitleOnlyLabelStyle(titleOnly: titleOnly)
    }
}
