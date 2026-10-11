//
//  AchievementsView.swift
//  Think
//

import SwiftUI

/// Every medal, pushed from Progress's "All achievements"
/// (`design/progress-settings.md` section 1). Grouped by Streak, Paths and
/// Focus sessions; locked medals stay visible, dimmed, with their unlock
/// condition. An earned medal opens the existing share flow. A plain
/// `List`, so there is no detent, overlay or scroll hint (`ACH-1`).
struct AchievementsView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.haptics) private var haptics
    @State private var sharing: ProgressAchievement?

    var body: some View {
        List {
            ForEach(ProgressAchievement.groups, id: \.first?.id) { group in
                Section {
                    ForEach(group) { achievement in
                        row(for: achievement)
                    }
                } header: {
                    Text(group.first?.localizedCategory ?? "")
                }
            }
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("AchievementsView")
        .sheet(item: $sharing) { achievement in
            switch achievement {
            case .streak(let milestone):
                StreakShareSheet(month: .now, milestone: milestone)
            case .path, .focus:
                AchievementShareSheet(achievement: achievement)
            }
        }
    }

    @ViewBuilder
    private func row(for achievement: ProgressAchievement) -> some View {
        if progress.hasEarned(achievement) {
            Button {
                haptics.play(.selection)
                sharing = achievement
            } label: {
                HStack(spacing: ThinkSpacing.m) {
                    AchievementMedal(achievement: achievement, isEarned: true)
                    VStack(alignment: .leading, spacing: ThinkSpacing.xs) {
                        Text(achievement.localizedLabel)
                            .font(.think(.heading))
                            .foregroundStyle(ThinkColor.label)
                        Text("Earned")
                            .font(.think(.secondary))
                            .foregroundStyle(ThinkColor.secondaryLabel)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: ThinkSymbol.share)
                        .foregroundStyle(ThinkColor.secondaryLabel)
                }
                .contentShape(Rectangle())
            }
            .accessibilityLabel(achievement.localizedLabel)
            .accessibilityValue(Text("Earned"))
            .accessibilityHint(Text("Share"))
            .accessibilityIdentifier("Achievement.\(achievement.id)")
        } else {
            HStack(spacing: ThinkSpacing.m) {
                AchievementMedal(achievement: achievement, isEarned: false)
                VStack(alignment: .leading, spacing: ThinkSpacing.xs) {
                    Text(achievement.localizedLabel)
                        .font(.think(.heading))
                        .foregroundStyle(ThinkColor.secondaryLabel)
                    Label(achievement.unlockCondition, systemImage: ThinkSymbol.lock)
                        .font(.think(.secondary))
                        .foregroundStyle(ThinkColor.secondaryLabel)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(achievement.localizedLabel)
            .accessibilityValue(Text("Locked"))
            .accessibilityHint(achievement.unlockCondition)
            .accessibilityIdentifier("Achievement.\(achievement.id)")
        }
    }
}

#Preview {
    NavigationStack {
        AchievementsView()
    }
    .environment(ProgressStore())
}
