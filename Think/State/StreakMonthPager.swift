//
//  StreakMonthPager.swift
//  Think
//

import Foundation

/// Which month the streak sheet shows and which way it last travelled
/// (`design/progress-settings.md` section 8). Paging takes two steps: the
/// direction is set first and the month second. A removed view keeps the
/// transition it was last rendered with, so the outgoing month only slides
/// the right way if the direction was already in place when it rendered.
struct StreakMonthPager: Equatable {
    private(set) var displayedMonth: Date
    /// -1 after paging back, 1 after paging forward, 0 before any paging.
    private(set) var direction = 0
    private var target: Date?

    init(displayedMonth: Date) {
        self.displayedMonth = displayedMonth
    }

    /// Step 1: records the direction of travel and the month to show.
    /// Returns that month, or nil when the calendar cannot move that far.
    @discardableResult
    mutating func begin(shift: Int, calendar: Calendar = .current) -> Date? {
        guard let shifted = calendar.date(byAdding: .month, value: shift, to: displayedMonth) else { return nil }
        direction = shift < 0 ? -1 : 1
        target = shifted
        return shifted
    }

    /// Step 2: shows the month `begin` chose. Does nothing without one.
    mutating func commit() {
        guard let target else { return }
        displayedMonth = target
        self.target = nil
    }
}
