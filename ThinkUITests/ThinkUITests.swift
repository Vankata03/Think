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
        XCTAssertTrue(app.descendants(matching: .any)["ActivityLog"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 0).isSelected)
    }

    @MainActor
    func testHomeKeepsMoveVisibleAndReversible() throws {
        let app = launchApp()
        let move = app.buttons["TodaysMoveToggle"]
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        for _ in 0..<3 where !move.isHittable { app.swipeUp() }
        move.tap()
        XCTAssertEqual(move.label, "Today's move done. Undo")
        move.tap()
        XCTAssertEqual(move.label, "Mark today's move done")
        XCTAssertTrue(app.buttons["WriteDailyAnswer"].exists)
        XCTAssertFalse(app.segmentedControls["DailyPracticePicker"].exists)
    }

    @MainActor
    func testTabsExposePrimarySections() throws {
        let app = launchApp()
        let tabs = app.tabBars.buttons
        XCTAssertEqual(tabs.count, 5)
        XCTAssertEqual(tabs.element(boundBy: 3).label, "Journal")

        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.descendants(matching: .any)["Path.deep-focus"].waitForExistence(timeout: 2))

        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.descendants(matching: .any)["FocusTimer"].waitForExistence(timeout: 2))

        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.descendants(matching: .any)["JournalView"].waitForExistence(timeout: 2))

        app.tabBars.buttons.element(boundBy: 4).tap()
        XCTAssertTrue(app.descendants(matching: .any)["ProfileProgress"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testProfileExposesPrivacyActions() throws {
        let app = launchApp()

        app.tabBars.buttons.element(boundBy: 4).tap()
        app.descendants(matching: .any)["ProfileSettings"].tap()

        XCTAssertTrue(app.buttons["Export journal"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Delete all data"].waitForExistence(timeout: 2))

        app.buttons["Delete all data"].tap()
        XCTAssertTrue(app.alerts["Delete all data?"].waitForExistence(timeout: 2))
        app.alerts.buttons["Cancel"].tap()
    }

    @MainActor
    func testProfileShowsCloudBackupStatus() throws {
        let app = launchApp()

        app.tabBars.buttons.element(boundBy: 4).tap()
        app.descendants(matching: .any)["ProfileSettings"].tap()

        let row = app.descendants(matching: .any)["CloudBackup"]
        XCTAssertTrue(row.waitForExistence(timeout: 2))
        // UI tests run on a throwaway in-memory store, so the row must
        // report the explicit off state and say entries stay on device.
        XCTAssertTrue(row.label.contains("iCloud sync"))
        XCTAssertTrue(row.label.contains("Off"))
        XCTAssertTrue(row.label.contains("when available"))
        XCTAssertFalse(row.label.contains("On —"))
    }

    @MainActor
    func testMoodChipPicksAndClearsAMood() throws {
        let app = launchApp()
        app.buttons["WriteDailyAnswer"].tap()

        let chip = app.buttons["MoodChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        XCTAssertEqual(chip.value as? String, "No mood")

        chip.tap()
        app.buttons["Steady"].tap()
        XCTAssertEqual(chip.value as? String, "Steady")

        chip.tap()
        app.buttons["No mood"].tap()
        XCTAssertEqual(chip.value as? String, "No mood")
    }

    @MainActor
    func testThemeChipFollowsTheSelectionRulesAndReloadsThroughEdit() throws {
        let note = "Theme note \(UUID().uuidString)"
        let app = launchApp()
        app.tabBars.buttons["Journal"].tap()
        app.buttons["NewNote"].tap()
        let chip = app.buttons["ThemeChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        XCTAssertEqual(chip.value as? String, "No theme")

        // The menu stays open while picking: three taps in one visit.
        chip.tap()
        app.buttons["Work"].tap()
        app.buttons["People"].tap()
        app.buttons["Health"].tap()
        dismissMenu(app)
        // A third pick replaces the secondary.
        XCTAssertEqual(chip.value as? String, "Work · Health")

        // Clearing the primary promotes the secondary.
        chip.tap()
        app.buttons["Work"].tap()
        dismissMenu(app)
        XCTAssertEqual(chip.value as? String, "Health")

        app.buttons["MoodChip"].tap()
        app.buttons["Good"].tap()
        let field = app.descendants(matching: .any).matching(identifier: "NewNoteInput").firstMatch
        field.tap()
        field.typeText(note)
        app.buttons["SaveNewNote"].tap()

        XCTAssertTrue(app.staticTexts[note].waitForExistence(timeout: 3))
        app.staticTexts[note].tap()
        XCTAssertTrue(app.buttons["EntryActions"].waitForExistence(timeout: 3))
        app.buttons["EntryActions"].tap()
        app.buttons["EditEntry"].tap()
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        XCTAssertEqual(chip.value as? String, "Health")
        XCTAssertEqual(app.buttons["MoodChip"].value as? String, "Good")
    }

    /// Taps the editor's day line, outside the open menu, to close it.
    @MainActor
    private func dismissMenu(_ app: XCUIApplication) {
        app.navigationBars.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
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
    func testCanCreateJournalNoteFromJournalTab() throws {
        let note = "UI note \(UUID().uuidString)"
        let app = launchApp()

        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["JournalView"].waitForExistence(timeout: 2))

        app.buttons["NewNote"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["NewNoteSheet"].waitForExistence(timeout: 2))
        let noteField = app.descendants(matching: .any).matching(identifier: "NewNoteInput").firstMatch
        noteField.tap()
        noteField.typeText(note)
        app.buttons["SaveNewNote"].tap()

        XCTAssertTrue(app.staticTexts[note].waitForExistence(timeout: 3))
    }

    @MainActor
    func testCanSaveDailyQuestionWhenNotAlreadyAnswered() throws {
        let answer = "Daily answer \(UUID().uuidString)"
        let app = launchApp()

        app.buttons["WriteDailyAnswer"].tap()
        let field = app.descendants(matching: .any).matching(identifier: "JournalEntryInput").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 2))
        field.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 2) {
            field.tap()
        }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        field.typeText(answer)
        app.buttons["SaveJournalEntry"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["DailyQuestionAnswered"].waitForExistence(timeout: 3))
        app.buttons["ReadDailyAnswer"].tap()
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

        app.tabBars.buttons.element(boundBy: 4).tap()
        app.descendants(matching: .any)["Favorites"].tap()

        let list = app.descendants(matching: .any)["FavoritesView"]
        XCTAssertTrue(list.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["FavoritesEmpty"].exists)
        XCTAssertEqual(list.cells.count, 1)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(favoriteButton.waitForExistence(timeout: 3))
        favoriteButton.tap()

        app.tabBars.buttons.element(boundBy: 4).tap()
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
