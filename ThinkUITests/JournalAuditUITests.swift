import XCTest

final class JournalAuditUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testProtectedJournalDoesNotRenderSeededText() throws {
        let app = launch(["-ui-journal-locked", "-ui-auth-failure", "-ui-seed-journal"])
        XCTAssertFalse(anything(app, containing: "PRIVATE AUDIT").exists)
        app.tabBars.buttons["Journal"].tap()
        let unlockExists = app.buttons["UnlockJournal"].waitForExistence(timeout: 3)
        if !unlockExists {
            print("LOCK_FIXTURE_UI \(app.debugDescription)")
            let capture = XCTAttachment(screenshot: app.screenshot())
            capture.name = "Failed authentication gate"
            capture.lifetime = .keepAlways
            add(capture)
        }
        XCTAssertTrue(unlockExists)
        XCTAssertTrue(app.staticTexts["Your journal is locked."].exists)
        app.buttons["UnlockJournal"].tap()
        XCTAssertTrue(app.buttons["UnlockJournal"].exists)
        XCTAssertFalse(anything(app, containing: "PRIVATE AUDIT").exists)
        // While locked: no search, no filter menu, no status rows; New note stays.
        XCTAssertFalse(app.searchFields.firstMatch.exists)
        XCTAssertFalse(app.buttons["JournalFilterMenu"].exists)
        XCTAssertTrue(app.buttons["NewNote"].exists)
    }

    /// The gate asks when the tab appears; after a failed attempt, Unlock
    /// asks again and opens the journal (`design/journal.md` section 7).
    @MainActor
    func testUnlockRetriesAfterAFailedAttempt() throws {
        let app = launch(["-ui-journal-locked", "-ui-auth-fail-once", "-ui-seed-journal"])
        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.buttons["UnlockJournal"].waitForExistence(timeout: 3))
        XCTAssertFalse(anything(app, containing: "PRIVATE AUDIT").exists)
        app.buttons["UnlockJournal"].tap()
        XCTAssertTrue(journalRow(app, containing: "PRIVATE AUDIT ANSWER").waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["UnlockJournal"].exists)
    }

    /// Locking while the tab is open takes every row, the search and the
    /// filters off screen and out of the accessibility tree.
    @MainActor
    func testLockingOnTheTabRemovesContentSearchAndFilters() throws {
        let app = launch(["-ui-journal-locked", "-ui-auth-success", "-ui-seed-journal", "-ui-relock-on-background"])
        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(journalRow(app, containing: "PRIVATE AUDIT ANSWER").waitForExistence(timeout: 3))
        chooseFilter(app, "Answers")
        XCTAssertTrue(app.descendants(matching: .any)["JournalActiveFilters"].waitForExistence(timeout: 3))
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("PRIVATE")
        XCTAssertTrue(journalRow(app, containing: "PRIVATE AUDIT ANSWER").waitForExistence(timeout: 3))

        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(app.buttons["UnlockJournal"].waitForExistence(timeout: 3))
        XCTAssertFalse(anything(app, containing: "PRIVATE").exists)
        XCTAssertFalse(app.searchFields.firstMatch.exists)
        XCTAssertFalse(app.buttons["JournalFilterMenu"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["JournalActiveFilters"].exists)
        XCTAssertTrue(app.buttons["NewNote"].exists)
    }

    @MainActor
    func testSuccessfulUnlockShowsSeededJournalAndDetailActions() throws {
        let app = launch(["-ui-journal-locked", "-ui-auth-success", "-ui-seed-journal"])
        // Today shows that the answer exists, never its text; opening it
        // asks Face ID first, then pushes the read detail.
        let answered = app.buttons["Act.question.done"]
        XCTAssertTrue(answered.waitForExistence(timeout: 3))
        for _ in 0..<3 where !answered.isHittable { app.swipeUp() }
        XCTAssertFalse(app.staticTexts["PRIVATE AUDIT ANSWER"].exists)
        let homeCapture = XCTAttachment(screenshot: app.screenshot())
        homeCapture.name = "Today locked answer row"
        homeCapture.lifetime = .keepAlways
        add(homeCapture)
        answered.tap()
        XCTAssertTrue(app.staticTexts["PRIVATE AUDIT ANSWER"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["JournalView"].waitForExistence(timeout: 3))
        let row = journalRow(app, containing: "PRIVATE AUDIT ANSWER")
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        XCTAssertTrue(app.buttons["EntryActions"].waitForExistence(timeout: 3))
    }

    /// A kind filter narrows the list and shows the active filters line;
    /// Clear brings every record back (`design/journal.md` section 3).
    @MainActor
    func testKindFilterNarrowsTheListAndClears() throws {
        let app = launch(["-ui-seed-journal", "-ui-seed-journal-scroll"])
        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(journalRow(app, containing: "SCROLL AUDIT NOTE 11").waitForExistence(timeout: 3))

        chooseFilter(app, "Retros")
        let line = app.descendants(matching: .any)["JournalActiveFilters"]
        XCTAssertTrue(line.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Retros"].exists)
        XCTAssertTrue(journalRow(app, containing: "PRIVATE AUDIT RETRO").waitForExistence(timeout: 3))
        XCTAssertFalse(journalRow(app, containing: "SCROLL AUDIT NOTE").exists)
        capture(app, "Journal filtered by retros")

        app.buttons["JournalClearFilters"].tap()
        XCTAssertTrue(journalRow(app, containing: "SCROLL AUDIT NOTE 11").waitForExistence(timeout: 3))
        XCTAssertFalse(line.exists)
    }

    /// A trailing swipe asks before deleting and keeps the row until the
    /// deletion is confirmed (`design/journal.md` section 2). Deleting the
    /// last record under a filter shows the whole-journal Empty state, and
    /// the filter does not outlive it (section 9).
    @MainActor
    func testSwipeDeleteConfirmsAndTheLastDeletionShowsEmpty() throws {
        let app = launch(["-ui-seed-journal"])
        app.tabBars.buttons["Journal"].tap()
        let retro = journalRow(app, containing: "PRIVATE AUDIT RETRO")
        XCTAssertTrue(retro.waitForExistence(timeout: 3))

        retro.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Delete this retro?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["It is removed from this device and your iCloud."].exists)
        XCTAssertTrue(retro.exists)
        app.buttons["ConfirmDeleteEntry"].firstMatch.tap()
        XCTAssertTrue(retro.waitForNonExistence(timeout: 3))

        chooseFilter(app, "Answers")
        XCTAssertTrue(app.descendants(matching: .any)["JournalActiveFilters"].waitForExistence(timeout: 3))
        let answer = journalRow(app, containing: "PRIVATE AUDIT ANSWER")
        XCTAssertTrue(answer.waitForExistence(timeout: 3))
        answer.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Delete this entry?"].waitForExistence(timeout: 3))
        app.buttons["ConfirmDeleteEntry"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Nothing written yet."].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["JournalFilterMenu"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["JournalActiveFilters"].exists)
        XCTAssertFalse(app.staticTexts["No entries match."].exists)

        // The first note after Empty is not hidden by a filter nobody can see.
        app.buttons["Write a note"].tap()
        let field = app.descendants(matching: .any).matching(identifier: "NewNoteInput").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("First note after empty")
        app.buttons["SaveNewNote"].tap()
        XCTAssertTrue(journalRow(app, containing: "First note after empty").waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["JournalActiveFilters"].exists)
    }

    @MainActor
    func testBlankNoteCaptureRemainsAvailableFromLockedJournal() throws {
        let app = launch(["-ui-journal-locked"])
        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.buttons["NewNote"].waitForExistence(timeout: 3))
        app.buttons["NewNote"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["NewNoteSheet"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testDraftWriteFailurePreventsCloseFromLosingWriting() throws {
        let app = launch(["-ui-fail-drafts"])
        openBlankNote(app)
        let field = app.descendants(matching: .any).matching(identifier: "NewNoteInput").firstMatch
        field.tap()
        field.typeText("Keep this failed draft")
        app.buttons["CancelJournalEditor"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["JournalSaveError"].waitForExistence(timeout: 3))
        XCTAssertTrue(field.exists)
        XCTAssertTrue((field.value as? String)?.contains("Keep this failed draft") == true)
    }

    @MainActor
    func testFailedSaveDraftSurvivesRelaunchAndCanBeSaved() throws {
        let app = launch(["-ui-fail-save"])
        openBlankNote(app)
        let marker = "Recover after save failure"
        let field = app.descendants(matching: .any).matching(identifier: "NewNoteInput").firstMatch
        field.tap()
        field.typeText(marker)
        app.buttons["SaveNewNote"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["JournalSaveError"].waitForExistence(timeout: 3))
        app.buttons["CancelJournalEditor"].tap()
        app.terminate()
        app.launchArguments = ["-ui-testing", "-ui-preserve-drafts", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.buttons["RecoverDrafts"].waitForExistence(timeout: 3))
        app.buttons["RecoverDrafts"].tap()
        XCTAssertTrue(app.staticTexts[marker].waitForExistence(timeout: 3))
        app.staticTexts[marker].tap()
        XCTAssertTrue(app.buttons["SaveNewNote"].waitForExistence(timeout: 3))
        app.buttons["SaveNewNote"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["JournalRecoveryEmpty"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testFocusReflectionEditPersistsWithoutUntouchedDraft() throws {
        let app = launch(["-ui-seed-focus"])
        app.tabBars.buttons.element(boundBy: 2).tap()
        app.buttons["FocusStats"].tap()
        let session = app.buttons["FocusSession.audit-focus-session"]
        for _ in 0..<6 { if session.isHittable { break }; app.swipeUp() }
        session.tap()
        let note = app.descendants(matching: .any).matching(identifier: "FocusNoteInput").firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 3))
        XCTAssertEqual(note.value as? String, "Original focus note")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Journal"].tap()
        XCTAssertFalse(app.buttons["RecoverDrafts"].exists)
        app.tabBars.buttons.element(boundBy: 2).tap()
        session.tap()
        note.tap()
        note.typeText(" updated")
        let edited = try XCTUnwrap(note.value as? String)
        XCTAssertTrue(edited.contains("updated"))
        app.buttons["SaveFocusNote"].tap()
        XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        session.tap()
        XCTAssertEqual(note.value as? String, edited.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @MainActor
    private func openBlankNote(_ app: XCUIApplication) {
        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.buttons["NewNote"].waitForExistence(timeout: 3))
        app.buttons["NewNote"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "NewNoteInput").firstMatch.waitForExistence(timeout: 3))
    }

    /// A Journal row is one accessibility element (`design/journal.md`
    /// section 4), so its text is matched inside the label.
    @MainActor
    private func journalRow(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    @MainActor
    private func anything(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)).firstMatch
    }

    /// Opens the filter menu and picks a kind from its inline picker.
    @MainActor
    private func chooseFilter(_ app: XCUIApplication, _ option: String) {
        let menu = app.buttons["JournalFilterMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 3))
        menu.tap()
        let item = app.buttons[option].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        item.tap()
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        app.launch()
        return app
    }
}
