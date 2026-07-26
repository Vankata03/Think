//
//  AchievementUnlockModifier.swift
//  Think
//

import SwiftUI
import UIKit

nonisolated enum AchievementUnlockPolicy {
    static func newlyEarned(
        previous: Set<ProgressAchievement>,
        current: Set<ProgressAchievement>
    ) -> [ProgressAchievement] {
        ProgressAchievement.all.filter {
            current.contains($0) && !previous.contains($0)
        }
    }
}

struct AchievementUnlockModifier: ViewModifier {
    let progress: ProgressStore
    let isEnabled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.haptics) private var haptics

    @AppStorage(SevenDayReviewPromptPolicy.storageKey) private var hasRequestedReview = false
    @State private var earnedSnapshot: Set<ProgressAchievement>?
    @State private var queuedAchievements: [ProgressAchievement] = []
    @State private var presentedAchievement: ProgressAchievement?
    @State private var isDismissing = false
    @State private var pendingReviewRequest = false
    @State private var autoDismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isEnabled, let achievement = presentedAchievement {
                    AchievementUnlockCard(achievement: achievement) {
                        dismissCurrentAchievement()
                    }
                    .id(achievement.id)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .transition(ThinkMotion.stateTransition(reduceMotion: reduceMotion))
                    .zIndex(1)
                }
            }
            .onAppear {
                guard earnedSnapshot == nil else { return }
                earnedSnapshot = progress.earnedAchievements
            }
            .onChange(of: progress.earnedAchievements) { _, current in
                handleEarnedAchievementsChange(current)
            }
            .onChange(of: voiceOverEnabled) { _, isVoiceOverEnabled in
                if isVoiceOverEnabled {
                    autoDismissTask?.cancel()
                    autoDismissTask = nil
                } else {
                    scheduleAutoDismissIfNeeded()
                }
            }
            .onDisappear {
                autoDismissTask?.cancel()
                autoDismissTask = nil
            }
    }

    private func handleEarnedAchievementsChange(_ current: Set<ProgressAchievement>) {
        guard let previous = earnedSnapshot else {
            earnedSnapshot = current
            return
        }
        earnedSnapshot = current
        guard isEnabled else { return }

        let knownAchievements = Set(queuedAchievements).union(
            presentedAchievement.map { [$0] } ?? []
        )
        let newAchievements = AchievementUnlockPolicy
            .newlyEarned(previous: previous, current: current)
            .filter { !knownAchievements.contains($0) }
        queuedAchievements.append(contentsOf: newAchievements)
        presentNextAchievementIfNeeded()
    }

    private func presentNextAchievementIfNeeded() {
        guard isEnabled,
              presentedAchievement == nil,
              !isDismissing,
              !queuedAchievements.isEmpty else { return }

        let achievement = queuedAchievements.removeFirst()
        withAnimation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion)) {
            presentedAchievement = achievement
        }
        haptics.play(.success)

        if voiceOverEnabled {
            let announcement = "\(String(localized: "Achievement unlocked")), \(achievement.localizedLabel)"
            Task { @MainActor in
                await Task.yield()
                UIAccessibility.post(notification: .announcement, argument: announcement)
            }
        }
        scheduleAutoDismissIfNeeded()
    }

    private func scheduleAutoDismissIfNeeded() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        guard presentedAchievement != nil, !voiceOverEnabled else { return }

        autoDismissTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(4))
            } catch {
                return
            }
            dismissCurrentAchievement()
        }
    }

    private func dismissCurrentAchievement() {
        guard let achievement = presentedAchievement, !isDismissing else { return }
        autoDismissTask?.cancel()
        autoDismissTask = nil
        isDismissing = true

        if achievement == .streak(.seven),
           SevenDayReviewPromptPolicy.shouldRequest(
               previouslyEarned: false,
               isEarned: true,
               hasRequested: hasRequestedReview,
               isEnabled: isEnabled
           ) {
            pendingReviewRequest = true
        }

        withAnimation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion)) {
            presentedAchievement = nil
        }

        let dismissalDelay: Duration = reduceMotion ? .milliseconds(200) : .milliseconds(220)
        Task { @MainActor in
            do {
                try await Task.sleep(for: dismissalDelay)
            } catch {
                return
            }
            isDismissing = false
            if queuedAchievements.isEmpty {
                requestPendingReviewIfNeeded()
            } else {
                presentNextAchievementIfNeeded()
            }
        }
    }

    private func requestPendingReviewIfNeeded() {
        guard pendingReviewRequest,
              SevenDayReviewPromptPolicy.shouldRequest(
                  previouslyEarned: false,
                  isEarned: true,
                  hasRequested: hasRequestedReview,
                  isEnabled: isEnabled
              ) else {
            pendingReviewRequest = false
            return
        }

        pendingReviewRequest = false
        hasRequestedReview = true
        Task {
            await AppReviewRequester.request()
        }
    }
}

private struct AchievementUnlockCard: View {
    let achievement: ProgressAchievement
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: achievement.icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Achievement unlocked")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(achievement.localizedLabel)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(String(localized: "Achievement unlocked")), \(achievement.localizedLabel)"
            )

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Done")
        }
        .padding(14)
        .frame(maxWidth: 440)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.separator.opacity(0.5), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 16, y: 8)
        .accessibilityElement(children: .contain)
    }
}
