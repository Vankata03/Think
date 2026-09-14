//
//  FocusView.swift
//  Think
//

import SwiftUI
import SwiftData
import AppIntents

private enum FocusSheet: Identifiable {
    case focusTip
    case sessionDuration

    var id: String {
        switch self {
        case .focusTip: "focusTip"
        case .sessionDuration: "sessionDuration"
        }
    }
}

struct FocusView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.haptics) private var haptics
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PomodoroTimer.self) private var timer
    @Environment(JournalLock.self) private var journalLock
    @Environment(JournalRepository.self) private var repository
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var saveError = false
    @State private var presentedSheet: FocusSheet?
    @State private var appeared = false
    @State private var intentionDraft = ""
    @FocusState private var intentionFocused: Bool

    private var sessionQuote: Quote { ContentLibrary.dailyQuote() }
    private var prominentButtonForeground: Color {
        .prominentButtonForeground(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    focusHeader
                        .padding(.horizontal, 22)
                        .padding(.top, 18)

                    Spacer(minLength: 42)

                    VStack(spacing: 28) {
                        FocusCountdownView()
                        if !timer.isRunning { focusCue }
                        protectedIntentionField
                            .padding(.horizontal, 22)
                        controls
                        if let session = timer.lastSessionRecord {
                            NavigationLink { FocusSessionDetailView(session: session) } label: {
                                Label("Reflect on your session", systemImage: "square.and.pencil")
                            }
                            .padding(.horizontal, 22)
                        }
                        sessionDurationControl
                            .padding(.horizontal, 22)
                    }
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(reduceMotion || appeared ? 1 : 0.97)

                    Spacer(minLength: 64)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        presentedSheet = .focusTip
                    } label: {
                        Image(systemName: "lightbulb")
                    }
                    .accessibilityLabel("Tip: silence distractions")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        FocusStatsView()
                    } label: {
                        Image(systemName: "chart.bar.xaxis")
                    }
                    .accessibilityLabel("Focus stats")
                    .accessibilityIdentifier("FocusStats")
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            // One presentation channel for all three sheets: two `.sheet`
            // modifiers on the same view can race, and a work phase can
            // finish while the duration sheet is open.
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .focusTip:
                    FocusTipSheet()
                case .sessionDuration:
                    FocusDurationSheet(timer: timer)
                }
            }
            .onAppear {
                timer.resync()
                timer.discardStalePendingFocusNote()
                if !journalLock.isLocked { intentionDraft = timer.intention ?? "" }
                withAnimation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion)) {
                    appeared = true
                }
            }
            .onChange(of: journalLock.isLocked) { _, locked in
                intentionDraft = locked ? "" : (timer.intention ?? "")
            }
            .alert("Could not save", isPresented: $saveError) {
                Button("OK", role: .cancel) { }
            } message: { Text("Your timer continues. Try saving your reflection again.") }
            .onChange(of: intentionFocused) { _, focused in
                // Leaving the field is a commit; the keyboard going away
                // must not lose what was typed.
                if !focused {
                    commitIntention()
                }
            }
            .onChange(of: timer.intention) { _, intention in
                // Only follow the timer when it clears the intention at
                // the end of a work phase. Following it while typing would
                // fight the field over trimmed whitespace.
                if intention == nil {
                    intentionDraft = ""
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    timer.resync()
                    timer.discardStalePendingFocusNote()
                }
            }
            .onChange(of: timer.automaticTransitionCount) {
                haptics.play(.success)
            }
        }
    }

    private var focusHeader: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center))
        return layout {
            VStack(alignment: .leading, spacing: 4) {
                Text(timer.phase == .work
                     ? String(localized: "Deep work")
                     : String(localized: "Break"))
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                Text(timer.isRunning
                     ? String(localized: "Session in progress")
                     : String(localized: "Ready when you are"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(progress.focusSessionsToday) today")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
        }
    }

    private var focusCue: some View {
        VStack(spacing: 8) {
            Text("Focus cue")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Color.accentColor)
            Text("\u{201C}\(sessionQuote.text)\u{201D}")
                .font(.system(.callout, design: .serif))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(.horizontal, 34)
    }

    /// Optional by construction: Start works untouched, and nothing here
    /// blocks or delays it. The session gains a name only if someone wants
    /// to give it one.
    @ViewBuilder
    private var protectedIntentionField: some View {
        if journalLock.isLocked {
            Button {
                Task { if await journalLock.authenticate() { intentionDraft = timer.intention ?? "" } }
            } label: { Label("Unlock private intention", systemImage: "lock") }
        } else { intentionField }
    }

    private var intentionField: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "target")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                TextField(String(localized: "What are you working on?"), text: intentionBinding)
                    .font(.subheadline)
                    .submitLabel(.done)
                    .focused($intentionFocused)
                    .onSubmit { commitIntention() }
                    .accessibilityIdentifier("FocusIntention")
                if !intentionDraft.isEmpty {
                    Button {
                        haptics.play(.selection)
                        setIntention("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear intention")
                }
            }

            if intentionDraft.isEmpty, let suggestion = timer.suggestedIntention() {
                Button {
                    haptics.play(.selection)
                    setIntention(suggestion)
                } label: {
                    Label(suggestion, systemImage: "arrow.uturn.backward")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Reuse intention: \(suggestion)"))
                .accessibilityIdentifier("FocusIntentionSuggestion")
            }
        }
        .padding(14)
        .frame(maxWidth: 360, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.separator).opacity(0.6), lineWidth: 1)
        }
    }

    /// Typing only moves the draft. The timer — which persists and pushes
    /// a Live Activity update — is written on submit, on focus loss, and
    /// when a session starts, not once per keystroke.
    private var intentionBinding: Binding<String> {
        Binding(
            get: { intentionDraft },
            set: { text in
                // Capped here rather than rejected on save, so the limit is
                // felt as the field simply stopping.
                intentionDraft = String(text.prefix(PomodoroTimer.intentionMaxLength))
            }
        )
    }

    /// For the clear button and the reuse suggestion, where the tap is the
    /// whole gesture and there is no later submit to wait for.
    private func setIntention(_ text: String) {
        intentionDraft = String(text.prefix(PomodoroTimer.intentionMaxLength))
        commitIntention()
    }

    private func commitIntention() {
        guard !journalLock.isLocked else { return }
        guard timer.intention != PomodoroTimer.normalizedIntention(intentionDraft) else { return }
        timer.setIntention(intentionDraft)
    }

    private func saveSessionIntention() {
        guard !journalLock.isLocked, let id = timer.currentSessionID else { return }
        do {
            let existing = try repository.sessionMetadata(sessionID: id)
            try repository.upsertSessionMetadata(sessionID: id, intention: timer.intention,
                outcome: existing?.outcome.flatMap(FocusOutcome.init(rawValue:)),
                energy: existing?.energy.flatMap(EnergyLevel.init(rawValue:)),
                closingNoteRecordID: existing?.closingNoteRecordID)
        } catch { saveError = true }
    }

    private var controls: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 16))
            : AnyLayout(HStackLayout(spacing: 16))
        return layout {
            Button {
                haptics.play(.reset)
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { timer.reset() }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(minWidth: 20, minHeight: 24)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel("Reset timer")

            Button {
                // Start can be tapped with the keyboard still up, so the
                // draft has to reach the timer before the session begins.
                commitIntention()
                let isManualStart = !timer.isRunning
                let isManualWorkStart = isManualStart && timer.phase == .work
                let donatedPreset = FocusSessionPreset(timer.preset)
                haptics.play(isManualStart ? .start : .pause)
                timer.toggle()
                if isManualWorkStart { saveSessionIntention() }
                if isManualWorkStart, let donatedPreset {
                    Task {
                        try? await StartFocusSessionIntent(preset: donatedPreset).donate()
                    }
                }
            } label: {
                Label(timer.isRunning ? String(localized: "Pause") : String(localized: "Start"),
                      systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 100)
                    .foregroundStyle(prominentButtonForeground)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color("AccentColor"))
            .foregroundStyle(prominentButtonForeground)

            Button {
                haptics.play(.selection)
                timer.skipPhase()
            } label: {
                Image(systemName: "forward.end")
                    .frame(minWidth: 20, minHeight: 24)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel(timer.phase == .work
                                ? String(localized: "Skip to break")
                                : String(localized: "Skip to work"))
        }
    }

    private var sessionDurationControl: some View {
        Button {
            haptics.play(.selection)
            presentedSheet = .sessionDuration
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("Session duration")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    DurationPairSummary(
                        focusMinutes: timer.preset.workMinutes,
                        breakMinutes: timer.preset.restMinutes
                    )
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: 360, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(.separator).opacity(0.6), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Session duration")
        .accessibilityValue(
            durationAccessibilityValue(
                focusMinutes: timer.preset.workMinutes,
                breakMinutes: timer.preset.restMinutes
            )
        )
        .accessibilityIdentifier("FocusDurationSummary")
    }
}

private struct DurationPairSummary: View {
    let focusMinutes: Int
    let breakMinutes: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                durationLabel("Focus", minutes: focusMinutes, color: .accentColor)
                Text("·")
                    .foregroundStyle(.tertiary)
                durationLabel("Break", minutes: breakMinutes, color: .green)
            }

            VStack(alignment: .leading, spacing: 4) {
                durationLabel("Focus", minutes: focusMinutes, color: .accentColor)
                durationLabel("Break", minutes: breakMinutes, color: .green)
            }
        }
        .font(.subheadline)
    }

    private func durationLabel(
        _ title: LocalizedStringKey,
        minutes: Int,
        color: Color
    ) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .foregroundStyle(.secondary)
            Text(localizedMinutes(minutes))
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct FocusDurationSheet: View {
    let timer: PomodoroTimer

    @Environment(\.dismiss) private var dismiss
    @Environment(\.haptics) private var haptics
    @State private var customFocusMinutes: Int
    @State private var customBreakMinutes: Int

    init(timer: PomodoroTimer) {
        self.timer = timer
        _customFocusMinutes = State(initialValue: timer.customPreset.workMinutes)
        _customBreakMinutes = State(initialValue: timer.customPreset.restMinutes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Presets") {
                    ForEach(PomodoroTimer.Preset.all, id: \.self) { preset in
                        presetButton(preset)
                    }
                }

                Section("Custom") {
                    Picker("Focus duration", selection: customFocusSelection) {
                        ForEach(PomodoroTimer.Preset.customWorkMinutesRange, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .accessibilityIdentifier("FocusCustomWork")

                    Picker("Break duration", selection: customBreakSelection) {
                        ForEach(PomodoroTimer.Preset.customRestMinutesRange, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .accessibilityIdentifier("FocusCustomRest")
                }
            }
            .navigationTitle("Session duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .accessibilityIdentifier("FocusDurationSheet")
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func presetButton(_ preset: PomodoroTimer.Preset) -> some View {
        let isSelected = preset == timer.preset

        return Button {
            if !isSelected {
                haptics.play(.selection)
            }
            timer.select(preset)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                DurationPairSummary(
                    focusMinutes: preset.workMinutes,
                    breakMinutes: preset.restMinutes
                )
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            durationAccessibilityValue(
                focusMinutes: preset.workMinutes,
                breakMinutes: preset.restMinutes
            )
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("FocusPreset.\(preset.workMinutes)")
    }

    private var customFocusSelection: Binding<Int> {
        Binding(
            get: { customFocusMinutes },
            set: { minutes in
                customFocusMinutes = minutes
                applyCustomDuration(
                    focusMinutes: minutes,
                    breakMinutes: timer.customPreset.restMinutes
                )
            }
        )
    }

    private var customBreakSelection: Binding<Int> {
        Binding(
            get: { customBreakMinutes },
            set: { minutes in
                customBreakMinutes = minutes
                applyCustomDuration(
                    focusMinutes: timer.customPreset.workMinutes,
                    breakMinutes: minutes
                )
            }
        )
    }

    private func applyCustomDuration(focusMinutes: Int, breakMinutes: Int) {
        if !timer.preset.isCustom
            || timer.preset.workMinutes != focusMinutes
            || timer.preset.restMinutes != breakMinutes {
            haptics.play(.selection)
        }
        _ = timer.selectCustom(
            workMinutes: focusMinutes,
            restMinutes: breakMinutes
        )
    }
}

private func localizedMinutes(_ minutes: Int) -> String {
    String(localized: "\(minutes) min")
}

private func durationAccessibilityValue(focusMinutes: Int, breakMinutes: Int) -> String {
    let focus = String(localized: "Focus")
    let rest = String(localized: "Break")
    return "\(focus): \(localizedMinutes(focusMinutes)); \(rest): \(localizedMinutes(breakMinutes))"
}

/// Countdown alone observes the ticking fields. Parent observes semantic state only.
private struct FocusCountdownView: View {
    @Environment(PomodoroTimer.self) private var timer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var countdownSize = 48.0

    var body: some View {
        VStack(spacing: 12) {
            if !dynamicTypeSize.isAccessibilitySize {
                ZStack {
                    Circle().fill(.regularMaterial)
                    Circle().stroke(Color(.tertiarySystemFill), lineWidth: 10)
                    Circle().trim(from: 0, to: timer.progress)
                        .stroke(timer.phase == .work ? Color.accentColor : .green,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .linear(duration: 0.8), value: timer.progress)
                    labels
                }
                .frame(maxWidth: 250)
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 30)
            } else { labels.padding(.horizontal, 20) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("FocusTimer\(timer.preset == .long ? ".50" : "")")
    }
    private var labels: some View {
        VStack(spacing: 4) {
            Text(timer.remainingLabel)
                .font(.system(size: countdownSize, weight: .medium, design: .rounded))
                .monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
            Text(timer.phase.label).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

private struct FocusTipSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Apps can't turn on a Focus for you — Apple keeps that under your control. Set it up once and your phone goes quiet automatically whenever you start a session here.")
                        .font(.subheadline)
                }

                Section("Create a Deep Work Focus") {
                    tipRow(number: 1, text: "Open Settings, then Focus.")
                    tipRow(number: 2, text: "Tap + and choose Custom. Name it Deep Work.")
                    tipRow(number: 3, text: "Allow notifications only from people who genuinely need you.")
                }

                Section("Turn it on automatically") {
                    tipRow(number: 1, text: "Open the Shortcuts app, then Automation.")
                    tipRow(number: 2, text: "Tap +, choose App, pick Think, select Is Opened.")
                    tipRow(number: 3, text: "Add the action Set Focus, choose Deep Work, and set Run Immediately.")
                }
            }
            .navigationTitle("Silence distractions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func tipRow(number: Int, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.medium))
                .frame(width: 22, height: 22)
                .background(Color(.tertiarySystemFill), in: Circle())
            Text(text)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    FocusView()
        .environment(ProgressStore())
        .environment(PomodoroTimer())
        .modelContainer(for: [JournalEntry.self, DailyRetro.self], inMemory: true)
}
