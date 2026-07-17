//
//  StreakAchievementsSheet.swift
//  Think
//

import SwiftUI

struct StreakAchievementsSheet: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haptics) private var haptics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedAchievement: ProgressAchievement?
    @State private var canScroll = false
    @State private var hasScrolled = false
    @State private var scrollHintOffset: CGFloat = 0

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
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentSize.height > geometry.containerSize.height + 1
            } action: { _, canScroll in
                self.canScroll = canScroll
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        guard !hasScrolled, abs(value.translation.height) >= 8 else { return }
                        withAnimation(.easeOut(duration: 0.18)) {
                            hasScrolled = true
                        }
                    }
            )
            .overlay(alignment: .bottom) {
                if canScroll, !hasScrolled {
                    Label("Scroll for more", systemImage: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                        .offset(y: scrollHintOffset)
                        .padding(.bottom, 10)
                        .allowsHitTesting(false)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .opacity.combined(with: .move(edge: .bottom))
                        )
                        .task {
                            guard !reduceMotion else { return }
                            do {
                                try await Task.sleep(for: .milliseconds(350))
                            } catch {
                                return
                            }
                            withAnimation(.easeInOut(duration: 0.55).repeatCount(2, autoreverses: true)) {
                                scrollHintOffset = 5
                            }
                        }
                }
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
        .sheet(item: $selectedAchievement) { achievement in
            switch achievement {
            case .streak(let milestone):
                StreakShareSheet(month: .now, milestone: milestone)
            case .path, .focus:
                AchievementShareSheet(achievement: achievement)
            }
        }
    }

    @ViewBuilder
    private func achievementCell(for achievement: ProgressAchievement) -> some View {
        let isEarned = progress.hasEarned(achievement)
        if isEarned {
            Button {
                haptics.play(.selection)
                selectedAchievement = achievement
            } label: {
                badge(for: achievement, isEarned: true)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(achievement.localizedLabel)
            .accessibilityValue("Earned")
            .accessibilityHint("Share")
        } else {
            badge(for: achievement, isEarned: isEarned)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(achievement.localizedLabel)
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
                Image(systemName: isEarned ? achievement.icon : lockedIcon(for: achievement))
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

            HStack(spacing: 6) {
                Text(isEarned ? String(localized: "Earned") : String(localized: "Locked"))
                if isEarned {
                    Image(systemName: "square.and.arrow.up")
                        .accessibilityHidden(true)
                }
            }
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

    private func categoryLabel(for achievement: ProgressAchievement) -> String {
        achievement.localizedCategory
    }

    private func unlockHint(for achievement: ProgressAchievement) -> String {
        switch achievement {
        case .streak(let milestone):
            String(localized: "Reach a \(milestone.rawValue)-day streak to unlock")
        case .path, .focus:
            ""
        }
    }

    private func lockedIcon(for achievement: ProgressAchievement) -> String {
        switch achievement {
        case .streak:
            "medal"
        case .path:
            "point.topleft.down.to.point.bottomright.curvepath"
        case .focus:
            "timer"
        }
    }
}

#Preview {
    StreakAchievementsSheet()
        .environment(ProgressStore())
}
