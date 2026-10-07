//
//  FocusSessionAccessory.swift
//  Think
//

import SwiftUI

/// The one line the running-session accessory shows beside the countdown
/// (focus.md section 6). The intention is private: it appears only during
/// work and only while the journal is unlocked, in the label as on screen.
enum FocusSessionLine {
    static func text(phase: PomodoroTimer.Phase, intention: String?, journalLocked: Bool) -> String {
        switch phase {
        case .rest:
            return String(localized: "Break")
        case .work:
            if !journalLocked, let intention { return intention }
            return String(localized: "Deep work")
        }
    }

    static func accessibilityLabel(
        phase: PomodoroTimer.Phase,
        intention: String?,
        journalLocked: Bool,
        countdown: String,
        isPaused: Bool
    ) -> String {
        let line = text(phase: phase, intention: intention, journalLocked: journalLocked)
        return isPaused
            ? String(localized: "Focus. Paused, \(countdown) left. \(line)")
            : String(localized: "Focus, \(countdown) left. \(line)")
    }
}

extension FocusSessionRecord {
    /// The minutes the stage's "Last session" line shows: the planned length
    /// of a completed session, the work done in an ended one (at least one).
    var lastSessionMinutes: Int {
        guard !isCompleted, let actualActiveSeconds else { return durationMinutes }
        return max(1, actualActiveSeconds / 60)
    }
}

/// A running or paused session, shown above the tab bar while another tab is
/// selected, the way Music shows the current track. Tapping it opens Focus;
/// the trailing button pauses and resumes.
struct FocusSessionAccessory: View {
    @Environment(PomodoroTimer.self) private var timer
    @Environment(JournalLock.self) private var journalLock
    @Environment(AppIntentRouter.self) private var router
    @Environment(\.haptics) private var haptics

    var body: some View {
        HStack(spacing: ThinkSpacing.m) {
            Button {
                router.selectedTab = .focus
            } label: {
                HStack(spacing: ThinkSpacing.s) {
                    Image(systemName: ThinkSymbol.focus)
                        .font(.subheadline)
                        .foregroundStyle(timer.phase == .rest ? ThinkColor.success : ThinkColor.accentInk)
                    Text(timer.remainingLabel)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(ThinkColor.label)
                    Text(FocusSessionLine.text(phase: timer.phase, intention: intention, journalLocked: journalLock.isLocked))
                        .font(.think(.secondary))
                        .foregroundStyle(ThinkColor.secondaryLabel)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(FocusSessionLine.accessibilityLabel(
                phase: timer.phase,
                intention: intention,
                journalLocked: journalLock.isLocked,
                countdown: timer.remainingLabel,
                isPaused: !timer.isRunning
            ))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("FocusAccessory")

            Button(
                timer.isRunning ? String(localized: "Pause") : String(localized: "Resume"),
                systemImage: timer.isRunning ? "pause.fill" : "play.fill"
            ) {
                if timer.isRunning {
                    haptics.play(.pause)
                    timer.pause()
                } else {
                    haptics.play(.start)
                    timer.start()
                }
            }
            .labelStyle(.iconOnly)
            .font(.body)
            .foregroundStyle(ThinkColor.label)
            .accessibilityIdentifier("FocusAccessoryToggle")
        }
        .padding(.horizontal, ThinkSpacing.l)
    }

    private var intention: String? {
        #if os(iOS)
        timer.intention
        #else
        nil
        #endif
    }
}
