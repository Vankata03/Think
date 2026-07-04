//
//  FocusView.swift
//  Think
//

import SwiftUI

struct FocusView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.scenePhase) private var scenePhase
    @State private var timer = PomodoroTimer()
    @State private var showingFocusTip = false

    private var sessionQuote: Quote { ContentLibrary.dailyQuote() }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                ring

                Text("\u{201C}\(sessionQuote.text)\u{201D}")
                    .font(.subheadline)
                    .fontDesign(.serif)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                controls
                presets

                Spacer()
            }
            .padding()
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingFocusTip = true
                    } label: {
                        Image(systemName: "moon")
                    }
                    .accessibilityLabel("Silence distractions")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(progress.focusSessionsToday) today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $showingFocusTip) {
                FocusTipSheet()
            }
            .onAppear {
                timer.onWorkSessionComplete = { progress.recordFocusSession() }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    timer.resync()
                }
            }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: 10)
            Circle()
                .trim(from: 0, to: timer.progress)
                .stroke(
                    timer.phase == .work ? Color.accentColor : Color.green,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: timer.progress)
            VStack(spacing: 4) {
                Text(timer.remainingLabel)
                    .font(.system(size: 44, weight: .medium, design: .rounded))
                    .monospacedDigit()
                Text(timer.phase.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 220, height: 220)
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button {
                timer.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Reset timer")

            Button {
                timer.toggle()
            } label: {
                Label(timer.isRunning ? "Pause" : "Start",
                      systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                    .frame(minWidth: 120)
                    .foregroundStyle(.black)
            }
            .buttonStyle(.glassProminent)

            Button {
                timer.skipPhase()
            } label: {
                Image(systemName: "forward.end")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(timer.phase == .work ? "Skip to break" : "Skip to work")
        }
    }

    private var presets: some View {
        HStack(spacing: 10) {
            ForEach(PomodoroTimer.Preset.all, id: \.workMinutes) { preset in
                Button(preset.label) {
                    timer.select(preset)
                }
                .font(.subheadline.weight(preset == timer.preset ? .medium : .regular))
                .buttonStyle(.bordered)
                .tint(preset == timer.preset ? .accentColor : .secondary)
            }
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

    private func tipRow(number: Int, text: String) -> some View {
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
}
