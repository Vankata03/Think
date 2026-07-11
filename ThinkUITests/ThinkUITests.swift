//
//  ThinkUITests.swift
//  ThinkUITests
//

import XCTest

final class ThinkUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsTodayCoreLoop() throws {
        let app = launchApp()

        XCTAssertTrue(app.descendants(matching: .any)["QuestionOfTheDayCard"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ShareQuote"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["TrainingLog"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 0).isSelected)
    }

    @MainActor
    func testTabsExposePrimarySections() throws {
        let app = launchApp()

        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.descendants(matching: .any)["Path.deep-focus"].waitForExistence(timeout: 2))

        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.staticTexts["25:00"].waitForExistence(timeout: 2))

        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.descendants(matching: .any)["ProfileProgress"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testShareSheetShowsAvailableCardStyles() throws {
        let app = launchApp()

        app.buttons["Share"].tap()

        XCTAssertTrue(app.navigationBars["Share card"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["Paper"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["Midnight"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["Clay"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["Forest"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 2))
        app.buttons["Done"].tap()
    }

    @MainActor
    func testFocusPresetChangesTimerDuration() throws {
        let app = launchApp()

        app.tabBars.buttons["Focus"].tap()
        XCTAssertTrue(app.staticTexts["25:00"].waitForExistence(timeout: 2))

        app.buttons["50 / 10"].tap()

        XCTAssertTrue(app.staticTexts["50:00"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testDeepFocusPathOpensCurrentStep() throws {
        let app = launchApp()

        app.tabBars.buttons["Paths"].tap()
        app.staticTexts["Deep focus"].tap()

        XCTAssertTrue(app.navigationBars["Deep focus"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Day '")).firstMatch.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Today's task"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testCanCreateJournalNoteFromProfile() throws {
        let note = "UI note \(UUID().uuidString)"
        let app = launchApp()

        app.tabBars.buttons["Profile"].tap()
        app.buttons["Journal"].tap()
        XCTAssertTrue(app.navigationBars["Journal"].waitForExistence(timeout: 2))

        app.navigationBars["Journal"].buttons["New note"].tap()
        XCTAssertTrue(app.navigationBars["New note"].waitForExistence(timeout: 2))
        app.textViews.firstMatch.tap()
        app.textViews.firstMatch.typeText(note)
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts[note].waitForExistence(timeout: 3))
    }

    @MainActor
    func testCanSaveDailyQuestionWhenNotAlreadyAnswered() throws {
        let answer = "Daily answer \(UUID().uuidString)"
        let app = launchApp()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 2))
        field.tap()
        field.typeText(answer)
        app.buttons["Save answer"].tap()

        XCTAssertTrue(app.staticTexts["Answered"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts[answer].waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing"]
            app.launch()
        }
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        return app
    }
}
