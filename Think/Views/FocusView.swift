//
//  FocusView.swift
//  Think
//

import SwiftUI
import AppIntents

private enum FocusSheet: String, Identifiable {
    case focusTip
    case sessionDuration

    var id: String { rawValue }
}

struct FocusView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.haptics) private var haptics
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PomodoroTimer.self) private var timer
    @State private var presentedSheet: FocusSheet?
    @State private var appeared = false

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
                withAnimation(.easeOut(duration: 0.45)) {
                    appeared = true
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    timer.resync()
                }
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
                    Picker("Focus duration", selection: $customFocusMinutes) {
                        ForEach(PomodoroTimer.Preset.customWorkMinutesRange, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .accessibilityIdentifier("FocusCustomWork")

                    Picker("Break duration", selection: $customBreakMinutes) {
                        ForEach(PomodoroTimer.Preset.customRestMinutesRange, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .accessibilityIdentifier("FocusCustomRest")

                    Button {
                        applyCustomDuration()
                    } label: {
                        Label(
                            "Use custom duration",
                            systemImage: timer.preset.isCustom
                                ? "checkmark.circle.fill"
                                : "slider.horizontal.3"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityIdentifier("UseCustomDuration")
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

    private func applyCustomDuration() {
        if !timer.preset.isCustom
            || timer.preset.workMinutes != customFocusMinutes
            || timer.preset.restMinutes != customBreakMinutes {
            haptics.play(.selection)
        }
        guard timer.selectCustom(
            workMinutes: customFocusMinutes,
            restMinutes: customBreakMinutes
        ) else { return }
        dismiss()
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
}
