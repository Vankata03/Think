//
//  PathDetailUITests.swift
//  ThinkUITests
//

import XCTest

/// Path detail and the step page (`design/paths.md` sections 5 and 6).
/// `-ui-seed-path-finished` finishes Deep focus on earlier days.
final class PathDetailUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCompletingAStepTurnsTheCardIntoDoneRowsAndUndoBringsItBack() throws {
        let app = openDeepFocus(launch([]))
        let complete = app.buttons["CompleteStep"]
        let disc = app.buttons["StepDisc.1"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        XCTAssertEqual(disc.value as? String, "today")

        complete.tap()

        let doneRow = app.cells.containing(.any, identifier: "PathDoneRow").firstMatch
        XCTAssertTrue(doneRow.waitForExistence(timeout: 3))
        XCTAssertFalse(complete.exists)
        XCTAssertTrue(app.buttons["PathNextRow"].exists)
        XCTAssertEqual(disc.value as? String, "done")

        doneRow.swipeLeft()
        app.buttons["UndoPathStep"].tap()

        XCTAssertTrue(complete.waitForExistence(timeout: 3))
        XCTAssertEqual(disc.value as? String, "today")
    }

    @MainActor
    func testDiscsOpenTheirStepPages() throws {
        let app = openDeepFocus(launch([]))
        let today = app.buttons["StepDisc.1"]
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        XCTAssertEqual(today.label, "Step 1, Notice the pull")

        today.tap()
        XCTAssertTrue(app.descendants(matching: .any)["PathStepTask"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["CompleteStep"].exists)
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons["StepDisc.7"].tap()
        let locked = app.descendants(matching: .any)["PathStepLocked"]
        XCTAssertTrue(locked.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Opens after step 6."].exists)
        XCTAssertFalse(app.descendants(matching: .any)["PathStepTask"].exists)
    }

    @MainActor
    func testALockedPathOpensThePathBeforeIt() throws {
        let app = launch([])
        app.tabBars.buttons.element(boundBy: 1).tap()
        let row = app.buttons["Path.clear-thinking"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        reveal(row, in: app)
        row.tap()

        let open = app.buttons["OpenPreviousPath"]
        XCTAssertTrue(open.waitForExistence(timeout: 3))
        XCTAssertEqual(open.label, "Open Deep focus")
        open.tap()

        XCTAssertTrue(app.buttons["CompleteStep"].waitForExistence(timeout: 3))
        // The stack was replaced: back leads to the list, not the locked path.
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["PathsHero"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testBeginAgainOpensStepOneAtOnce() throws {
        let app = launch(["-ui-seed-path-finished"])
        app.tabBars.buttons.element(boundBy: 1).tap()
        let row = app.buttons["Path.deep-focus"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let beginAgain = app.buttons["BeginAgain"]
        XCTAssertTrue(beginAgain.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["CompleteStep"].exists)
        XCTAssertEqual(app.buttons["StepDisc.21"].value as? String, "done")
        beginAgain.tap()

        XCTAssertTrue(app.buttons["CompleteStep"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["StepDisc.1"].value as? String, "today")
    }

    @MainActor
    func testFocusForTheStepLandsOnFocusWithTheIntentionSet() throws {
        let app = openDeepFocus(launch([]))
        let focus = app.buttons["FocusForStep"]
        XCTAssertTrue(focus.waitForExistence(timeout: 5))
        XCTAssertEqual(focus.label, "Focus for 10 min")

        focus.tap()

        XCTAssertTrue(app.descendants(matching: .any)["FocusTimer"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["Focus"].isSelected)
        let intention = app.textFields["FocusIntention"]
        XCTAssertTrue(intention.waitForExistence(timeout: 3))
        XCTAssertEqual(intention.value as? String, "Notice the pull")
    }

    @MainActor
    private func openDeepFocus(_ app: XCUIApplication) -> XCUIApplication {
        app.tabBars.buttons.element(boundBy: 1).tap()
        let hero = app.buttons["PathsHero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        hero.tap()
        XCTAssertTrue(app.descendants(matching: .any)["PathDetail.deep-focus"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"] + arguments
        app.launch()
        return app
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<4 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
}
