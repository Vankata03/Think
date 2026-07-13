//
//  FocusView.swift
//  Think
//

import SwiftUI
import AppIntents

struct FocusView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.haptics) private var haptics
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PomodoroTimer.self) private var timer
    @State private var showingFocusTip = false
    @State private var appeared = false

    private var sessionQuote: Quote { ContentLibrary.dailyQuote() }
    private var prominentButtonForeground: Color {
        .prominentButtonForeground(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                focusHeader
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                Spacer(minLength: 42)

                VStack(spacing: 28) {
                    ring
                    focusCue
                    controls
                    presets
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.97)

                Spacer(minLength: 64)
            }
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingFocusTip = true
                    } label: {
                        Image(systemName: "lightbulb")
                    }
                    .accessibilityLabel("Tip: silence distractions")
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .sheet(isPresented: $showingFocusTip) {
                FocusTipSheet()
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
                if isManualWorkStart {
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

    private var presets: some View {
        HStack(spacing: 10) {
            ForEach(PomodoroTimer.Preset.all, id: \.workMinutes) { preset in
                Button(preset.label) {
                    if preset != timer.preset {
                        haptics.play(.selection)
                    }
                    timer.select(preset)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(presetForeground(for: preset))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(presetBackground(for: preset), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(presetStroke(for: preset), lineWidth: 1)
                }
                .contentShape(Capsule())
                .buttonStyle(.plain)
                .accessibilityLabel(preset.label)
                .accessibilityIdentifier("FocusPreset.\(preset.workMinutes)")
            }
        }
    }

    private func presetForeground(for preset: PomodoroTimer.Preset) -> Color {
        preset == timer.preset ? .accentColor : .secondary
    }

    private func presetBackground(for preset: PomodoroTimer.Preset) -> Color {
        preset == timer.preset ? Color.accentColor.opacity(0.16) : Color(.secondarySystemGroupedBackground)
    }

    private func presetStroke(for preset: PomodoroTimer.Preset) -> Color {
        preset == timer.preset ? Color.accentColor.opacity(0.28) : Color(.separator).opacity(0.6)
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
}
