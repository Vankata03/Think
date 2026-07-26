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
    case focusNote(PomodoroTimer.FocusNotePrompt)

    var id: String {
        switch self {
        case .focusTip: "focusTip"
        case .sessionDuration: "sessionDuration"
        case .focusNote(let prompt): "focusNote.\(prompt.id)"
        }
    }
}

struct FocusView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.haptics) private var haptics
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PomodoroTimer.self) private var timer
    @Environment(\.modelContext) private var modelContext
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
                        ring
                        focusCue
                        intentionField
                            .padding(.horizontal, 22)
                        controls
                        sessionDurationControl
                            .padding(.horizontal, 22)
                    }
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.97)

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
            .sheet(item: $presentedSheet, onDismiss: clearPendingFocusNote) { sheet in
                switch sheet {
                case .focusTip:
                    FocusTipSheet()
                case .sessionDuration:
                    FocusDurationSheet(timer: timer)
                case .focusNote(let prompt):
                    FocusNoteSheet(prompt: prompt) { note in
                        saveFocusNote(prompt: prompt, note: note)
                    }
                }
            }
            .onAppear {
                timer.resync()
                timer.discardStalePendingFocusNote()
                offerPendingFocusNote()
                intentionDraft = timer.intention ?? ""
                withAnimation(.easeOut(duration: 0.45)) {
                    appeared = true
                }
            }
            .onChange(of: timer.pendingFocusNote) { _, _ in
                offerPendingFocusNote()
            }
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
                    offerPendingFocusNote()
                }
            }
            .onChange(of: timer.automaticTransitionCount) {
                haptics.play(.success)
            }
        }
    }

    private var focusHeader: some View {
        HStack(alignment: .center) {
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

    private var ring: some View {
        ZStack {
            Circle()
                .fill(.regularMaterial)
                .frame(width: 238, height: 238)
                .shadow(
                    color: timer.isRunning ? Color.accentColor.opacity(0.22) : .clear,
                    radius: timer.isRunning ? 34 : 0
                )

            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: 12)
            Circle()
                .trim(from: 0, to: timer.progress)
                .stroke(
                    timer.phase == .work ? Color.accentColor : .green,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: (timer.phase == .work ? Color.accentColor : .green).opacity(0.35),
                    radius: timer.isRunning ? 12 : 4
                )
                .animation(.linear(duration: 0.8), value: timer.progress)
            VStack(spacing: 4) {
                Text(timer.remainingLabel)
                    .font(.system(size: 48, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(timer.phase.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 250, height: 250)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("FocusTimer\(timer.preset == .long ? ".50" : "")")
        .animation(.easeInOut(duration: 0.25), value: timer.isRunning)
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
        guard timer.intention != PomodoroTimer.normalizedIntention(intentionDraft) else { return }
        timer.setIntention(intentionDraft)
    }

    private func offerPendingFocusNote() {
        guard let prompt = timer.pendingFocusNote else { return }
        presentedSheet = .focusNote(prompt)
    }

    /// Any dismissal of the note sheet — Save, Skip, or a swipe — retires
    /// the prompt. Harmless for the other two sheets, which never set one.
    private func clearPendingFocusNote() {
        timer.clearPendingFocusNote()
    }

    /// The finished session already credited the day through
    /// `ProgressStore.recordFocusSession`, so this writes the entry and
    /// nothing else — crediting it again would inflate the practice rail.
    private func saveFocusNote(prompt: PomodoroTimer.FocusNotePrompt, note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(
            JournalEntry(
                date: prompt.completedAt,
                prompt: prompt.intention,
                text: trimmed,
                kind: JournalEntry.kindFocus
            )
        )
        haptics.play(.success)
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button {
                haptics.play(.reset)
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { timer.reset() }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 24, height: 24)
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
                if isManualWorkStart, let donatedPreset {
                    Task {
                        try? await StartFocusSessionIntent(preset: donatedPreset).donate()
                    }
                }
            } label: {
                Label(timer.isRunning ? String(localized: "Pause") : String(localized: "Start"),
                      systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                    .frame(minWidth: 132)
                    .foregroundStyle(prominentButtonForeground)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.accentColor)
            .foregroundStyle(prominentButtonForeground)

            Button {
                haptics.play(.selection)
                timer.skipPhase()
            } label: {
                Image(systemName: "forward.end")
                    .frame(width: 24, height: 24)
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

/// Offered once, right after a work phase that had an intention. Skip is a
/// first-class outcome: the session already counted, and a note that has
/// to be written is a note that stops sessions from being started.
private struct FocusNoteSheet: View {
    let prompt: PomodoroTimer.FocusNotePrompt
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var note = ""

    private var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Session complete")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.accentColor)
                    Text(prompt.intention)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }

                TextField(
                    String(localized: "How did it go?"),
                    text: $note,
                    axis: .vertical
                )
                    .lineLimit(3...6)
                    .padding(14)
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.separator.opacity(0.6), lineWidth: 1)
                    }
                    .accessibilityIdentifier("FocusNoteInput")

                Spacer()
            }
            .padding(20)
            .navigationTitle("After the session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                        .accessibilityIdentifier("SkipFocusNote")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(trimmedNote)
                        dismiss()
                    }
                    .disabled(trimmedNote.isEmpty)
                    .accessibilityIdentifier("SaveFocusNote")
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("FocusNoteSheet")
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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
