//
//  RetroReminderTests.swift
//  ThinkTests
//

import Foundation
import Testing
import UserNotifications
@testable import Think

struct RetroReminderTests {

    @Test func theRetroReminderIsTimeSensitive() {
        let content = RetroReminder.notificationContent()

        #expect(content.interruptionLevel == .timeSensitive)
        #expect(!content.title.isEmpty)
        #expect(!content.body.isEmpty)
    }

    /// A motivational line is not time sensitive, and marking it so is the
    /// abuse pattern Apple's review guidance calls out.
    @Test func theDailyLineStaysAtItsDefaultLevel() {
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: 9, minute: 0),
            repeats: false
        )
        let request = DailyQuoteNotifier.notificationRequest(
            for: DailyQuoteNotifier.ScheduledDailyLine(
                identifier: "daily-line-test",
                quote: ContentLibrary.quotes[0],
                trigger: trigger
            )
        )

        #expect(request.content.interruptionLevel == .active)
    }
}
