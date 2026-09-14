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
        app.tabBars.buttons.element(boundBy: 3).tap()
        capture(app, "07 Your practice")
        let settings = app.buttons["ProfileSettings"]
        reveal(settings, in: app)
        settings.tap()
        capture(app, "08 Settings top")
        app.swipeUp()
        capture(app, "09 Settings lower")

        app.terminate()
        app.launch()
        app.tabBars.buttons.element(boundBy: 3).tap()
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
