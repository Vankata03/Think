import XCTest

/// Repeat on the audit simulator matrix; retained screenshots are inspected
/// by the integrator. Accessibility-tree checks do not certify spoken VoiceOver.
final class VisualAuditUITests: XCTestCase {
    @MainActor
    func testCapturePrimaryScreens() throws {
        try capturePrimaryScreens(language: nil)
    }

    @MainActor
    func testCaptureGermanScreens() throws {
        try capturePrimaryScreens(language: "de")
    }

    @MainActor
    private func capturePrimaryScreens(language: String?) throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-seed-journal"]
        if let language {
            app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", "de_DE"]
        }
        app.launch()
        XCTAssertTrue(app.buttons["OpenJournal"].waitForExistence(timeout: 5))
        capture(app, "01 Today top")
        app.swipeUp()
        capture(app, "02 Today activities")
        app.tabBars.buttons.element(boundBy: 1).tap()
        capture(app, "03 Paths")
        app.buttons["Path.deep-focus"].tap()
        capture(app, "04 Path lesson")
        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.descendants(matching: .any)["FocusTimer"].waitForExistence(timeout: 3))
        capture(app, "05 Focus top")
        app.swipeUp()
        capture(app, "06 Focus controls")
        app.tabBars.buttons.element(boundBy: 4).tap()
        capture(app, "07 Your practice")
        let settings = app.buttons["ProfileSettings"]
        reveal(settings, in: app)
        settings.tap()
        capture(app, "08 Settings top")
        app.swipeUp()
        capture(app, "09 Settings lower")

        app.terminate()
        app.launch()
        app.tabBars.buttons.element(boundBy: 4).tap()
        let weekly = app.buttons["OpenWeeklyReview"]
        reveal(weekly, in: app)
        weekly.tap()
        capture(app, "10 Weekly review")

        app.terminate()
        app.launch()
        app.buttons["OpenJournal"].tap()
        let answer = app.staticTexts["PRIVATE AUDIT ANSWER"]
        reveal(answer, in: app)
        capture(app, "11 Journal")
        answer.tap()
        capture(app, "12 Journal detail")
    }

    /// The journal editor across the acceptance floor (`journal.md`
    /// section 13): both appearances, AX3, and `de` and `bg` on the chips.
    /// Asserts the chips stay on screen and stack at AX3; the screenshots
    /// show the long entry staying above the keyboard (`JRN-4`).
    @MainActor
    func testCaptureJournalEditor() throws {
        continueAfterFailure = false
        let runs: [(name: String, appearance: String, language: String, locale: String, ax3: Bool, labels: [String])] = [
            ("dark en", "dark", "en", "en_US", false, ["Sharp", "Learning", "Making"]),
            ("light en", "light", "en", "en_US", false, ["Sharp", "Learning", "Making"]),
            ("dark de AX3", "dark", "de", "de_DE", true, ["Klar", "Lernen", "Gestalten"]),
            ("light bg AX3", "light", "bg", "bg_BG", true, ["Изострено", "Учене", "Творене"]),
        ]
        for run in runs {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-appearance", run.appearance,
                                   "-AppleLanguages", "(\(run.language))", "-AppleLocale", run.locale]
            if run.ax3 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"] }
            app.launch()
            let write = app.buttons["WriteDailyAnswer"]
            reveal(write, in: app)
            write.tap()
            let mood = app.buttons["MoodChip"]
            let theme = app.buttons["ThemeChip"]
            XCTAssertTrue(theme.waitForExistence(timeout: 3))
            capture(app, "Editor \(run.name) empty")

            mood.tap()
            app.buttons[run.labels[0]].tap()
            theme.tap()
            app.buttons[run.labels[1]].tap()
            capture(app, "Editor \(run.name) theme menu")
            app.buttons[run.labels[2]].tap()
            app.navigationBars.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let width = app.windows.firstMatch.frame.width
            XCTAssertLessThanOrEqual(mood.frame.maxX, width)
            XCTAssertLessThanOrEqual(theme.frame.maxX, width)
            if run.ax3 { XCTAssertGreaterThanOrEqual(theme.frame.minY, mood.frame.maxY) }
            capture(app, "Editor \(run.name) chips")

            let field = app.descendants(matching: .any).matching(identifier: "JournalEntryInput").firstMatch
            // A new answer focuses its field on appear. Whether the keyboard
            // is still up after the menus depends on timing; when it is, it
            // covers the field's centre and the field already has focus.
            if !app.keyboards.firstMatch.exists { field.tap() }
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
            app.typeText((1...14).map { "Line \($0) of a long entry that keeps going" }.joined(separator: "\n"))
            capture(app, "Editor \(run.name) long entry")
            app.terminate()
        }
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if element.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
