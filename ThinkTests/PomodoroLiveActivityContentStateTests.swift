//
//  PomodoroLiveActivityContentStateTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

struct PomodoroLiveActivityContentStateTests {

    @Test func contentStateReportsElapsedProgress() {
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000)
        let endDate = startDate.addingTimeInterval(25 * 60)
        let state = PomodoroActivityAttributes.ContentState(
            phase: .work,
            startDate: startDate,
            endDate: endDate
        )

        #expect(state.progress(at: startDate) == 0)
        #expect(state.progress(at: startDate.addingTimeInterval(5 * 60)) == 0.2)
        #expect(state.progress(at: endDate) == 1)
    }

    @Test func contentStateClampsProgressOutsideTimerBounds() {
        let startDate = Date(timeIntervalSinceReferenceDate: 2_000)
        let endDate = startDate.addingTimeInterval(10 * 60)
        let state = PomodoroActivityAttributes.ContentState(
            phase: .rest,
            startDate: startDate,
            endDate: endDate
        )

        #expect(state.progress(at: startDate.addingTimeInterval(-60)) == 0)
        #expect(state.progress(at: endDate.addingTimeInterval(60)) == 1)
    }
}
