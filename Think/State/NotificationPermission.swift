//
//  NotificationPermission.swift
//  Think
//

import Observation
import UserNotifications

enum NotificationPermission {
    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestAuthorizationIfNeeded() async -> Bool {
        switch await status() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return
                (try? await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound]
                )) ?? false
        @unknown default:
            return false
        }
    }
}

/// Notification permission as Settings sees it, so tests can stand in a spy.
@MainActor
protocol NotificationAuthorizing {
    func status() async -> UNAuthorizationStatus
    func requestAuthorization() async -> Bool
}

struct SystemNotificationAuthorization: NotificationAuthorizing {
    func status() async -> UNAuthorizationStatus {
        await NotificationPermission.status()
    }

    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }
}

/// The Settings switch for phase-end notifications (`progress-settings.md`
/// section 3). The timer never asks for permission at Start, so turning
/// the alerts on is where a person who was never asked gets asked.
@MainActor
enum SessionEndAlerts {
    /// Applies the switch and returns the notification authorization that
    /// results, so Settings can show the denied explanation.
    static func setEnabled(
        _ enabled: Bool,
        timer: PomodoroTimer,
        permission: any NotificationAuthorizing = SystemNotificationAuthorization()
    ) async -> UNAuthorizationStatus {
        timer.setSessionEndAlertsEnabled(enabled)
        let status = await permission.status()
        guard enabled, status == .notDetermined else { return status }
        _ = await permission.requestAuthorization()
        return await permission.status()
    }
}

/// Where views reach notification permission and reminder scheduling, so UI
/// tests can stand in a scripted prompt for the system alert. Views read it
/// as optional and fall back to `system`.
@Observable
@MainActor
final class NotificationAccess {
    @ObservationIgnored let authorizer: any NotificationAuthorizing
    @ObservationIgnored let scheduleReminders: () -> Void

    init(
        authorizer: any NotificationAuthorizing = SystemNotificationAuthorization(),
        scheduleReminders: @escaping () -> Void = {
            DailyQuoteNotifier.refreshSchedule()
            RetroReminder.refreshSchedule()
        }
    ) {
        self.authorizer = authorizer
        self.scheduleReminders = scheduleReminders
    }

    static let system = NotificationAccess()
}
