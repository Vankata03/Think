//
//  WeeklyReviewUITests.swift
//  ThinkUITests
//

import XCTest

/// The weekly review against `design/progress-settings.md` section 9: the
/// reflection is written in the Journal editor, saved as the week's
/// review, and hidden with the mood counts while the journal is locked.
final class WeeklyReviewUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testWritingAReflectionShowsItOnTheReviewTheJournalAndItsDetail() throws {
        let app = openReview([])
        // A zero-practice week shows zeros and a writable reflection.
        XCTAssertTrue(element(app, "WeeklyReviewPracticeDays").label.contains("0 of 7 days"))
        // No inline composer and no save button on the screen (WKR-1, WKR-2).
        XCTAssertFalse(element(app, "WeeklyReviewInput").exists)
        XCTAssertFalse(app.buttons["SaveWeeklyReview"].exists)

        let write = app.buttons["WriteReflection"]
        reveal(write, in: app)
        write.tap()
        let editor = element(app, "JournalEditor")
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.exists)
        XCTAssertFalse(app.buttons["MoodChip"].exists)
        XCTAssertFalse(app.buttons["ThemeChip"].exists)
        XCTAssertFalse(app.buttons["SaveJournalEntry"].isEnabled)

        let field = element(app, "JournalEntryInput")
        if !app.keyboards.firstMatch.exists { field.tap() }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.typeText("Five of seven days.")
        element(app, "NextWeekInput").tap()
        app.typeText("Pack the practice.")
        app.buttons["SaveJournalEntry"].tap()

        let saved = app.buttons["WeeklyReviewSaved"]
        XCTAssertTrue(saved.waitForExistence(timeout: 3))
        XCTAssertTrue(saved.label.contains("Five of seven days."))
        XCTAssertFalse(app.buttons["WriteReflection"].exists)
        saved.tap()
        XCTAssertTrue(app.buttons["EditEntry"].waitForExistence(timeout: 3))
        XCTAssertTrue(anything(app, containing: "Pack the practice.").exists)

        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Five of seven days.")).firstMatch
            .waitForExistence(timeout: 3))
    }

    /// Cancel keeps the draft; "Write reflection" reopens it.
    @MainActor
    func testThisWeeksDraftReopensInTheEditor() throws {
        let app = openReview([])
        let write = app.buttons["WriteReflection"]
        reveal(write, in: app)
        write.tap()
        let field = element(app, "JournalEntryInput")
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        if !app.keyboards.firstMatch.exists { field.tap() }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.typeText("Half a reflection")
        app.buttons["CancelJournalEditor"].tap()

        XCTAssertTrue(write.waitForExistence(timeout: 3))
        write.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        XCTAssertEqual(field.value as? String, "Half a reflection")
    }

    /// A failed save keeps the review's own message and the writing.
    @MainActor
    func testAFailedSaveKeepsTheWritingWithTheReviewsMessage() throws {
        let app = openReview(["-ui-fail-save"])
        let write = app.buttons["WriteReflection"]
        reveal(write, in: app)
        write.tap()
        let field = element(app, "JournalEntryInput")
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        if !app.keyboards.firstMatch.exists { field.tap() }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.typeText("Kept")
        app.buttons["SaveJournalEntry"].tap()
        let error = element(app, "JournalSaveError")
        XCTAssertTrue(error.waitForExistence(timeout: 3))
        XCTAssertEqual(error.label, "Could not save your weekly review. Your writing is still here. Try again.")
        XCTAssertEqual(field.value as? String, "Kept")
    }

    @MainActor
    func testASavedReviewShowsAsItsJournalRow() throws {
        let app = openReview(["-ui-seed-weekly-review"])
        let saved = app.buttons["WeeklyReviewSaved"]
        reveal(saved, in: app)
        XCTAssertTrue(saved.label.contains("PRIVATE WEEKLY REFLECTION"))
        XCTAssertTrue(element(app, "WeeklyReviewMood").exists)
    }

    /// Locked: the gate as the reflection's row, no mood counts, no journal
    /// counts and nothing private in the accessibility tree.
    @MainActor
    func testALockedJournalHidesTheReflectionAndMoodCounts() throws {
        let app = openReview(["-ui-journal-locked", "-ui-seed-weekly-review"])
        let unlock = app.buttons["UnlockJournal"]
        reveal(unlock, in: app)
        XCTAssertFalse(anything(app, containing: "PRIVATE").exists)
        XCTAssertFalse(element(app, "WeeklyReviewMood").exists)
        XCTAssertFalse(app.buttons["WeeklyReviewSaved"].exists)
        XCTAssertFalse(app.buttons["WriteReflection"].exists)

        let thisWeek = element(app, "WeeklyReviewThisWeek")
        reveal(thisWeek, in: app)
        app.buttons["This week"].firstMatch.tap()
        XCTAssertTrue(anything(app, containing: "Completed focus sessions").waitForExistence(timeout: 3))
        XCTAssertFalse(anything(app, containing: "Answers").exists)
        XCTAssertFalse(anything(app, containing: "Notes").exists)
    }

    // MARK: Helpers

    @MainActor
    private func openReview(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        app.launch()
        app.tabBars.buttons["Progress"].tap()
        let open = app.buttons["OpenWeeklyReview"]
        reveal(open, in: app)
        open.tap()
        XCTAssertTrue(element(app, "WeeklyReviewView").waitForExistence(timeout: 3))
        return app
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    @MainActor
    private func anything(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)).firstMatch
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, element.identifier)
    }
}
