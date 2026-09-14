import XCTest

final class JournalAuditUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testProtectedJournalDoesNotRenderSeededText() throws {
        let app = launch(["-ui-journal-locked", "-ui-auth-failure", "-ui-seed-journal"])
        XCTAssertFalse(app.staticTexts["PRIVATE AUDIT ANSWER"].exists)
        XCTAssertFalse(app.staticTexts["PRIVATE AUDIT RETRO"].exists)
        app.buttons["Journal"].tap()
        let unlockExists = app.buttons["UnlockJournal"].waitForExistence(timeout: 3)
        if !unlockExists {
            print("LOCK_FIXTURE_UI \(app.debugDescription)")
            let capture = XCTAttachment(screenshot: app.screenshot())
            capture.name = "Failed authentication gate"
            capture.lifetime = .keepAlways
            add(capture)
        }
        XCTAssertTrue(unlockExists)
        app.buttons["UnlockJournal"].tap()
        XCTAssertTrue(app.buttons["UnlockJournal"].exists)
        XCTAssertFalse(app.staticTexts["PRIVATE AUDIT ANSWER"].exists)
        XCTAssertFalse(app.staticTexts["PRIVATE AUDIT RETRO"].exists)
    }

    @MainActor
    func testSuccessfulUnlockShowsSeededJournalAndDetailActions() throws {
        let app = launch(["-ui-journal-locked", "-ui-auth-success", "-ui-seed-journal"])
        let unlock = app.buttons["UnlockToRead"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 3))
        for _ in 0..<3 where !unlock.isHittable { app.swipeUp() }
        let homeCapture = XCTAttachment(screenshot: app.screenshot())
        homeCapture.name = "Home unlock alignment"
        homeCapture.lifetime = .keepAlways
        add(homeCapture)
        app.buttons["Journal"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["JournalView"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["PRIVATE AUDIT ANSWER"].waitForExistence(timeout: 3))
        app.staticTexts["PRIVATE AUDIT ANSWER"].tap()
        XCTAssertTrue(app.buttons["EntryActions"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testJournalFiltersScrollWithEntries() throws {
        let app = launch(["-ui-seed-journal"])
        app.buttons["Journal"].tap()
        let controls = app.descendants(matching: .any)["JournalFilters"]
        XCTAssertTrue(controls.waitForExistence(timeout: 3))
        let before = controls.frame.minY
        let top = XCTAttachment(screenshot: app.screenshot())
        top.name = "Journal scrolling controls top"
        top.lifetime = .keepAlways
        add(top)
        app.swipeUp()
        if controls.exists && controls.isHittable {
            XCTAssertLessThan(controls.frame.minY, before - 20)
        }
        let scrolled = XCTAttachment(screenshot: app.screenshot())
        scrolled.name = "Journal scrolling controls scrolled"
        scrolled.lifetime = .keepAlways
        add(scrolled)
    }

    @MainActor
    func testBlankNoteCaptureRemainsAvailableFromLockedJournal() throws {
        let app = launch(["-ui-journal-locked"])
        app.buttons["Journal"].tap()
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
        app.buttons["Close"].tap()
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
        app.buttons["Close"].tap()
        app.terminate()
        app.launchArguments = ["-ui-testing", "-ui-preserve-drafts", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.buttons["Journal"].tap()
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
        app.tabBars.buttons.element(boundBy: 0).tap()
        app.buttons["OpenJournal"].tap()
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
        app.buttons["Journal"].tap()
        XCTAssertTrue(app.buttons["NewNote"].waitForExistence(timeout: 3))
        app.buttons["NewNote"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "NewNoteInput").firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        app.launch()
        return app
    }
}
