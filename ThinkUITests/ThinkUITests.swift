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
    func testProfileExposesPrivacyActions() throws {
        let app = launchApp()

        app.tabBars.buttons.element(boundBy: 3).tap()

        XCTAssertTrue(app.buttons["Export journal"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Delete all data"].waitForExistence(timeout: 2))

        app.buttons["Delete all data"].tap()
        XCTAssertTrue(app.alerts["Delete all data?"].waitForExistence(timeout: 2))
        app.alerts.buttons["Cancel"].tap()
    }

    @MainActor
    func testProfileShowsCloudBackupStatus() throws {
        let app = launchApp()

        app.tabBars.buttons.element(boundBy: 3).tap()

        let row = app.descendants(matching: .any)["CloudBackup"]
        XCTAssertTrue(row.waitForExistence(timeout: 2))
        // UI tests run on a throwaway in-memory store, so the row must
        // report the explicit off state and say entries stay on device.
        XCTAssertTrue(row.label.contains("iCloud backup"))
        XCTAssertTrue(row.label.contains("Off"))
        XCTAssertTrue(row.label.contains("Entries stay on this device"))
        XCTAssertFalse(row.label.contains("On —"))
    }

    @MainActor
    func testMoodChipTogglesOnAndOff() throws {
        let app = launchApp()

        let chip = app.descendants(matching: .any)["Mood.steady"]
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        XCTAssertFalse(chip.isSelected)

        chip.tap()
        XCTAssertTrue(chip.isSelected)

        // Tapping the selected chip clears it, so a mis-tap is never sticky.
        chip.tap()
        XCTAssertFalse(chip.isSelected)
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
        XCTAssertTrue(app.descendants(matching: .any)["FocusTimer"].waitForExistence(timeout: 5))

        app.buttons["FocusDurationSummary"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["FocusDurationSheet"].waitForExistence(timeout: 2))
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
        if !app.keyboards.firstMatch.waitForExistence(timeout: 2) {
            field.tap()
        }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
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
    func testSavingTodaysLineFillsAndEmptiesTheFavoritesList() throws {
        let app = launchApp()

        let favoriteButton = app.buttons["FavoriteQuote"]
        XCTAssertTrue(favoriteButton.waitForExistence(timeout: 5))
        favoriteButton.tap()

        app.tabBars.buttons.element(boundBy: 3).tap()
        app.descendants(matching: .any)["Favorites"].tap()

        let list = app.descendants(matching: .any)["FavoritesView"]
        XCTAssertTrue(list.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["FavoritesEmpty"].exists)
        XCTAssertEqual(list.cells.count, 1)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(favoriteButton.waitForExistence(timeout: 3))
        favoriteButton.tap()

        app.tabBars.buttons.element(boundBy: 3).tap()
        app.descendants(matching: .any)["Favorites"].tap()

        XCTAssertTrue(app.staticTexts["FavoritesEmpty"].waitForExistence(timeout: 3))
    }

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
