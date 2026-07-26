//
//  AchievementCardView.swift
//  Think
//

import SwiftUI

struct AchievementCardView: View {
    let achievement: ProgressAchievement
    let style: CardStyle

    static let designSize = QuoteCardView.designSize

    var body: some View {
        ZStack {
            style.background

            VStack(spacing: 48) {
                Spacer()

                Rectangle()
                    .fill(style.accent)
                    .frame(width: 120, height: 6)

                Image(systemName: achievement.icon)
                    .font(.system(size: 160, weight: .medium))
                    .foregroundStyle(style.accent)

                Text(achievement.target, format: .number)
                    .font(.system(size: 400, weight: .medium, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(style.text)

                Text(achievement.localizedCategory)
                    .font(.system(size: 56, weight: .medium, design: .serif))
                    .foregroundStyle(style.text)
                    .multilineTextAlignment(.center)

                Text("Earned")
                    .font(.system(size: 40, design: .serif))
                    .italic()
                    .foregroundStyle(style.accent)

                Spacer()

                Text("THINK")
                    .font(.system(size: 32, weight: .medium))
                    .kerning(14)
                    .foregroundStyle(style.accent)
                    .padding(.bottom, 120)
            }
            .padding(.horizontal, 120)
        }
        .frame(width: Self.designSize.width, height: Self.designSize.height)
    }
}

#Preview {
    AchievementCardView(achievement: .focus(50), style: .paper)
        .scaleEffect(0.2)
        .frame(width: 216, height: 384)
}
