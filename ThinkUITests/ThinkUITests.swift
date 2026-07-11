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
        XCTAssertTrue(app.descendants(matching: .any)["FocusTimer"].waitForExistence(timeout: 2))

        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.descendants(matching: .any)["ProfileProgress"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testShareSheetShowsAvailableCardStyles() throws {
        let app = launchApp()

        XCTAssertTrue(app.buttons["ShareQuote"].waitForExistence(timeout: 3))
        app.buttons["ShareQuote"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["ShareCardSheet"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["CardStyle.paper"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["CardStyle.midnight"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["CardStyle.clay"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["CardStyle.forest"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["SaveShareCard"].waitForExistence(timeout: 2))
        app.buttons["DismissShareCard"].tap()
    }

    @MainActor
    func testFocusPresetChangesTimerDuration() throws {
        let app = launchApp()

        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.descendants(matching: .any)["FocusTimer"].waitForExistence(timeout: 2))

        app.buttons["FocusPreset.50"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["FocusTimer.50"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testDeepFocusPathOpensCurrentStep() throws {
        let app = launchApp()

        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.descendants(matching: .any)["Path.deep-focus"].waitForExistence(timeout: 3))
        app.descendants(matching: .any)["Path.deep-focus"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["PathDetail.deep-focus"].waitForExistence(timeout: 5))
        let taskLabel = app.descendants(matching: .any)["PathCurrentTask"]
        if !taskLabel.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(taskLabel.waitForExistence(timeout: 5))
    }

    @MainActor
    func testCanCreateJournalNoteFromProfile() throws {
        let note = "UI note \(UUID().uuidString)"
        let app = launchApp()

        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.buttons["Journal"].waitForExistence(timeout: 3))
        app.buttons["Journal"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["JournalView"].waitForExistence(timeout: 2))

        app.buttons["NewNote"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["NewNoteSheet"].waitForExistence(timeout: 2))
        app.textViews["NewNoteInput"].tap()
        app.textViews["NewNoteInput"].typeText(note)
        app.buttons["SaveNewNote"].tap()

        XCTAssertTrue(app.staticTexts[note].waitForExistence(timeout: 3))
    }

    @MainActor
    func testCanSaveDailyQuestionWhenNotAlreadyAnswered() throws {
        let answer = "Daily answer \(UUID().uuidString)"
        let app = launchApp()

        let field = app.textFields["DailyQuestionInput"]
        XCTAssertTrue(field.waitForExistence(timeout: 2))
        field.tap()
        field.typeText(answer)
        app.buttons["SaveDailyAnswer"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["DailyQuestionAnswered"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts[answer].waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = englishLaunchArguments
            app.launch()
        }
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = englishLaunchArguments
        app.launch()
        return app
    }

    private var englishLaunchArguments: [String] {
        ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }
}
