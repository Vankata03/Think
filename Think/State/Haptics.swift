//
//  Haptics.swift
//  Think
//

import SwiftUI
import UIKit

enum HapticImpact: Equatable {
    case light
    case medium

    var feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light: .light
        case .medium: .medium
        }
    }
}

enum HapticNotification: Equatable {
    case success
    case warning
    case error

    var feedbackType: UINotificationFeedbackGenerator.FeedbackType {
        switch self {
        case .success: .success
        case .warning: .warning
        case .error: .error
        }
    }
}

enum HapticPattern: Equatable {
    case selection
    case impact(HapticImpact)
    case notification(HapticNotification)
}

protocol HapticsBackend: AnyObject {
    func play(_ pattern: HapticPattern)
}

struct Haptics {
    enum Event {
        case selection
        case start
        case pause
        case reset
        case success
        case warning

        var pattern: HapticPattern {
            switch self {
            case .selection: .selection
            case .start: .impact(.medium)
            case .pause: .impact(.light)
            case .reset: .impact(.medium)
            case .success: .notification(.success)
            case .warning: .notification(.warning)
            }
        }
    }

    static let live = Haptics(backend: SystemHapticsBackend())

    private let backend: HapticsBackend

    init(backend: HapticsBackend) {
        self.backend = backend
    }

    func play(_ event: Event) {
        backend.play(event.pattern)
    }
}

final class SystemHapticsBackend: HapticsBackend {
    func play(_ pattern: HapticPattern) {
        Task { @MainActor in
            Self.playOnMain(pattern)
        }
    }

    @MainActor
    private static func playOnMain(_ pattern: HapticPattern) {
        switch pattern {
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        case .impact(let impact):
            let generator = UIImpactFeedbackGenerator(style: impact.feedbackStyle)
            generator.prepare()
            generator.impactOccurred(intensity: 0.85)
        case .notification(let notification):
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(notification.feedbackType)
        }
    }
}

final class RecordingHapticsBackend: HapticsBackend {
    private(set) var patterns: [HapticPattern] = []

    func play(_ pattern: HapticPattern) {
        patterns.append(pattern)
    }
}

private struct HapticsEnvironmentKey: EnvironmentKey {
    static let defaultValue = Haptics.live
}

extension EnvironmentValues {
    var haptics: Haptics {
        get { self[HapticsEnvironmentKey.self] }
        set { self[HapticsEnvironmentKey.self] = newValue }
    }
}
