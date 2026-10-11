//
//  Onboarding.swift
//  Think
//

import Foundation
import UserNotifications

/// First-launch onboarding (`design/onboarding.md`). Shown once, on a new
/// installation, gated by `completedKey`; an installation that already set
/// it never sees onboarding again.
enum Onboarding {
    static let completedKey = "hasCompletedOnboarding"
}

/// The paged flow: three steps, four where the on-device AI step applies.
/// Forward only; Skip on every step but the last (section 2).
struct OnboardingFlow: Equatable {
    enum Step: Hashable {
        case promise
        case reminders
        case makeItYours
        /// Owned by issue #67; the flow only reserves its place.
        case onDeviceAI
    }

    let steps: [Step]

    init(includesOnDeviceAI: Bool) {
        steps = [.promise, .reminders, .makeItYours] + (includesOnDeviceAI ? [.onDeviceAI] : [])
    }

    func isLast(_ step: Step) -> Bool { steps.last == step }

    func canSkip(_ step: Step) -> Bool { !isLast(step) }

    /// One-based, for "Step n of m".
    func number(of step: Step) -> Int { (steps.firstIndex(of: step) ?? 0) + 1 }

    func next(after step: Step) -> Step? {
        guard let index = steps.firstIndex(of: step), index + 1 < steps.count else { return nil }
        return steps[index + 1]
    }
}

/// The three switches of the Reminders step, all on to start.
struct OnboardingReminderChoice: Equatable {
    var dailyLine = true
    var eveningRetro = true
    var sessionEndAlerts = true

    static let allOff = OnboardingReminderChoice(dailyLine: false, eveningRetro: false, sessionEndAlerts: false)

    var anyOn: Bool { dailyLine || eveningRetro || sessionEndAlerts }
}

/// Continue on the Reminders step (section 4). Nothing is asked while the
/// switches move; this is the one place onboarding asks for notification
/// permission.
@MainActor
enum OnboardingReminders {
    /// Asks for permission once when a switch is on and the answer is not
    /// yet known, then saves: what is on when allowed, all three off when
    /// not. Skip saves `.allOff` through here, which never asks.
    /// - Returns: what was saved.
    @discardableResult
    static func commit(
        _ choice: OnboardingReminderChoice,
        permission: any NotificationAuthorizing,
        defaults: UserDefaults = .standard,
        timer: PomodoroTimer,
        schedule: () -> Void
    ) async -> OnboardingReminderChoice {
        var saved = OnboardingReminderChoice.allOff
        if choice.anyOn, await isAllowed(permission) {
            saved = choice
        }
        defaults.set(saved.dailyLine, forKey: DailyQuoteNotifier.enabledKey)
        defaults.set(saved.eveningRetro, forKey: RetroReminder.enabledKey)
        timer.setSessionEndAlertsEnabled(saved.sessionEndAlerts)
        if saved.anyOn { schedule() }
        return saved
    }

    private static func isAllowed(_ permission: any NotificationAuthorizing) async -> Bool {
        switch await permission.status() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return await permission.requestAuthorization()
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}

/// A row of the Optional section of "Make it yours" (section 5.2), shown
/// only where it can work. Settings keeps the unavailable explanations.
enum OnboardingOptionalRow: Hashable {
    case health
    case journalLock

    static func available(healthAvailable: Bool, lockAvailable: Bool) -> [OnboardingOptionalRow] {
        (healthAvailable ? [.health] : []) + (lockAvailable ? [.journalLock] : [])
    }
}
