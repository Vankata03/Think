//
//  PomodoroLiveActivity.swift
//  ThinkWidgets
//

import ActivityKit
import SwiftUI
import WidgetKit

nonisolated enum PomodoroLiveActivityPresentation {
    static func title(for state: PomodoroActivityAttributes.ContentState) -> String {
        state.phase == .work ? String(localized: "Deep work") : String(localized: "Break")
    }

    @MainActor static func symbol(for state: PomodoroActivityAttributes.ContentState) -> String {
        state.phase == .work ? ThinkSymbol.focus : ThinkSymbol.breakPhase
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
                        .padding(.leading, ThinkSpacing.s)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerText(for: presentationState(for: context))
                        .font(.title2.weight(.medium))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .padding(.trailing, ThinkSpacing.s)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: ThinkSpacing.s) {
                        intentionText(for: presentationState(for: context))
                        progressBar(for: presentationState(for: context))
                    }
                    .padding(.horizontal, ThinkSpacing.xl)
                    .padding(.top, ThinkSpacing.s)
                    .padding(.bottom, ThinkSpacing.s)
                }
            } compactLeading: {
                Image(systemName: PomodoroLiveActivityPresentation.symbol(for: presentationState(for: context)))
            } compactTrailing: {
                timerText(for: presentationState(for: context))
                    .monospacedDigit()
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: ThinkSymbol.focus)
            }
        }
    }

    private func presentationState(
        for context: ActivityViewContext<PomodoroActivityAttributes>
    ) -> PomodoroActivityAttributes.ContentState {
        context.state.presentationState(isStale: context.isStale)
    }

    private func lockScreenView(for state: PomodoroActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: ThinkSpacing.m) {
            HStack {
                Label(
                    PomodoroLiveActivityPresentation.title(for: state),
                    systemImage: PomodoroLiveActivityPresentation.symbol(for: state)
                )
                    .font(.headline)
                Spacer()
                timerText(for: state)
                    .font(.title.weight(.medium))
                    .fontDesign(.rounded)
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
            accent: state.phase == .work ? ThinkColor.accent : ThinkColor.success
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
                .padding(.horizontal, ThinkSpacing.xs)

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

private enum PreviewState {
    static var work: PomodoroActivityAttributes.ContentState {
        .init(
            phase: .work,
            startDate: .now,
            endDate: .now.addingTimeInterval(25 * 60),
            intention: "Write the first section"
        )
    }

    static var rest: PomodoroActivityAttributes.ContentState {
        .init(phase: .rest, startDate: .now, endDate: .now.addingTimeInterval(5 * 60))
    }
}

#Preview(
    "Lock screen",
    as: .content,
    using: PomodoroActivityAttributes()
) {
    PomodoroLiveActivity()
} contentStates: {
    PreviewState.work
    PreviewState.rest
}

#Preview(
    "Island expanded",
    as: .dynamicIsland(.expanded),
    using: PomodoroActivityAttributes()
) {
    PomodoroLiveActivity()
} contentStates: {
    PreviewState.work
    PreviewState.rest
}
