//
//  OnboardingView.swift
//  Think
//

import SwiftUI

/// First-launch introduction: what the practice is, the daily line
/// notification opt-in, and the first path. Shown once, gated by
/// `Onboarding.completedKey`.
enum Onboarding {
    static let completedKey = "hasCompletedOnboarding"
}

struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.haptics) private var haptics
    @AppStorage(Onboarding.completedKey) private var completed = false
    @AppStorage(DailyQuoteNotifier.enabledKey) private var dailyLineEnabled = false
    @AppStorage(DailyQuoteNotifier.minutesKey) private var dailyLineMinutes = DailyQuoteNotifier.defaultMinutes
    @AppStorage(RetroReminder.enabledKey) private var retroReminderEnabled = false
    @AppStorage(RetroReminder.minutesKey) private var retroReminderMinutes = RetroReminder.defaultMinutes

    @State private var page = 0

    private var dailyLineTime: Binding<Date> {
        $dailyLineMinutes.timeOfDay
    }

    private var retroReminderTime: Binding<Date> {
        $retroReminderMinutes.timeOfDay
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                pageDots
                Spacer()
                if page < 2 {
                    Button("Skip") {
                        finish()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Group {
                switch page {
                case 0: practicePage
                case 1: notificationPage
                default: pathPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .id(page)

            Button {
                advance()
            } label: {
                Text(page < 2
                     ? String(localized: "Continue")
                     : String(localized: "Begin practice"))
                    .font(.headline)
                    .foregroundStyle(Color.prominentButtonForeground(for: colorScheme))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.accentColor)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .animation(.easeInOut(duration: 0.3), value: page)
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Capsule()
                    .fill(index == page ? Color.accentColor : Color(.tertiarySystemFill))
                    .frame(width: index == page ? 22 : 7, height: 7)
            }
        }
        .accessibilityLabel("Step \(page + 1) of 3")
    }

    private var practicePage: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            Text("\u{201C}")
                .font(.system(size: 88, design: .serif).weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(height: 56, alignment: .top)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text("A gym for your mind")
                    .font(.largeTitle.bold())
                Text("Think is a short daily practice, not a feed. A few honest minutes, every day.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                practiceRow(icon: "text.quote", title: "Read the daily line", detail: "One idea worth carrying all day.")
                practiceRow(icon: "pencil.line", title: "Answer one question", detail: "A few private sentences. Stored on your device only.")
                practiceRow(icon: "timer", title: "Train your attention", detail: "A path step or a focus session. Your streak grows.")
                practiceRow(icon: "moon.stars", title: "Close the day", detail: "A two-minute evening retrospective: what went well, what's next.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.separator.opacity(0.6), lineWidth: 1)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private func practiceRow(icon: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var notificationPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text("Bookend your day")
                    .font(.largeTitle.bold())
                Text("A line to open the morning, a two-minute retrospective to close the evening. Both optional, both at times you choose.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                Toggle(isOn: $dailyLineEnabled) {
                    onboardingLabel("Daily line notification", systemImage: "bell")
                }
                .tint(.accentColor)
                .padding(.vertical, 10)

                if dailyLineEnabled {
                    Divider()
                    DatePicker(selection: dailyLineTime, displayedComponents: .hourAndMinute) {
                        onboardingLabel("Time", systemImage: "clock")
                    }
                    .tint(.accentColor)
                    .padding(.vertical, 10)
                }

                Divider()

                Toggle(isOn: $retroReminderEnabled) {
                    onboardingLabel("Evening retrospective reminder", systemImage: "moon.stars")
                }
                .tint(.accentColor)
                .padding(.vertical, 10)

                if retroReminderEnabled {
                    Divider()
                    DatePicker(selection: retroReminderTime, displayedComponents: .hourAndMinute) {
                        onboardingLabel("Time", systemImage: "clock")
                    }
                    .tint(.accentColor)
                    .padding(.top, 10)
                }
            }
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.separator.opacity(0.6), lineWidth: 1)
            }
            .animation(.default, value: dailyLineEnabled)
            .animation(.default, value: retroReminderEnabled)

            Text("You can change this anytime in Profile.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private var pathPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            Image(systemName: PathLibrary.deepFocus.icon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text("Start with \(PathLibrary.deepFocus.name)")
                    .font(.largeTitle.bold())
                Text("\(PathLibrary.deepFocus.tagline). One short lesson and one concrete task per day, ten minutes at most.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if let firstStep = PathLibrary.deepFocus.steps.first {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Day 1 · \(firstStep.title)")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(firstStep.task)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.separator.opacity(0.6), lineWidth: 1)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private func onboardingLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label {
            Text(title)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
        }
        .font(.subheadline)
    }

    private func advance() {
        haptics.play(.selection)
        if page < 2 {
            page += 1
        } else {
            finish()
        }
    }

    private func finish() {
        if dailyLineEnabled {
            DailyQuoteNotifier.refreshSchedule()
        }
        if retroReminderEnabled {
            RetroReminder.refreshSchedule()
        }
        haptics.play(.success)
        completed = true
    }
}

#Preview {
    OnboardingView()
        .environment(ProgressStore())
}
