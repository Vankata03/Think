import Foundation
import Testing

@testable import Think

struct JournalIdentityTests {
    private struct Record {
        let id: UUID?
        let date: Date
        var updatedAt: Date?
        let text: String
    }

    private static func id(_ last: Int) -> UUID { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", last))! }

    private func select(_ records: [Record]) -> DailySelection<Record>? {
        JournalIdentity.select(records, latestEdit: { $0.updatedAt ?? $0.date }, recordID: { $0.id }, tiebreak: { $0.text })
    }

    @Test func dstAndMidnightUseCapturedCivilDay() {
        let day = CivilDay(year: 2026, month: 3, day: 29, timeZoneIdentifier: "Europe/Sofia")
        #expect(day.interval.duration == 23 * 60 * 60)
        #expect(!day.contains(day.next.start))
        #expect(day.previous.next == day)
    }

    /// The day's record is the latest edit (`design/journal.md` section 6).
    @Test func latestEditIsThePrimaryAndVersionsFollowNewestFirst() {
        let morning = Date(timeIntervalSince1970: 1_790_000_000)
        let phone = Record(id: Self.id(1), date: morning, text: "Phone")
        let iPad = Record(id: Self.id(2), date: morning.addingTimeInterval(600), text: "iPad")
        let edited = Record(id: Self.id(3), date: morning.addingTimeInterval(-600), updatedAt: morning.addingTimeInterval(1_200), text: "Edited")

        let selected = select([phone, iPad, edited])

        #expect(selected?.primary.text == "Edited")
        #expect(selected?.variants.map(\.text) == ["iPad", "Phone"])
    }

    /// Equal edit times fall back to the record ID, then the tiebreak, so
    /// every device picks the same primary whatever order rows arrive in.
    @Test func equalEditsBreakTiesByRecordIDThenTiebreakIndependentOfArrivalOrder() {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let first = Record(id: Self.id(1), date: date, text: "One")
        let second = Record(id: Self.id(2), date: date, text: "Two")
        let legacyA = Record(id: nil, date: date, text: "A")
        let legacyB = Record(id: nil, date: date, text: "B")

        for arrival in [[second, legacyB, first, legacyA], [legacyA, first, legacyB, second]] {
            #expect(select(arrival)?.all.map(\.text) == ["A", "B", "One", "Two"])
        }
    }
}
