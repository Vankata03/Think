//
//  StreakAchievementsSheet.swift
//  Think
//

import SwiftUI

struct StreakAchievementsSheet: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haptics) private var haptics
    @State private var selectedMilestone: StreakMilestone?

    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 14),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Milestones stay here after you earn them.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    achievementSection("Streak", achievements: ProgressAchievement.streakMilestones)
                    achievementSection("Paths", achievements: ProgressAchievement.pathMilestones)
                    achievementSection("Focus sessions", achievements: ProgressAchievement.focusMilestones)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(item: $selectedMilestone) { milestone in
            StreakShareSheet(month: .now, milestone: milestone)
        }
    }

    @ViewBuilder
    private func achievementCell(for achievement: ProgressAchievement) -> some View {
        let isEarned = progress.hasEarned(achievement)
        if isEarned, case .streak(let milestone) = achievement {
            Button {
                haptics.play(.selection)
                selectedMilestone = milestone
            } label: {
                badge(for: achievement, isEarned: true)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label(for: achievement))
            .accessibilityValue("Earned")
            .accessibilityHint("Opens milestone share card")
        } else {
            badge(for: achievement, isEarned: isEarned)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label(for: achievement))
                .accessibilityValue(
                    isEarned ? String(localized: "Earned") : String(localized: "Locked")
                )
                .accessibilityHint(isEarned ? "" : unlockHint(for: achievement))
        }
    }

    private func achievementSection(
        _ title: LocalizedStringKey,
        achievements: [ProgressAchievement]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(achievements) { achievement in
                    achievementCell(for: achievement)
                }
            }
        }
    }

    private func badge(for achievement: ProgressAchievement, isEarned: Bool) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isEarned ? Color.accentColor.opacity(0.16) : Color(.tertiarySystemFill))
                Image(systemName: icon(for: achievement, isEarned: isEarned))
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(isEarned ? Color.accentColor : Color.secondary.opacity(0.55))
            }
            .frame(width: 82, height: 82)

            Text(achievement.target, format: .number)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(isEarned ? Color.primary : Color.secondary)

            Text(categoryLabel(for: achievement))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(isEarned ? String(localized: "Earned") : String(localized: "Locked"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(isEarned ? Color.accentColor : Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    isEarned ? Color.accentColor.opacity(0.35) : Color(uiColor: .separator).opacity(0.5),
                    lineWidth: 1
                )
        }
        .opacity(isEarned ? 1 : 0.72)
        .contentShape(Rectangle())
    }

    private func label(for achievement: ProgressAchievement) -> String {
        switch achievement {
        case .streak(let milestone):
            String(localized: "\(milestone.rawValue) day streak")
        case .path(let target):
            "\(String(localized: "Paths")): \(target)"
        case .focus(let target):
            "\(String(localized: "Focus sessions")): \(target)"
        }
    }

    private func categoryLabel(for achievement: ProgressAchievement) -> String {
        switch achievement {
        case .streak: String(localized: "Streak")
        case .path: String(localized: "Paths")
        case .focus: String(localized: "Focus sessions")
        }
    }

    private func unlockHint(for achievement: ProgressAchievement) -> String {
        switch achievement {
        case .streak(let milestone):
            String(localized: "Reach a \(milestone.rawValue)-day streak to unlock")
        case .path, .focus:
            ""
        }
    }

    private func icon(for achievement: ProgressAchievement, isEarned: Bool) -> String {
        switch achievement {
        case .streak:
            isEarned ? "medal.fill" : "medal"
        case .path:
            isEarned ? "checkmark.seal.fill" : "point.topleft.down.to.point.bottomright.curvepath"
        case .focus:
            "timer"
        }
    }
}

#Preview {
    StreakAchievementsSheet()
        .environment(ProgressStore())
}
