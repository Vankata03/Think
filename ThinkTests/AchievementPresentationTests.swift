//
//  AchievementPresentationTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

/// Unearned medals stay visible with their unlock condition as a secondary
/// line and as the VoiceOver hint (design-system section 8).
struct AchievementPresentationTests {

    @Test(arguments: [
        (ProgressAchievement.streak(.seven), "Reach a 7-day streak to unlock"),
        (.streak(.oneHundred), "Reach a 100-day streak to unlock"),
        (.path(1), "Complete 1 path to unlock"),
        (.focus(1), "Complete 1 focus session to unlock"),
        (.focus(50), "Complete 50 focus sessions to unlock"),
    ])
    func everyMedalNamesItsUnlockCondition(_ achievement: ProgressAchievement, _ condition: String) {
        #expect(achievement.unlockCondition == condition)
    }

    @Test func everyMedalBelongsToExactlyOneGroup() {
        #expect(ProgressAchievement.groups.flatMap { $0 } == ProgressAchievement.all)
    }
}
