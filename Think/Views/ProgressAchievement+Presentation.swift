//
//  ProgressAchievement+Presentation.swift
//  Think
//

import Foundation

extension ProgressAchievement {
    /// The three groups of the achievements list, in order: Streak, Paths,
    /// Focus sessions. Each group runs from the first medal to the highest.
    static let groups = [streakMilestones, pathMilestones, focusMilestones]

    var localizedCategory: String {
        switch self {
        case .streak: String(localized: "Streak")
        case .path: String(localized: "Paths")
        case .focus: String(localized: "Focus sessions")
        }
    }

    var localizedLabel: String {
        switch self {
        case .streak(let milestone):
            String(localized: "\(milestone.rawValue) day streak")
        case .path(let target), .focus(let target):
            String(localized: "\(localizedCategory): \(target)")
        }
    }

    var icon: String {
        switch self {
        case .streak: "medal.fill"
        case .path: "checkmark.seal.fill"
        case .focus: "timer"
        }
    }

    /// The medal art of a locked medal, drawn dimmed.
    var lockedIcon: String {
        switch self {
        case .streak: "medal"
        case .path: ThinkSymbol.path
        case .focus: ThinkSymbol.focus
        }
    }

    /// What earns the medal: the secondary line and the VoiceOver hint of
    /// a locked medal (design-system section 8).
    var unlockCondition: String {
        switch self {
        case .streak(let milestone):
            String(localized: "Reach a \(milestone.rawValue)-day streak to unlock")
        case .path(let target):
            String(localized: "Complete \(target) paths to unlock")
        case .focus(let target):
            String(localized: "Complete \(target) focus sessions to unlock")
        }
    }

    var shareMessage: String {
        String(localized: "\(localizedLabel) — Earned")
    }
}
