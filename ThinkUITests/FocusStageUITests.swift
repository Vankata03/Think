//
//  FocusStageUITests.swift
//  ThinkUITests
//

import XCTest

/// The Focus stage and its running-session accessory (design/focus.md).
final class FocusStageUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// `FOC-5`: every control of a session is reachable in the bar without
    /// scrolling.
    @MainActor
    func testTheBarRunsASessionAtTheDefaultSize() throws {
        let app = launch()
        try runSessionFromTheBar(app)
    }

    @MainActor
    func testTheBarRunsASessionAtAX3() throws {
        let app = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"])
        try runSessionFromTheBar(app)
    }

    @MainActor
    func testTurningTheBreakWheelUpdatesTheArc() throws {
        let app = launch()
        openFocus(app)
        let arc = app.descendants(matching: .any)["FocusTimer"]
        XCTAssertTrue(arc.label.contains("then 5 min break"), arc.label)

        let breakWheel = app.pickerWheels.element(boundBy: 1)
        XCTAssertTrue(breakWheel.waitForExistence(timeout: 2))
        breakWheel.adjust(toPickerWheelValue: "10 minutes")

        let updated = NSPredicate(format: "label CONTAINS %@", "then 10 min break")
        expectation(for: updated, evaluatedWith: arc)
        waitForExpectations(timeout: 3)
    }

    @MainActor
    func testTheWheelReadsItsValuesWithUnits() throws {
        let app = launch()
        openFocus(app)
        let workWheel = app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(workWheel.waitForExistence(timeout: 2))
        XCTAssertEqual(workWheel.value as? String, "25 minutes")
    }

    @MainActor
    func testTheAccessoryShowsTheSessionOnOtherTabsAndOpensFocus() throws {
        let app = launch()
        openFocus(app)
        let field = app.descendants(matching: .any).matching(identifier: "FocusIntention").firstMatch
        field.tap()
        field.typeText("Write the brief\n")
        app.buttons["FocusPrimary"].tap()

        app.tabBars.buttons["Today"].tap()
        let accessory = app.buttons["FocusAccessory"]
        XCTAssertTrue(accessory.waitForExistence(timeout: 3))
        XCTAssertTrue(accessory.label.contains("Write the brief"), accessory.label)
        XCTAssertTrue(app.buttons["FocusAccessoryToggle"].exists)
        XCTAssertEqual(app.buttons["FocusAccessoryToggle"].label, "Pause")

        app.buttons["FocusAccessoryToggle"].tap()
        XCTAssertEqual(app.buttons["FocusAccessoryToggle"].label, "Resume")

        accessory.tap()
        XCTAssertTrue(app.tabBars.buttons["Focus"].isSelected)
        XCTAssertFalse(app.buttons["FocusAccessory"].exists)
    }

    @MainActor
    func testTheAccessoryHidesTheIntentionOnceTheJournalLocks() throws {
        let app = launch(["-ui-auth-success"])
        openFocus(app)
        let field = app.descendants(matching: .any).matching(identifier: "FocusIntention").firstMatch
        field.tap()
        field.typeText("Write the brief\n")
        app.buttons["FocusPrimary"].tap()

        app.tabBars.buttons.element(boundBy: 4).tap()
        let gear = app.navigationBars.buttons["Settings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 3))
        gear.tap()
        let lock = app.switches["LockJournal"]
        for _ in 0..<12 where !(lock.exists && lock.isHittable) { app.swipeUp() }
        // A Form toggle's own switch sits at the trailing edge of the row.
        lock.switches.firstMatch.exists ? lock.switches.firstMatch.tap() : lock.tap()
        XCTAssertEqual(lock.value as? String, "1")

        let accessory = app.buttons["FocusAccessory"]
        XCTAssertTrue(accessory.waitForExistence(timeout: 3))
        let hidden = NSPredicate(format: "NOT (label CONTAINS %@)", "Write the brief")
        expectation(for: hidden, evaluatedWith: accessory)
        waitForExpectations(timeout: 3)
        XCTAssertTrue(accessory.label.contains("Deep work"), accessory.label)
        XCTAssertFalse(app.staticTexts["Write the brief"].exists)
    }

    @MainActor
    func testAPathStepSetsTheWheelAndIntentionWithoutStarting() throws {
        let app = launch()
        app.tabBars.buttons.element(boundBy: 1).tap()
        app.descendants(matching: .any)["Path.deep-focus"].tap()
        let focusButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Focus for")).firstMatch
        for _ in 0..<6 where !focusButton.isHittable { app.swipeUp() }
        focusButton.tap()

        XCTAssertTrue(app.tabBars.buttons["Focus"].isSelected)
        XCTAssertEqual(app.buttons["FocusPrimary"].label, "Start")
        let field = app.descendants(matching: .any).matching(identifier: "FocusIntention").firstMatch
        XCTAssertFalse((field.value as? String ?? "").isEmpty)
    }

    // MARK: - Helpers

    @MainActor
    private func runSessionFromTheBar(_ app: XCUIApplication) throws {
        openFocus(app)
        let primary = app.buttons["FocusPrimary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 3))
        XCTAssertEqual(primary.label, "Start")
        XCTAssertTrue(primary.isHittable)
        XCTAssertFalse(app.buttons["FocusEnd"].exists)

        primary.tap()
        XCTAssertEqual(primary.label, "Pause")
        XCTAssertTrue(app.buttons["FocusEnd"].isHittable)
        XCTAssertTrue(app.buttons["FocusSkip"].isHittable)
        XCTAssertEqual(app.buttons["FocusSkip"].label, "Skip")
        XCTAssertFalse(app.pickerWheels.firstMatch.exists)

        primary.tap()
        XCTAssertEqual(primary.label, "Resume")
        primary.tap()
        XCTAssertEqual(primary.label, "Pause")

        app.buttons["FocusSkip"].tap()
        XCTAssertEqual(app.buttons["FocusSkip"].label, "Skip to work")
        XCTAssertTrue(app.buttons["FocusSkip"].isHittable)
        XCTAssertFalse(app.buttons["FocusEnd"].exists)
        XCTAssertTrue(primary.isHittable)

        app.buttons["FocusSkip"].tap()
        XCTAssertTrue(app.buttons["FocusEnd"].isHittable)

        // Under a minute of work: End ends at once, without asking.
        app.buttons["FocusEnd"].tap()
        XCTAssertFalse(app.buttons["End session"].exists)
        XCTAssertEqual(primary.label, "Start")
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 2))
    }

    @MainActor
    private func openFocus(_ app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.descendants(matching: .any)["FocusTimer"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        app.launch()
        return app
    }
}
