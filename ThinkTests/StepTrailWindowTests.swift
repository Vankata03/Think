//
//  StepTrailWindowTests.swift
//  ThinkTests
//
//  The seven-disc window of the Paths hero (design/paths.md section 3).
//

import Testing
@testable import Think

@MainActor
struct StepTrailWindowTests {

    @Test func stepOneIsSolidAtTheStartAndFadesWhereTheRunContinues() {
        let layout = StepTrailWindowLayout(totalSteps: 21, doneSteps: 0, todayStep: 1)

        #expect(layout.steps == Array(1...7))
        #expect(!layout.fadesLeading)
        #expect(layout.fadesTrailing)
        #expect(layout.state(of: 1) == .next)
        #expect(layout.state(of: 2) == .later)
    }

    @Test func midRunCentresTodayAndFadesBothEdges() {
        let layout = StepTrailWindowLayout(totalSteps: 21, doneSteps: 9, todayStep: 10)

        #expect(layout.steps == Array(7...13))
        #expect(layout.fadesLeading)
        #expect(layout.fadesTrailing)
        #expect(layout.state(of: 9) == .done)
        #expect(layout.state(of: 10) == .next)
        #expect(layout.state(of: 11) == .later)
    }

    @Test func theLastStepIsSolidAtTheEnd() {
        let layout = StepTrailWindowLayout(totalSteps: 21, doneSteps: 20, todayStep: 21)

        #expect(layout.steps == Array(15...21))
        #expect(layout.fadesLeading)
        #expect(!layout.fadesTrailing)
    }

    @Test func aSevenStepRunShowsEveryStepWithoutFading() {
        let layout = StepTrailWindowLayout(totalSteps: 7, doneSteps: 3, todayStep: 4)

        #expect(layout.steps == Array(1...7))
        #expect(!layout.fadesLeading)
        #expect(!layout.fadesTrailing)
    }

    @Test func theDoneFormCentresTheStepJustDoneAndHasNoTodayDisc() {
        let layout = StepTrailWindowLayout(totalSteps: 21, doneSteps: 5, todayStep: nil)

        #expect(layout.steps == Array(2...8))
        #expect(layout.state(of: 5) == .done)
        #expect(layout.state(of: 6) == .later)
        #expect(!layout.steps.contains { layout.state(of: $0) == .next })
    }

    @Test func voiceOverReadsTheStepsDone() {
        let layout = StepTrailWindowLayout(totalSteps: 21, doneSteps: 4, todayStep: 5)

        #expect(layout.accessibilityValue == "4 of 21 steps done")
    }
}
