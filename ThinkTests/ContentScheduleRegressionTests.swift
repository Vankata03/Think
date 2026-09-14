import Foundation
import Testing
@testable import Think

@MainActor struct ContentScheduleRegressionTests {
    @Test func frozenSchedulesRemainResolvableAndRetainRetiredHistory() {
        #expect(ContentLibrary.legacyScheduleIDs.count == 100)
        #expect(Set(ContentLibrary.legacyScheduleIDs).count == 100)
        #expect(ContentLibrary.editorialScheduleIDs.count == 107)
        #expect(Set(ContentLibrary.editorialScheduleIDs).count == 107)
        for id in ContentLibrary.legacyScheduleIDs {
            #expect(ContentLibrary.practice(id: id, version: 1) != nil)
        }
        #expect(ContentLibrary.practice(id: "practice.038", version: 1) != nil)
        #expect(!ContentLibrary.editorialScheduleIDs.contains("practice.038"))
    }

    @Test func editorialCutoverAdvancesByCivilDaysAcrossTimezonesAndDST() throws {
        for zone in ["Europe/Sofia", "America/New_York", "Pacific/Auckland"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try #require(TimeZone(identifier: zone))
            let cutover = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 1)))
            #expect(ContentLibrary.dailyPractice(for: cutover.addingTimeInterval(-1), calendar: calendar).version == 1)
            for offset in 0..<220 {
                let day = try #require(calendar.date(byAdding: .day, value: offset, to: cutover))
                let practice = ContentLibrary.dailyPractice(for: day, calendar: calendar)
                #expect(practice.id == ContentLibrary.editorialScheduleIDs[offset % 107])
                #expect(ContentLibrary.dailyPractice(for: day.addingTimeInterval(3_600), calendar: calendar) == practice)
            }
        }
    }
}
