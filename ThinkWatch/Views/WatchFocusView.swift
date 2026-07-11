//
//  WatchFocusView.swift
//  ThinkWatchApp
//

import SwiftUI

struct WatchFocusView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.scenePhase) private var scenePhase
    @State private var timer = PomodoroTimer(systemSideEffectsEnabled: false)

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ring
                controls
                presets
                Text("\(progress.focusSessionsToday) today")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
        }
        .navigationTitle("Focus")
        .onAppear {
            timer.onWorkSessionComplete = {
                progress.recordFocusSession()
            }
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
            ForEach(PomodoroTimer.Preset.all, id: \.workMinutes) { preset in
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
}

#Preview {
    NavigationStack {
        WatchFocusView()
            .environment(ProgressStore(defaults: .standard))
    }
}
