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
    /// caption crowds the trailing edge. It stays on a 402pt screen
    /// (iPhone 17 Pro, the stage column inset 16pt either side).
    @Test func theEndOfWorkCaptionStaysOnARowOf402Points() {
        let geometry = SessionArcGeometry(width: 402 - 2 * 16)
        for share in [25.0 / 30, 0.9, 120.0 / 121] {
            let point = geometry.endCaptionCentre(workShare: share, captionWidth: 80)
            #expect(point.x + 40 <= geometry.width)
            #expect(point.x - 40 >= 0)
        }
    }

    /// Inside the curve it would sit on the countdown (seen in the build's
    /// screenshots at 25/5), so it stays outside, clear of the stroke.
    @Test func theEndOfWorkCaptionStaysOutsideTheCurve() {
        let geometry = SessionArcGeometry(width: 370)
        for share in [0.14, 0.5, 25.0 / 30, 0.95] {
            let point = geometry.endCaptionCentre(workShare: share, captionWidth: 80)
            let distance = hypot(point.x - geometry.center.x, point.y - geometry.center.y)
            #expect(distance >= geometry.radius + SessionArcGeometry.captionOffset - 0.001)
        }
    }

    @Test func aCaptionPushedInwardClimbsAlongTheCurve() {
        let geometry = SessionArcGeometry(width: 300)
        let free = ArcPosition.point(fraction: 0.95, center: geometry.center,
                                     radius: geometry.radius + SessionArcGeometry.captionOffset)
        let point = geometry.endCaptionCentre(workShare: 0.95, captionWidth: 80)
        #expect(point.x < free.x)
        #expect(point.y < free.y)
        let distance = hypot(point.x - geometry.center.x, point.y - geometry.center.y)
        #expect(abs(distance - (geometry.radius + SessionArcGeometry.captionOffset)) < tolerance)
    }

    @Test func radiusFollowsTheWidthAndIsCapped() {
        #expect(SessionArcGeometry(width: 260).radius == 100)
        #expect(SessionArcGeometry(width: 600).radius == SessionArcGeometry.maxRadius)
    }
}
