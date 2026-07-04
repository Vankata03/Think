//
//  PomodoroLiveActivity.swift
//  ThinkWidgets
//

import ActivityKit
import SwiftUI
import WidgetKit

nonisolated enum PomodoroLiveActivityPresentation {
    static func title(for state: PomodoroActivityAttributes.ContentState) -> String {
        state.phase == .work ? "Deep work" : "Break"
    }

    static func symbol(for state: PomodoroActivityAttributes.ContentState) -> String {
        state.phase == .work ? "brain.head.profile" : "cup.and.saucer"
    }
}

struct PomodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            lockScreenView(for: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(
                        PomodoroLiveActivityPresentation.title(for: context.state),
                        systemImage: PomodoroLiveActivityPresentation.symbol(for: context.state)
                    )
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerText(for: context.state)
                        .font(.title2.weight(.medium))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }
            } compactLeading: {
                Image(systemName: PomodoroLiveActivityPresentation.symbol(for: context.state))
            } compactTrailing: {
                timerText(for: context.state)
                    .monospacedDigit()
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }

    private func lockScreenView(for state: PomodoroActivityAttributes.ContentState) -> some View {
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
        .padding()
    }

    private func timerText(for state: PomodoroActivityAttributes.ContentState) -> Text {
        Text(timerInterval: Date.now...max(Date.now, state.endDate), countsDown: true)
    }
}
