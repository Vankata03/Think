//
//  RetroReminder.swift
//  Think
//

import Foundation
import UserNotifications

/// Schedules the evening retrospective reminder. Unlike the daily
/// line, the content is static, so a single repeating calendar
/// trigger is enough.
enum RetroReminder {
    static let enabledKey = "retroReminderEnabled"
    static let minutesKey = "retroReminderMinutes"
    static let defaultMinutes = 21 * 60

    private static let identifier = "daily-retro"

    static func refreshSchedule() {
        Task {
            await refreshScheduleAsync()
        }
    }

    static func refreshScheduleAsync() async {
        let defaults = UserDefaults.standard
        cancelSchedule()
        guard defaults.bool(forKey: enabledKey) else { return }
        guard await NotificationPermission.requestAuthorizationIfNeeded() else { return }

        let minutes = defaults.object(forKey: minutesKey) as? Int ?? defaultMinutes
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Evening retrospective")
        content.body = String(localized: "Close the day. Two honest minutes.")
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancelSchedule() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
