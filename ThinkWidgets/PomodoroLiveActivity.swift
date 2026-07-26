//
//  PomodoroLiveActivity.swift
//  ThinkWidgets
//

import ActivityKit
import SwiftUI
import WidgetKit

private enum LiveActivityStyle {
    static let work = Color(red: 1.0, green: 0.894, blue: 0.361)
    static let rest = Color.green

    static func accent(for state: PomodoroActivityAttributes.ContentState) -> Color {
        state.phase == .work ? work : rest
    }
}

nonisolated enum PomodoroLiveActivityPresentation {
    static func title(for state: PomodoroActivityAttributes.ContentState) -> String {
        state.phase == .work ? String(localized: "Deep work") : String(localized: "Break")
    }

    static func symbol(for state: PomodoroActivityAttributes.ContentState) -> String {
        state.phase == .work ? "brain.head.profile" : "cup.and.saucer"
    }
}

struct PomodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            lockScreenView(for: presentationState(for: context))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(
                        PomodoroLiveActivityPresentation.title(for: presentationState(for: context)),
                        systemImage: PomodoroLiveActivityPresentation.symbol(for: presentationState(for: context))
                    )
                        .font(.headline)
                        .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerText(for: presentationState(for: context))
                        .font(.title2.weight(.medium))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        intentionText(for: presentationState(for: context))
                        progressBar(for: presentationState(for: context))
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                }
            } compactLeading: {
                Image(systemName: PomodoroLiveActivityPresentation.symbol(for: presentationState(for: context)))
            } compactTrailing: {
                timerText(for: presentationState(for: context))
                    .monospacedDigit()
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }

    private func presentationState(
        for context: ActivityViewContext<PomodoroActivityAttributes>
    ) -> PomodoroActivityAttributes.ContentState {
        context.state.presentationState(isStale: context.isStale)
    }

    private func lockScreenView(for state: PomodoroActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    PomodoroLiveActivityPresentation.title(for: state),
                    systemImage: PomodoroLiveActivityPresentation.symbol(for: state)
                )
                    .font(.headline)
                Spacer()
                timerText(for: state)
                    .font(.title.weight(.medium))
                    .monospacedDigit()
            }

            intentionText(for: state)

            progressBar(for: state)
        }
        .padding()
    }

    /// One line, never wrapped: the intention is context for the
    /// countdown, and a two-line activity pushes the progress bar around.
    @ViewBuilder
    private func intentionText(
        for state: PomodoroActivityAttributes.ContentState
    ) -> some View {
        if let intention = state.intention, !intention.isEmpty {
            Text(intention)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func timerText(for state: PomodoroActivityAttributes.ContentState) -> Text {
        Text(timerInterval: Date.now...max(Date.now, state.endDate), countsDown: true)
    }

    private func progressBar(for state: PomodoroActivityAttributes.ContentState) -> some View {
        SystemTimedPomodoroProgressBar(
            state: state,
            accent: LiveActivityStyle.accent(for: state)
        )
        .accessibilityLabel("Pomodoro progress")
        .accessibilityValue(String(localized: "\(Int((state.progress() * 100).rounded())) percent"))
    }
}

private struct SystemTimedPomodoroProgressBar: View {
    let state: PomodoroActivityAttributes.ContentState
    let accent: Color

    var body: some View {
        ZStack {
            ProgressView(timerInterval: state.progressRange, countsDown: false)
                .progressViewStyle(.linear)
                .tint(accent)
                .labelsHidden()
                .scaleEffect(y: 1.7)
                .padding(.horizontal, 4)

            HStack {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                Spacer()
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(height: 12)
    }
}
