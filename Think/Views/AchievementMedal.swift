//
//  AchievementMedal.swift
//  Think
//

import SwiftUI

/// The medal art shared by the Progress strip and the achievements list.
/// An earned medal is an `accent` disc with `accentOnFill` art; a locked
/// one keeps its art, dimmed, so colour never carries the state alone.
struct AchievementMedal: View {
    let achievement: ProgressAchievement
    let isEarned: Bool

    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = 44

    var body: some View {
        let diameter = min(size, 88)
        ZStack {
            Circle()
                .fill(isEarned ? ThinkColor.accent : ThinkColor.track)
            Image(systemName: isEarned ? achievement.icon : achievement.lockedIcon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(isEarned ? ThinkColor.accentOnFill : ThinkColor.secondaryLabel)
        }
        .frame(width: diameter, height: diameter)
        .opacity(isEarned ? 1 : 0.6)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        AchievementMedal(achievement: .streak(.seven), isEarned: true)
        AchievementMedal(achievement: .focus(10), isEarned: false)
    }
}
