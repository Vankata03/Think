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
    func testFocusForTheStepLandsOnFocusWithTheWheelAndIntentionSet() throws {
        let app = openDeepFocus(launch([]))
        let focus = app.buttons["FocusForStep"]
        XCTAssertTrue(focus.waitForExistence(timeout: 5))
        XCTAssertEqual(focus.label, "Focus for 10 min")

        focus.tap()

        XCTAssertTrue(app.descendants(matching: .any)["FocusTimer"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["Focus"].isSelected)
        XCTAssertEqual(app.pickerWheels.element(boundBy: 0).value as? String, "10 minutes")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "FocusIntention").firstMatch.value as? String, "Notice the pull")
        // No timer running: End only shows during a session.
        XCTAssertFalse(app.buttons["FocusEnd"].exists)
    }

    @MainActor
    func testFocusForTheStepOnlySwitchesTabsWhileASessionRuns() throws {
        let app = launch([])
        app.tabBars.buttons.element(boundBy: 2).tap()
        let field = app.descendants(matching: .any).matching(identifier: "FocusIntention").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Write the brief\n")
        app.buttons["FocusPrimary"].tap()
        XCTAssertTrue(app.buttons["FocusEnd"].waitForExistence(timeout: 3))

        openDeepFocus(app).buttons["FocusForStep"].tap()

        XCTAssertTrue(app.buttons["FocusEnd"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["Focus"].isSelected)
        XCTAssertEqual(app.staticTexts["FocusIntentionText"].label, "Write the brief")
    }

    /// paths.md section 12: every disc keeps a 44pt target at the largest
    /// non-accessibility size. Run on the narrowest iPhone (375pt) too.
    @MainActor
    func testTrailDiscsKeepTheirTargetsAtTheLargestTextSize() throws {
        let app = openDeepFocus(
            launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"]))
        let width = app.windows.firstMatch.frame.width
        var frames: [CGRect] = []
        for number in 1...21 {
            let disc = app.buttons["StepDisc.\(number)"]
            if number == 1 || number == 15 {
                for _ in 0..<4 where !disc.isHittable { app.swipeUp() }
            }
            XCTAssertTrue(disc.exists)
            XCTAssertGreaterThanOrEqual(disc.frame.width, 44, "disc \(number)")
            XCTAssertGreaterThanOrEqual(disc.frame.height, 44, "disc \(number)")
            XCTAssertLessThanOrEqual(disc.frame.maxX, width)
            frames.append(disc.frame)
        }
        // Neighbouring targets in a row never overlap.
        for row in 0..<3 {
            let discs = frames[(row * 7)..<(row * 7 + 7)].sorted { $0.minX < $1.minX }
            for (a, b) in zip(discs, discs.dropFirst()) {
                XCTAssertLessThanOrEqual(a.maxX, b.minX + 0.5)
            }
        }
    }

    @MainActor
    @discardableResult
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
