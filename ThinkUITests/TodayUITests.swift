//
//  TodayUITests.swift
//  ThinkUITests
//

import XCTest

/// Today and Saved lines (`design/today.md`). `-ui-today-hour` pins the
/// clock so the day can be walked; `-ui-seed-answer` writes today's answer.
final class TodayUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTheEveningRotatesTheMoveToTheRetroAndUndoBringsItBack() throws {
        let app = launch(["-ui-today-hour", "20.5", "-ui-seed-answer"])
        let arc = app.descendants(matching: .any)["TodayDayArc"]
        let done = app.buttons["MarkMoveDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(arc.label.contains("1 of 3"))
        XCTAssertEqual(app.buttons["TodayStreak"].label, "Start today.")

        done.tap()

        XCTAssertTrue(app.buttons["BeginRetro"].waitForExistence(timeout: 3))
        XCTAssertTrue(arc.label.contains("2 of 3"))
        XCTAssertEqual(app.buttons["TodayStreak"].label, "1 day streak")

        let moveRow = app.descendants(matching: .any)["Act.move.done"]
        reveal(moveRow, in: app)
        moveRow.swipeLeft()
        app.buttons["UndoMove"].tap()

        XCTAssertTrue(done.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["BeginRetro"].exists)
        XCTAssertTrue(arc.label.contains("1 of 3"))
        XCTAssertEqual(app.buttons["TodayStreak"].label, "Start today.")
    }

    /// Before 20:00 the retro is only the later row and the dashed marker.
    @MainActor
    func testBeforeEightTheRetroIsOnlyALaterRow() throws {
        let app = launch(["-ui-today-hour", "15", "-ui-seed-answer"])
        let done = app.buttons["MarkMoveDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()

        XCTAssertTrue(app.descendants(matching: .any)["PracticeComplete"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["BeginRetro"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["Act.retro.later"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["TodayDayArc"].label.contains("2 of 3"))
    }

    @MainActor
    func testASavedLineAppearsInSavedLinesAndASwipeRemovesIt() throws {
        let app = launch([])
        let savedLines = app.buttons["OpenSavedLines"]
        XCTAssertTrue(savedLines.waitForExistence(timeout: 5))
        XCTAssertEqual(savedLines.label, "Saved lines")

        savedLines.tap()
        XCTAssertTrue(app.staticTexts["Lines you keep appear here."].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let save = app.buttons["FavoriteQuote"]
        XCTAssertEqual(save.label, "Save this line")
        save.tap()
        XCTAssertEqual(save.label, "Remove from saved lines")

        savedLines.tap()
        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Lines you keep appear here."].exists)
        row.swipeLeft()
        app.buttons["Remove"].tap()
        XCTAssertTrue(app.staticTexts["Lines you keep appear here."].waitForExistence(timeout: 3))
    }

    /// Every icon-only control on Today carries a title.
    @MainActor
    func testIconOnlyControlsHaveTitles() throws {
        let app = launch([])
        XCTAssertTrue(app.buttons["ShareQuote"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["ShareQuote"].label, "Share")
        XCTAssertEqual(app.buttons["FavoriteQuote"].label, "Save this line")
        XCTAssertEqual(app.buttons["OpenSavedLines"].label, "Saved lines")
        XCTAssertEqual(app.buttons["TodayStreak"].label, "Start today.")
    }

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + arguments
        app.launch()
        return app
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<4 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
}
