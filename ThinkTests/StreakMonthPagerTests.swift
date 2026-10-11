import Foundation
import Testing

@testable import Think

/// Paging the streak calendar (`design/progress-settings.md` section 8).
/// The direction of travel must be in place before the month changes, so
/// the outgoing month slides the way the new one arrives from.
struct StreakMonthPagerTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ month: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: 15, hour: 12))!
    }

    @Test func beginningRecordsTheDirectionBeforeTheMonthChanges() {
        var pager = StreakMonthPager(displayedMonth: date(9))

        let target = pager.begin(shift: -1, calendar: calendar)

        #expect(target == date(8))
        #expect(pager.direction == -1)
        #expect(pager.displayedMonth == date(9))
    }

    @Test func committingShowsTheChosenMonth() {
        var pager = StreakMonthPager(displayedMonth: date(9))
        pager.begin(shift: -1, calendar: calendar)

        pager.commit()

        #expect(pager.displayedMonth == date(8))
    }

    /// Back then forward: while the earlier month is still on screen the
    /// direction already says forward, which is what its removal needs.
    @Test func reversingDirectionFlipsTheDirectionWhileTheOldMonthIsStillShown() {
        var pager = StreakMonthPager(displayedMonth: date(9))
        pager.begin(shift: -1, calendar: calendar)
        pager.commit()
        #expect(pager.direction == -1)

        pager.begin(shift: 1, calendar: calendar)

        #expect(pager.direction == 1)
        #expect(pager.displayedMonth == date(8))
        pager.commit()
        #expect(pager.displayedMonth == date(9))
    }

    @Test func committingWithoutBeginningChangesNothing() {
        var pager = StreakMonthPager(displayedMonth: date(9))

        pager.commit()

        #expect(pager.displayedMonth == date(9))
        #expect(pager.direction == 0)
    }
}
