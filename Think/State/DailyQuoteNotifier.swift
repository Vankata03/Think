//
//  DailyQuoteNotifier.swift
//  Think
//

import Foundation
import UserNotifications

/// Schedules the "daily line" notification. Local notifications can't
/// pick content at fire time, so this keeps a sliding window of the
/// next 8 days scheduled individually, refreshed whenever the app
/// becomes active.
enum DailyQuoteNotifier {
    static let enabledKey = "dailyQuoteNotificationEnabled"
    static let minutesKey = "dailyQuoteNotificationMinutes"
    static let defaultMinutes = 8 * 60

    private static let dayCount = 8
    private static var identifiers: [String] {
        (0..<dayCount).map { "daily-quote-\($0)" }
    }

    static func scheduledRequests(
        startingAt now: Date,
        minutes: Int,
        calendar: Calendar
    ) -> [UNNotificationRequest] {
        let today = calendar.startOfDay(for: now)
        return (0..<dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fireDate = calendar.date(byAdding: .minute, value: minutes, to: day),
                  fireDate > now else { return nil }

            let quote = ContentLibrary.dailyQuote(for: day)
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Today's line")
            content.body = quote.notificationText
            content.sound = .default

            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            return UNNotificationRequest(
                identifier: "daily-quote-\(offset)", content: content, trigger: trigger
            )
        }
    }

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
        let requests = scheduledRequests(startingAt: .now, minutes: minutes, calendar: .current)
        let center = UNUserNotificationCenter.current()
        for request in requests {
            try? await center.add(request)
        }
    }

    static func cancelSchedule() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
