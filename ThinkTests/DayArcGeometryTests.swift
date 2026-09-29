//
//  DayArcGeometryTests.swift
//  ThinkTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Think

@MainActor
struct DayArcGeometryTests {
    private let tolerance = 0.0001

    @Test func sixIsTheStartOfTheArc() {
        #expect(DayArcGeometry.fraction(forHour: 6) == 0)
    }

    @Test func twentyTwoIsTheEndOfTheArc() {
        #expect(DayArcGeometry.fraction(forHour: 22) == 1)
    }

    @Test func hoursBetweenMapLinearly() {
        #expect(DayArcGeometry.fraction(forHour: 14) == 0.5)
        #expect(DayArcGeometry.fraction(forHour: 10) == 0.25)
    }

    @Test func hoursOutsideTheDayAreClamped() {
        #expect(DayArcGeometry.fraction(forHour: 0) == 0)
        #expect(DayArcGeometry.fraction(forHour: 5.99) == 0)
        #expect(DayArcGeometry.fraction(forHour: 23.5) == 1)
    }

    @Test func hourOfADateReadsHoursAndMinutes() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Sofia"))
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 8, minute: 30)))
        #expect(DayArcGeometry.hour(of: date, calendar: calendar) == 8.5)
    }

    @Test func radiusIsTheContentWidthMinusSixtyHalvedAndCapped() {
        #expect(DayArcGeometry(width: 260).radius == 100)
        #expect(DayArcGeometry(width: 353).radius == 132)
        #expect(DayArcGeometry(width: 353).rowHeight == 210)
    }

    @Test func questionMarkerSitsAtEightOClock() {
        let geometry = DayArcGeometry(width: 353)
        let point = geometry.point(forHour: 8)
        let angle = Double.pi * (1 - 0.125)
        #expect(abs(point.x - (geometry.center.x + 132 * cos(angle))) < tolerance)
        #expect(abs(point.y - (geometry.center.y - 132 * sin(angle))) < tolerance)
        #expect(point.x < geometry.center.x)
    }

    @Test func moveMarkerSitsAtTheTopOfTheArc() {
        let geometry = DayArcGeometry(width: 353)
        let point = geometry.point(forHour: 14)
        #expect(abs(point.x - geometry.center.x) < tolerance)
        #expect(abs(point.y - (geometry.center.y - 132)) < tolerance)
    }

    @Test func retroMarkerMirrorsTheQuestionMarker() {
        let geometry = DayArcGeometry(width: 353)
        let question = geometry.point(forHour: 8)
        let retro = geometry.point(forHour: 20)
        #expect(abs((retro.x - geometry.center.x) + (question.x - geometry.center.x)) < tolerance)
        #expect(abs(retro.y - question.y) < tolerance)
    }

    @Test func markersAreAtTheRitualHours() {
        #expect(DayArcGeometry.markerHours == [8, 14, 20])
    }

    @Test func sunShowsItsFullHaloAwayFromMarkers() {
        let geometry = DayArcGeometry(width: 353)
        #expect(geometry.haloOpacity(atHour: 11) == 1)
        #expect(geometry.haloOpacity(atHour: 6) == 1)
        #expect(geometry.haloOpacity(atHour: 22) == 1)
    }

    @Test func sunDropsItsHaloWhereItWouldOverlapAMarker() {
        let geometry = DayArcGeometry(width: 353)
        #expect(geometry.haloOpacity(atHour: 8) == 0)
        #expect(geometry.haloOpacity(atHour: 8.5) == 0)
        #expect(geometry.haloOpacity(atHour: 13.75) == 0)
        #expect(geometry.haloOpacity(atHour: 20.25) == 0)
    }

    @Test func haloFadesInAsTheSunLeavesAMarker() {
        let geometry = DayArcGeometry(width: 353)
        // 26pt from the question marker: between the disc touching the
        // marker (23pt) and the halo clearing it (29pt).
        let hour = 8 + 2 * asin(13.0 / 132) * 16 / Double.pi
        let opacity = geometry.haloOpacity(atHour: hour)
        #expect(abs(opacity - 0.5) < 0.01)
    }

    @Test func textInsideTheRowKeepsItsCentre() {
        #expect(DayArcGeometry.clampedCentre(160, width: 50, within: 260) == 160)
    }

    @Test func textPastTheRightEdgeIsNudgedInward() {
        // "Rückblick" beside the retro marker on a 260pt row.
        #expect(DayArcGeometry.clampedCentre(238, width: 56, within: 260) == 232)
    }

    @Test func textPastTheLeftEdgeIsNudgedInward() {
        #expect(DayArcGeometry.clampedCentre(12, width: 48, within: 260) == 24)
    }

    @Test func textWiderThanTheRowIsCentred() {
        #expect(DayArcGeometry.clampedCentre(20, width: 300, within: 260) == 130)
    }
}
