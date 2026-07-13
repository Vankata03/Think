//
//  WatchFocusView.swift
//  ThinkWatchApp
//

import SwiftUI

struct WatchFocusView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PomodoroTimer.self) private var timer

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ring
                controls
                presets
                customDurationControls
                Text("\(progress.focusSessionsToday) today")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
        }
        .navigationTitle("Focus")
        .onAppear {
            timer.resync()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                timer.resync()
            }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.22), lineWidth: 9)
            Circle()
                .trim(from: 0, to: timer.progress)
                .stroke(timer.phase == .work ? .yellow : .green, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.6), value: timer.progress)
            VStack(spacing: 3) {
                Text(timer.remainingLabel)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.72)
                Text(timer.phase.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 132, height: 132)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(timer.phase == .work
                            ? String(localized: "Deep work timer")
                            : String(localized: "Break timer"))
        .accessibilityValue(timer.remainingLabel)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Button {
                timer.toggle()
            } label: {
                Label(
                    timer.isRunning ? String(localized: "Pause") : String(localized: "Start"),
                    systemImage: timer.isRunning ? "pause.fill" : "play.fill"
                )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)

            HStack(spacing: 8) {
                Button {
                    timer.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Reset timer")

                Button {
                    timer.skipPhase()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(timer.phase == .work
                                    ? String(localized: "Skip to break")
                                    : String(localized: "Skip to work"))
            }
        }
    }

    private var presets: some View {
        HStack(spacing: 8) {
            ForEach(PomodoroTimer.Preset.all, id: \.self) { preset in
                Button {
                    timer.select(preset)
                } label: {
                    Text(preset.label)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(preset == timer.preset ? .yellow : .secondary)
                .accessibilityAddTraits(preset == timer.preset ? .isSelected : [])
            }
        }
        .accessibilityLabel("Focus preset")
    }

    private var customDurationControls: some View {
        VStack(spacing: 6) {
            Text("Custom")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(timer.preset.isCustom ? .yellow : .secondary)

            HStack(spacing: 8) {
                customDurationPicker(
                    title: "Work duration",
                    selection: customWorkMinutes,
                    range: PomodoroTimer.Preset.customWorkMinutesRange,
                    identifier: "FocusCustomWork"
                )

                customDurationPicker(
                    title: "Break duration",
                    selection: customRestMinutes,
                    range: PomodoroTimer.Preset.customRestMinutesRange,
                    identifier: "FocusCustomRest"
                )
            }
        }
    }

    private var customWorkMinutes: Binding<Int> {
        Binding(
            get: { timer.customPreset.workMinutes },
            set: {
                timer.selectCustom(
                    workMinutes: $0,
                    restMinutes: timer.customPreset.restMinutes
                )
            }
        )
    }

    private var customRestMinutes: Binding<Int> {
        Binding(
            get: { timer.customPreset.restMinutes },
            set: {
                timer.selectCustom(
                    workMinutes: timer.customPreset.workMinutes,
                    restMinutes: $0
                )
            }
        )
    }

    private func customDurationPicker(
        title: LocalizedStringKey,
        selection: Binding<Int>,
        range: ClosedRange<Int>,
        identifier: String
    ) -> some View {
        Picker(title, selection: selection) {
            ForEach(range, id: \.self) { value in
                Text("\(value) min").tag(value)
            }
        }
        .pickerStyle(.navigationLink)
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    NavigationStack {
        WatchFocusView()
            .environment(ProgressStore(defaults: .standard))
            .environment(PomodoroTimer(systemSideEffectsEnabled: false))
    }
}
