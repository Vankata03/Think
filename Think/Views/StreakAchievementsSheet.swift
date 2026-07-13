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

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(StreakMilestone.allCases) { milestone in
                            achievementCell(for: milestone)
                        }
                    }
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
    private func achievementCell(for milestone: StreakMilestone) -> some View {
        if progress.hasEarned(milestone) {
            Button {
                haptics.play(.selection)
                selectedMilestone = milestone
            } label: {
                badge(for: milestone, isEarned: true)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(streakLabel(for: milestone))
            .accessibilityValue("Earned")
            .accessibilityHint("Opens milestone share card")
        } else {
            badge(for: milestone, isEarned: false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(streakLabel(for: milestone))
                .accessibilityValue("Locked")
                .accessibilityHint(
                    String(localized: "Reach a \(milestone.rawValue)-day streak to unlock")
                )
        }
    }

    private func badge(for milestone: StreakMilestone, isEarned: Bool) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isEarned ? Color.accentColor.opacity(0.16) : Color(.tertiarySystemFill))
                Image(systemName: isEarned ? "medal.fill" : "medal")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(isEarned ? Color.accentColor : Color.secondary.opacity(0.55))
            }
            .frame(width: 82, height: 82)

            Text(milestone.rawValue, format: .number)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(isEarned ? Color.primary : Color.secondary)

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

    private func streakLabel(for milestone: StreakMilestone) -> String {
        String(localized: "\(milestone.rawValue) day streak")
    }
}

#Preview {
    StreakAchievementsSheet()
        .environment(ProgressStore())
}
