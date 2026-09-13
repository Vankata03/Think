import Foundation
import Testing
import UserNotifications
@testable import Think

@MainActor struct NotificationRenderMeasurementTests {
    @Test func compareActualAttachmentRenderingWithCacheReuse() async throws {
        var cold: [Double] = [], warm: [Double] = []
        for _ in 0..<4 {
            let line = DailyQuoteNotifier.ScheduledDailyLine(
                identifier: "measurement-\(UUID())",
                quote: Quote(text: "A small step makes a difference. \(UUID())", author: ""),
                trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 8), repeats: false))
            for cached in [false, true] {
                let start = ContinuousClock.now
                let result = await DailyQuoteNotifier.prepareRichRequest(for: line)
                let duration = start.duration(to: .now).components
                let milliseconds = Double(duration.seconds) * 1_000 + Double(duration.attoseconds) / 1e15
                #expect(!result.request.content.attachments.isEmpty)
                if cached { warm.append(milliseconds) } else { cold.append(milliseconds) }
                result.removeTemporaryFiles()
            }
        }
        func mean(_ values: [Double]) -> String { String(format: "%.3f", values.reduce(0, +) / Double(values.count)) }
        print("NOTIFICATION_MEASUREMENT samples=4 uncachedMs=\(mean(cold)) cachedMs=\(mean(warm))")
    }
}
