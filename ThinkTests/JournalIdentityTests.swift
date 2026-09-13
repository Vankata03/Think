import Foundation
import Testing
@testable import Think

struct JournalIdentityTests {
    @Test func dstAndMidnightUseCapturedCivilDay() {
        let day = CivilDay(year: 2026, month: 3, day: 29, timeZoneIdentifier: "Europe/Sofia")
        #expect(day.interval.duration == 23 * 60 * 60)
        #expect(!day.contains(day.next.start))
        #expect(day.previous.next == day)
    }
    @Test func duplicateOrderIsIndependentOfArrivalOrder() {
        struct Record { let id: UUID; let date: Date; let text: String }
        let first = Record(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, date: .distantPast, text: "One")
        let second = Record(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, date: .distantPast, text: "Two")
        let selected = JournalIdentity.select([second, first], date: { $0.date }, recordID: { $0.id })
        #expect(selected?.primary.id == first.id)
        #expect(selected?.variants.first?.text == "Two")
    }
}
