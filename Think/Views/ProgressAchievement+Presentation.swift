//
//  ProgressAchievement+Presentation.swift
//  Think
//

import Foundation

extension ProgressAchievement {
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

    var shareMessage: String {
        String(localized: "\(localizedLabel) — Earned")
    }
}
