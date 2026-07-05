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
        let defaults = UserDefaults.standard
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard defaults.bool(forKey: enabledKey) else { return }

        let minutes = defaults.object(forKey: minutesKey) as? Int ?? defaultMinutes

        Task {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }

            var components = DateComponents()
            components.hour = minutes / 60
            components.minute = minutes % 60

            let content = UNMutableNotificationContent()
            content.title = "Evening retrospective"
            content.body = "Close the day. Two honest minutes."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
