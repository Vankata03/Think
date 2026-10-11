//
//  StepTrailLayoutTests.swift
//  ThinkTests
//
//  The full trail of path detail (design/paths.md section 3): seven
//  discs to a row, snaking.
//

import Testing

@testable import Think

struct StepTrailLayoutTests {

    @Test func aSevenStepPathIsOneRow() {
        let layout = StepTrailLayout(totalSteps: 7)

        #expect(layout.rows == [[1, 2, 3, 4, 5, 6, 7]])
    }

    @Test func rowsSnakeSoTheSecondRunsRightToLeft() {
        let layout = StepTrailLayout(totalSteps: 21)

        #expect(
            layout.rows == [
                [1, 2, 3, 4, 5, 6, 7],
                [14, 13, 12, 11, 10, 9, 8],
                [15, 16, 17, 18, 19, 20, 21],
            ])
    }

    @Test func aShortReturningRowStartsUnderTheTurn() {
        let layout = StepTrailLayout(totalSteps: 10)

        #expect(
            layout.rows == [
                [1, 2, 3, 4, 5, 6, 7],
                [nil, nil, nil, nil, 10, 9, 8],
            ])
    }
}
