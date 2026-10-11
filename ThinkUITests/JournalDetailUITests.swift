import XCTest

/// The Journal's read detail and versions (`design/journal.md` sections 5
/// and 6).
final class JournalDetailUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    /// A three-way conflict on one day: the latest edit is the listed
    /// record; the others sit behind "Another version from this day",
    /// newest first, and each opens its own detail.
    @MainActor
    func testConflictShowsTheLatestEditWithTheOthersBehindAnotherVersion() throws {
        let app = launch(["-ui-seed-journal-versions"])
        app.tabBars.buttons["Journal"].tap()
        let primary = journalRow(app, containing: "VERSION C")
        XCTAssertTrue(primary.waitForExistence(timeout: 3))
        XCTAssertFalse(journalRow(app, containing: "VERSION A").exists)
        XCTAssertFalse(journalRow(app, containing: "VERSION B").exists)

        primary.tap()
        XCTAssertTrue(app.staticTexts["VERSION C of today's answer."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["PRIVATE AUDIT PROMPT"].exists)
        XCTAssertTrue(app.staticTexts["Good · Work · People"].exists)
        app.buttons["AnotherVersion"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["JournalVersions"].waitForExistence(timeout: 3))
        let newer = journalRow(app, containing: "VERSION B")
        let older = journalRow(app, containing: "VERSION A")
        XCTAssertTrue(newer.waitForExistence(timeout: 3) && older.exists)
        XCTAssertFalse(journalRow(app, containing: "VERSION C").exists)
        XCTAssertLessThan(newer.frame.minY, older.frame.minY)

        older.tap()
        XCTAssertTrue(app.staticTexts["VERSION A of today's answer."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["AnotherVersion"].exists)
    }

    /// Editing an older version gives it the newest edit, so it becomes
    /// the day's record and the list shows it instead.
    @MainActor
    func testEditingAnOlderVersionMakesItTheDaysRecord() throws {
        let app = launch(["-ui-seed-journal-versions"])
        app.tabBars.buttons["Journal"].tap()
        let primary = journalRow(app, containing: "VERSION C")
        XCTAssertTrue(primary.waitForExistence(timeout: 3))
        primary.tap()
        app.buttons["AnotherVersion"].tap()
        let older = journalRow(app, containing: "VERSION A")
        XCTAssertTrue(older.waitForExistence(timeout: 3))
        older.tap()

        XCTAssertTrue(app.buttons["EditEntry"].waitForExistence(timeout: 3))
        app.buttons["EditEntry"].tap()
        let field = app.descendants(matching: .any).matching(identifier: "JournalEntryInput").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        XCTAssertTrue((field.value as? String)?.contains("VERSION A") == true)
        field.tap()
        field.typeText(" Edited")
        app.buttons["SaveJournalEntry"].tap()
        // Where the tap left the cursor decides where the word lands.
        let edited = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'VERSION A' AND label CONTAINS ' Edited' AND NOT label BEGINSWITH 'Edited'")
        ).firstMatch
        XCTAssertTrue(edited.waitForExistence(timeout: 3))

        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(journalRow(app, containing: "VERSION A").waitForExistence(timeout: 3))
        XCTAssertFalse(journalRow(app, containing: "VERSION C").exists)
    }

    /// Edit opens the editor on the record shown, for an answer and a retro.
    @MainActor
    func testEditOpensTheEditorOnTheRecord() throws {
        let app = launch(["-ui-seed-journal"])
        app.tabBars.buttons["Journal"].tap()
        let answer = journalRow(app, containing: "PRIVATE AUDIT ANSWER")
        XCTAssertTrue(answer.waitForExistence(timeout: 3))
        answer.tap()
        XCTAssertTrue(app.navigationBars["Answer"].waitForExistence(timeout: 3))
        app.buttons["EditEntry"].tap()
        let field = app.descendants(matching: .any).matching(identifier: "JournalEntryInput").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        XCTAssertEqual(field.value as? String, "PRIVATE AUDIT ANSWER")
        app.buttons["CancelJournalEditor"].tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let retro = journalRow(app, containing: "PRIVATE AUDIT RETRO")
        XCTAssertTrue(retro.waitForExistence(timeout: 3))
        retro.tap()
        XCTAssertTrue(app.navigationBars["Retro"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["What went well?"].exists)
        XCTAssertTrue(app.staticTexts["PRIVATE AUDIT IMPROVE"].exists)
        app.buttons["EditEntry"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["JournalEditor"].waitForExistence(timeout: 3))
        XCTAssertTrue(anything(app, containing: "PRIVATE AUDIT RETRO").exists)
    }

    /// Delete asks first with the retro copy, then removes the record and
    /// pops back to a list without it.
    @MainActor
    func testDeleteAsksRemovesAndPops() throws {
        let app = launch(["-ui-seed-journal"])
        app.tabBars.buttons["Journal"].tap()
        let retro = journalRow(app, containing: "PRIVATE AUDIT RETRO")
        XCTAssertTrue(retro.waitForExistence(timeout: 3))
        retro.tap()

        let delete = app.buttons["DeleteEntry"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        XCTAssertTrue(app.staticTexts["Delete this retro?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["It is removed from this device and your iCloud."].exists)
        XCTAssertTrue(app.descendants(matching: .any)["JournalDetail"].exists)
        app.buttons["ConfirmDeleteEntry"].firstMatch.tap()

        XCTAssertTrue(app.buttons["JournalFilterMenu"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["JournalDetail"].exists)
        XCTAssertFalse(app.staticTexts["Entry not found."].exists)
        XCTAssertFalse(journalRow(app, containing: "PRIVATE AUDIT RETRO").exists)
        XCTAssertTrue(journalRow(app, containing: "PRIVATE AUDIT ANSWER").exists)
    }

    /// A detail that locks underneath shows the Locked state, with nothing
    /// private left in the accessibility tree.
    @MainActor
    func testDetailThatLocksUnderneathShowsLocked() throws {
        let app = launch(["-ui-journal-locked", "-ui-auth-success", "-ui-seed-journal", "-ui-relock-on-background"])
        app.tabBars.buttons["Journal"].tap()
        let answer = journalRow(app, containing: "PRIVATE AUDIT ANSWER")
        XCTAssertTrue(answer.waitForExistence(timeout: 3))
        answer.tap()
        XCTAssertTrue(app.staticTexts["PRIVATE AUDIT ANSWER"].waitForExistence(timeout: 3))

        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(app.buttons["UnlockJournal"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["JournalDetail"].exists)
        XCTAssertFalse(anything(app, containing: "PRIVATE").exists)
        XCTAssertFalse(app.buttons["EditEntry"].exists)
        XCTAssertFalse(app.buttons["DeleteEntry"].exists)
    }

    /// A Journal row is one accessibility element, so its text is matched
    /// inside the label.
    @MainActor
    private func journalRow(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    @MainActor
    private func anything(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)).firstMatch
    }

    @MainActor
    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        app.launch()
        return app
    }
}
