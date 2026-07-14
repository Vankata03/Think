//
//  PomodoroLiveActivityContentStateTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

struct PomodoroLiveActivityContentStateTests {

    @Test func contentStateDecodesLegacyPayloadWithoutStartDate() throws {
        let endDate = Date(timeIntervalSinceReferenceDate: 1_000)
        let data = """
        {
          "phase": "work",
          "endDate": \(endDate.timeIntervalSinceReferenceDate)
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(PomodoroActivityAttributes.ContentState.self, from: data)

        #expect(state.phase == .work)
        #expect(state.startDate == endDate)
        #expect(state.endDate == endDate)
        #expect(state.restEndDate == nil)
    }

    @Test func staleWorkStateTransitionsToItsPreloadedBreak() {
        let workStart = Date(timeIntervalSinceReferenceDate: 3_000)
        let workEnd = workStart.addingTimeInterval(25 * 60)
        let restEnd = workEnd.addingTimeInterval(5 * 60)
        let state = PomodoroActivityAttributes.ContentState(
            phase: .work,
            startDate: workStart,
            endDate: workEnd,
            restEndDate: restEnd
        )

        #expect(state.presentationState(isStale: false) == state)

        let breakState = state.presentationState(isStale: true)
        #expect(breakState.phase == .rest)
        #expect(breakState.startDate == workEnd)
        #expect(breakState.endDate == restEnd)
        #expect(breakState.restEndDate == nil)
    }

    @Test func staleStateWithoutAValidBreakRemainsUnchanged() {
        let endDate = Date(timeIntervalSinceReferenceDate: 4_000)
        let restState = PomodoroActivityAttributes.ContentState(
            phase: .rest,
            startDate: endDate.addingTimeInterval(-5 * 60),
            endDate: endDate
        )

        #expect(restState.presentationState(isStale: true) == restState)
    }

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
