//
//  SessionArcGeometryTests.swift
//  ThinkTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Think

struct SessionArcGeometryTests {
    private let tolerance = 0.0001

    @Test func workAndBreakShareTheCurveInProportion() {
        #expect(abs(SessionArcGeometry.workShare(workMinutes: 25, breakMinutes: 5) - 25.0 / 30) < tolerance)
        #expect(abs(SessionArcGeometry.workShare(workMinutes: 120, breakMinutes: 30) - 0.8) < tolerance)
        #expect(abs(SessionArcGeometry.workShare(workMinutes: 5, breakMinutes: 30) - 5.0 / 35) < tolerance)
    }

    @Test func aSessionWithoutMinutesIsAllWork() {
        #expect(SessionArcGeometry.workShare(workMinutes: 0, breakMinutes: 0) == 1)
    }

    @Test func whileIdleTheSunWaitsAtTheLeftEnd() {
        #expect(SessionArcGeometry.sunFraction(stage: .idle, phaseProgress: 0.6, workShare: 0.8) == 0)
    }

    @Test func duringWorkTheSunMovesThroughTheWorkPart() {
        #expect(abs(SessionArcGeometry.sunFraction(stage: .work, phaseProgress: 0.5, workShare: 0.8) - 0.4) < tolerance)
        #expect(abs(SessionArcGeometry.sunFraction(stage: .work, phaseProgress: 1, workShare: 0.8) - 0.8) < tolerance)
    }

    @Test func duringTheBreakTheSunMovesAlongTheTail() {
        #expect(abs(SessionArcGeometry.sunFraction(stage: .rest, phaseProgress: 0, workShare: 0.8) - 0.8) < tolerance)
        #expect(abs(SessionArcGeometry.sunFraction(stage: .rest, phaseProgress: 0.5, workShare: 0.8) - 0.9) < tolerance)
        #expect(SessionArcGeometry.sunFraction(stage: .rest, phaseProgress: 1, workShare: 0.8) == 1)
    }

    @Test func progressOutsideThePhaseIsClamped() {
        #expect(SessionArcGeometry.sunFraction(stage: .work, phaseProgress: -1, workShare: 0.5) == 0)
        #expect(SessionArcGeometry.sunFraction(stage: .rest, phaseProgress: 2, workShare: 0.5) == 1)
    }

    /// focus.md section 12: past about 80% of the curve the end-of-work
    /// caption crowds the trailing edge, so it moves inside the curve.
    @Test func theEndOfWorkCaptionMovesInsidePastEightyPercent() {
        #expect(!SessionArcGeometry.endCaptionInside(workShare: 0.5))
        #expect(!SessionArcGeometry.endCaptionInside(workShare: 0.8))
        #expect(SessionArcGeometry.endCaptionInside(workShare: 25.0 / 30))
    }

    @Test func theEndCaptionInsideTheCurveStaysOnARowOf402Points() {
        // An iPhone 17 Pro is 402pt wide; the stage column is inset.
        let geometry = SessionArcGeometry(width: 402 - 2 * 16)
        let point = geometry.endCaptionCentre(workShare: 25.0 / 30, captionWidth: 64)
        #expect(point.x + 32 <= geometry.width)
        #expect(point.x - 32 >= 0)
        // Inside means nearer the circle's centre than the curve.
        let boundary = geometry.point(at: 25.0 / 30)
        #expect(hypot(point.x - geometry.center.x, point.y - geometry.center.y)
            < hypot(boundary.x - geometry.center.x, boundary.y - geometry.center.y))
    }

    @Test func theEndCaptionBeforeEightyPercentSitsOutsideTheCurve() {
        let geometry = SessionArcGeometry(width: 370)
        let point = geometry.endCaptionCentre(workShare: 0.5, captionWidth: 64)
        #expect(hypot(point.x - geometry.center.x, point.y - geometry.center.y) > geometry.radius)
    }

    @Test func radiusFollowsTheWidthAndIsCapped() {
        #expect(SessionArcGeometry(width: 260).radius == 100)
        #expect(SessionArcGeometry(width: 600).radius == SessionArcGeometry.maxRadius)
    }
}
