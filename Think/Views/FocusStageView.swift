//
//  FocusStageView.swift
//  Think
//

import AppIntents
import SwiftUI

/// Focus: one centred column on the plain background, with the controls in
/// a bottom safe-area bar so they never scroll away (design/focus.md
/// section 2). The one screen that is a stage rather than a `List`.
struct FocusStageView: View {
    @Environment(PomodoroTimer.self) private var timer
    @Environment(JournalLock.self) private var journalLock
    @Environment(JournalRepository.self) private var repository
    @Environment(\.haptics) private var haptics
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var intentionDraft = ""
    @State private var confirmingEnd = false
    @State private var saveError = false
    @FocusState private var intentionFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ThinkSpacing.xl) {
                    headline
                    if let minutes = timer.sessionDoneMinutes {
                        doneLine(minutes)
                    }
                    arc
                    if timer.isIdle {
                        FocusDurationWheel()
                            .transition(.opacity)
                    }
                    lastSession
                }
                .padding(.horizontal, ThinkSpacing.l)
                .padding(.vertical, ThinkSpacing.l)
                .frame(maxWidth: .infinity)
                .animation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion), value: timer.isIdle)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .background(ThinkColor.background)
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaBar(edge: .bottom) { controls }
            .confirmationDialog("End this session?", isPresented: $confirmingEnd, titleVisibility: .visible) {
                Button("End session", role: .destructive) { endSession() }
            } message: {
                Text("The time you've done so far is kept as partial effort.")
            }
            .alert("Could not save", isPresented: $saveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your timer continues. The intention was not saved with this session.")
            }
            .onAppear {
                timer.resync()
                syncDraft()
            }
            .onChange(of: journalLock.isLocked) { syncDraft() }
            .onChange(of: intentionFocused) { _, focused in
                // Leaving the field is a commit; the keyboard going away
                // must not lose what was typed.
                if !focused { commitIntention() }
            }
            .onChange(of: timer.intention) {
                // Follow the timer (a path step, the end of a work phase)
                // unless someone is typing, where it would fight the field
                // over trimmed whitespace.
                if !intentionFocused { syncDraft() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { timer.resync() }
            }
            .onChange(of: timer.automaticTransitionCount) {
                haptics.play(.success)
            }
        }
    }

    // MARK: Headline

    /// The intention: editable while idle, read-only during a session, and
    /// behind the journal lock while it is locked.
    @ViewBuilder
    private var headline: some View {
        if journalLock.isLocked {
            Button {
                Task { if await journalLock.authenticate() { syncDraft() } }
            } label: {
                Label("Unlock private intention", systemImage: ThinkSymbol.lock)
            }
            .thinkButton(.tertiary)
            .font(.think(.secondary))
            .accessibilityIdentifier("FocusUnlockIntention")
        } else if timer.isIdle {
            intentionField
        } else {
            Text(timer.intention ?? String(localized: "Deep work"))
                .font(.think(.line))
                .foregroundStyle(timer.intention == nil ? ThinkColor.secondaryLabel : ThinkColor.label)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("FocusIntentionText")
        }
    }

    private var intentionField: some View {
        VStack(spacing: ThinkSpacing.s) {
            // The placeholder is a `Text` behind the field so it wraps at
            // accessibility sizes instead of truncating (focus.md section 11).
            ZStack(alignment: .top) {
                if intentionDraft.isEmpty {
                    Text("What are you working on?")
                        .font(.think(.line))
                        .foregroundStyle(ThinkColor.tertiaryLabel)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
                TextField(
                    String(localized: "What are you working on?"),
                    text: intentionBinding,
                    prompt: Text(verbatim: ""),
                    axis: .vertical
                )
                .font(.think(.line))
                .multilineTextAlignment(.center)
                .submitLabel(.done)
                .focused($intentionFocused)
                .accessibilityIdentifier("FocusIntention")
            }
            if intentionDraft.isEmpty, let suggestion = timer.suggestedIntention() {
                Button {
                    haptics.play(.selection)
                    intentionDraft = String(suggestion.prefix(PomodoroTimer.intentionMaxLength))
                    commitIntention()
                } label: {
                    Text(suggestion)
                        .font(.think(.secondary))
                        .multilineTextAlignment(.center)
                }
                .thinkButton(.tertiary)
                .accessibilityLabel(String(localized: "Reuse intention: \(suggestion)"))
                .accessibilityIdentifier("FocusIntentionSuggestion")
            }
        }
    }

    /// Typing only moves the draft. The timer, which persists and pushes a
    /// Live Activity update, is written on Return, on focus loss and at Start.
    private var intentionBinding: Binding<String> {
        Binding(
            get: { intentionDraft },
            set: { text in
                // A vertical field takes Return as a newline; here it is Done.
                let submitted = text.contains("\n")
                let line = text.replacingOccurrences(of: "\n", with: "")
                intentionDraft = String(line.prefix(PomodoroTimer.intentionMaxLength))
                if submitted { intentionFocused = false }
            }
        )
    }

    private func syncDraft() {
        intentionDraft = journalLock.isLocked ? "" : (timer.intention ?? "")
    }

    private func commitIntention() {
        guard !journalLock.isLocked else { return }
        guard timer.intention != PomodoroTimer.normalizedIntention(intentionDraft) else { return }
        timer.setIntention(intentionDraft)
    }

    // MARK: Done line, arc and last session

    private func doneLine(_ minutes: Int) -> some View {
        HStack(spacing: ThinkSpacing.xs) {
            Image(systemName: ThinkSymbol.done)
                .foregroundStyle(ThinkColor.success)
            Text("Session done · \(minutes) min")
                .foregroundStyle(ThinkColor.secondaryLabel)
        }
        .font(.think(.secondary))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("FocusDoneLine")
    }

    private var arc: some View {
        // Idle captions are clock times that move with the minute.
        TimelineView(.everyMinute) { _ in
            let now = Date.now
            let wheel = timer.wheelPreset
            let idle = timer.isIdle
            let workMinutes = idle ? wheel.workMinutes : timer.preset.workMinutes
            let breakMinutes = idle ? wheel.restMinutes : timer.preset.restMinutes
            let remaining = TimeInterval(timer.remainingSeconds)
            let workEnd: Date =
                if idle {
                    now.addingTimeInterval(TimeInterval(workMinutes * 60))
                } else if timer.phase == .work {
                    now.addingTimeInterval(remaining)
                } else {
                    now
                }
            let breakEnd = timer.phase == .rest && !idle
                ? now.addingTimeInterval(remaining)
                : workEnd.addingTimeInterval(TimeInterval(breakMinutes * 60))
            SessionArcView(
                workMinutes: workMinutes,
                breakMinutes: breakMinutes,
                stage: idle ? .idle : (timer.phase == .work ? .work : .rest),
                isPaused: !timer.isRunning,
                phaseProgress: timer.progress,
                countdown: idle ? String(format: "%02d:00", workMinutes) : timer.remainingLabel,
                workEnd: workEnd,
                breakEnd: breakEnd
            )
        }
        .accessibilityIdentifier("FocusTimer")
    }

    /// Plain text, not a link: history lives on Progress.
    @ViewBuilder
    private var lastSession: some View {
        if let record = timer.lastSessionRecord {
            let time = Calendar.current.isDateInToday(record.completedAt)
                ? record.completedAt.formatted(.dateTime.hour().minute())
                : record.completedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
            Text("Last session · \(record.lastSessionMinutes) min · \(time)")
                .font(.think(.secondary))
                .foregroundStyle(ThinkColor.secondaryLabel)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("FocusLastSession")
        }
    }

    // MARK: Controls

    /// Start, Pause or Resume as the one primary, End and Skip beside it.
    /// They stack at accessibility sizes and never leave the bar.
    private var controls: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(spacing: ThinkSpacing.s))
            : AnyLayout(HStackLayout(spacing: ThinkSpacing.s))
        return layout {
            if !timer.isIdle, timer.phase == .work {
                Button {
                    if timer.endAsksFirst {
                        confirmingEnd = true
                    } else {
                        endSession()
                    }
                } label: {
                    Text("End").frame(maxWidth: stacked ? .infinity : nil)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .accessibilityIdentifier("FocusEnd")
            }
            Button(action: primaryAction) {
                Label(primaryTitle, systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                    .frame(minWidth: 96)
                    .frame(maxWidth: stacked ? .infinity : nil)
            }
            .thinkButton(.primary)
            .controlSize(.large)
            .accessibilityIdentifier("FocusPrimary")
            if !timer.isIdle {
                Button {
                    haptics.play(.selection)
                    timer.skipPhase()
                } label: {
                    Text(timer.phase == .rest ? String(localized: "Skip to work") : String(localized: "Skip"))
                        .frame(maxWidth: stacked ? .infinity : nil)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .accessibilityIdentifier("FocusSkip")
            }
        }
        .padding(.horizontal, ThinkSpacing.l)
        .padding(.bottom, ThinkSpacing.s)
        .frame(maxWidth: .infinity)
    }

    private var primaryTitle: String {
        if timer.isRunning { return String(localized: "Pause") }
        return timer.isIdle ? String(localized: "Start") : String(localized: "Resume")
    }

    private func primaryAction() {
        if timer.isRunning {
            haptics.play(.pause)
            timer.pause()
        } else if timer.isIdle {
            // Start can be tapped with the keyboard still up, so the draft
            // has to reach the timer before the session begins.
            commitIntention()
            intentionFocused = false
            haptics.play(.start)
            let donatedPreset = FocusSessionPreset(timer.wheelPreset)
            timer.startFromWheel()
            saveSessionIntention()
            if let donatedPreset {
                Task { try? await StartFocusSessionIntent(preset: donatedPreset).donate() }
            }
        } else {
            haptics.play(.start)
            timer.start()
        }
    }

    /// End records the work done so far as partial effort, as Reset did.
    private func endSession() {
        // The work phase may have finished while the dialog was open.
        guard !timer.isIdle, timer.phase == .work else { return }
        haptics.play(.reset)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { timer.reset() }
    }

    private func saveSessionIntention() {
        guard !journalLock.isLocked, let id = timer.currentSessionID else { return }
        do {
            try repository.upsertSessionMetadata(sessionID: id, intention: timer.intention)
        } catch {
            saveError = true
        }
    }
}

/// Work and break minutes as two system wheels, as in the Clock app's Timers
/// tab (focus.md section 4). Turning either sets the duration at once.
private struct FocusDurationWheel: View {
    @Environment(PomodoroTimer.self) private var timer
    @Environment(\.haptics) private var haptics
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: ThinkSpacing.l))
            : AnyLayout(HStackLayout(spacing: 0))
        layout {
            column(
                String(localized: "Work"),
                values: PomodoroTimer.Preset.wheelWorkMinutes,
                selection: Binding(
                    get: { timer.wheelPreset.workMinutes },
                    set: { select(work: $0, rest: timer.wheelPreset.restMinutes) }
                ),
                unitColor: ThinkColor.accentInk,
                identifier: "FocusWheel.Work"
            )
            column(
                String(localized: "Break"),
                values: PomodoroTimer.Preset.wheelRestMinutes,
                selection: Binding(
                    get: { timer.wheelPreset.restMinutes },
                    set: { select(work: timer.wheelPreset.workMinutes, rest: $0) }
                ),
                unitColor: ThinkColor.success,
                identifier: "FocusWheel.Break"
            )
        }
    }

    private func select(work: Int, rest: Int) {
        guard work != timer.wheelPreset.workMinutes || rest != timer.wheelPreset.restMinutes else { return }
        haptics.play(.selection)
        timer.selectDuration(workMinutes: work, restMinutes: rest)
    }

    private func column(
        _ title: String,
        values: [Int],
        selection: Binding<Int>,
        unitColor: Color,
        identifier: String
    ) -> some View {
        VStack(spacing: ThinkSpacing.xs) {
            Text(title)
                .font(.think(.caption))
                .fontWeight(.semibold)
                .foregroundStyle(ThinkColor.secondaryLabel)
                .accessibilityHidden(true)
            Picker(selection: selection) {
                ForEach(values, id: \.self) { minutes in
                    Text(Self.row(minutes, unitColor: unitColor))
                        .accessibilityLabel(Text("\(minutes) minutes"))
                        .tag(minutes)
                }
            } label: {
                Text(title)
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            .clipped()
            .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity)
    }

    /// "*n* min" with the unit in the column's colour.
    private static func row(_ minutes: Int, unitColor: Color) -> AttributedString {
        var text = AttributedString(localized: "\(minutes) min")
        text.foregroundColor = unitColor
        if let number = text.range(of: minutes.formatted()) {
            text[number].foregroundColor = ThinkColor.label
        }
        return text
    }
}
