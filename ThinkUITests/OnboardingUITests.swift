//
//  OnboardingUITests.swift
//  ThinkUITests
//

import XCTest

/// First-launch onboarding against `design/onboarding.md`. `-ui-onboarding`
/// shows it on a fresh install; the notification prompt is a scripted
/// stand-in for the system alert (`-ui-notifications-denied` starts it
/// answered), so each test starts from a fresh answer.
final class OnboardingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testContinueAsksOnceAndADenialLeavesAllRemindersOff() throws {
        let app = launch()

        assertNoPrompt(app)
        primary(app).tap()
        let retro = app.switches["Onboarding.EveningRetro"]
        XCTAssertTrue(retro.waitForExistence(timeout: 3))
        flip(retro)
        // Flipping switches asks nothing.
        assertNoPrompt(app)

        primary(app).tap()
        let prompt = app.alerts["UITestNotificationPrompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 3))
        prompt.buttons["Don't Allow"].tap()

        XCTAssertTrue(app.navigationBars["Make it yours"].waitForExistence(timeout: 3))
        assertNoPrompt(app)
        XCTAssertFalse(app.buttons["OnboardingSkip"].exists, "No Skip on the last step")
        XCTAssertEqual(primary(app).label, "Begin practice")
        primary(app).tap()

        XCTAssertTrue(app.descendants(matching: .any)["TodayDayArc"].waitForExistence(timeout: 5))
        assertNoPrompt(app)
        openSettings(app)
        XCTAssertTrue(app.descendants(matching: .any)["NotificationPermissionDenied"].waitForExistence(timeout: 3))
        assertSwitch(app, "DailyLineReminder", isOn: false)
        assertSwitch(app, "EveningRetroReminder", isOn: false)
        assertSwitch(app, "SessionEndAlerts", isOn: false)
    }

    @MainActor
    func testAllowingSavesTheSwitchesThatAreOn() throws {
        let app = launch()

        primary(app).tap()
        let retro = app.switches["Onboarding.EveningRetro"]
        XCTAssertTrue(retro.waitForExistence(timeout: 3))
        flip(retro)
        XCTAssertEqual(retro.value as? String, "0")
        primary(app).tap()
        let prompt = app.alerts["UITestNotificationPrompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 3))
        prompt.buttons["Allow"].tap()
        XCTAssertTrue(app.navigationBars["Make it yours"].waitForExistence(timeout: 3))
        primary(app).tap()

        XCTAssertTrue(app.descendants(matching: .any)["TodayDayArc"].waitForExistence(timeout: 5))
        openSettings(app)
        XCTAssertTrue(app.switches["DailyLineReminder"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["NotificationPermissionDenied"].exists)
        assertSwitch(app, "DailyLineReminder", isOn: true)
        assertSwitch(app, "EveningRetroReminder", isOn: false)
        assertSwitch(app, "SessionEndAlerts", isOn: true)
    }

    @MainActor
    func testSkipNeverAsksAndLeavesRemindersOff() throws {
        let app = launch()

        XCTAssertTrue(app.buttons["OnboardingSkip"].waitForExistence(timeout: 3))
        primary(app).tap()
        XCTAssertTrue(app.switches["Onboarding.DailyLine"].waitForExistence(timeout: 3))
        app.buttons["OnboardingSkip"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["TodayDayArc"].waitForExistence(timeout: 5))
        assertNoPrompt(app)
        openSettings(app)
        XCTAssertTrue(app.switches["DailyLineReminder"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["NotificationPermissionDenied"].exists, "Never asked")
        assertSwitch(app, "DailyLineReminder", isOn: false)
        assertSwitch(app, "EveningRetroReminder", isOn: false)
        assertSwitch(app, "SessionEndAlerts", isOn: false)
    }

    @MainActor
    func testAnEarlierDenialAsksNothingAndSavesAllOff() throws {
        let app = launch(["-ui-notifications-denied"])

        primary(app).tap()
        XCTAssertTrue(app.switches["Onboarding.DailyLine"].waitForExistence(timeout: 3))
        primary(app).tap()
        XCTAssertTrue(app.navigationBars["Make it yours"].waitForExistence(timeout: 3))
        assertNoPrompt(app)
    }

    @MainActor
    func testAppearanceTilesRepaintTheScreenInBothDirections() throws {
        XCUIDevice.shared.appearance = .light
        let app = launch(["-ui-notifications-denied"])
        primary(app).tap()
        primary(app).tap()
        XCTAssertTrue(app.navigationBars["Make it yours"].waitForExistence(timeout: 3))

        let dark = app.buttons["Appearance.dark"]
        let auto = app.buttons["Appearance.system"]
        let light = app.buttons["Appearance.light"]
        XCTAssertTrue(dark.isSelected, "Dark is chosen on a new installation")
        XCTAssertLessThan(backgroundBrightness(app), 0.2)

        light.tap()
        XCTAssertTrue(light.isSelected)
        XCTAssertGreaterThan(waitForBrightness(app, above: true), 0.8)
        dark.tap()
        XCTAssertLessThan(waitForBrightness(app, above: false), 0.2)
        auto.tap()
        XCTAssertTrue(auto.isSelected)
        XCTAssertGreaterThan(waitForBrightness(app, above: true), 0.8, "Auto follows the light device")
    }

    @MainActor
    func testAnUpgradingUserLandsOnToday() throws {
        let app = launch(["-hasCompletedOnboarding", "YES"])

        XCTAssertTrue(app.descendants(matching: .any)["TodayDayArc"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["OnboardingPrimary"].exists)
    }

    @MainActor
    func testStepCountDotsAndTilesAtTheDefaultSize() throws {
        let app = launch(["-ui-notifications-denied"])

        XCTAssertTrue(app.descendants(matching: .any)["OnboardingDayArc"].waitForExistence(timeout: 3))
        let count = app.descendants(matching: .any)["OnboardingStepCount"]
        XCTAssertEqual(count.label, "Step 1 of 3")
        XCTAssertEqual(primary(app).label, "Continue")
        primary(app).tap()
        XCTAssertTrue(app.navigationBars["Reminders"].waitForExistence(timeout: 3))
        XCTAssertEqual(count.label, "Step 2 of 3")
        primary(app).tap()
        XCTAssertTrue(app.navigationBars["Make it yours"].waitForExistence(timeout: 3))
        XCTAssertEqual(count.label, "Step 3 of 3")

        let dark = app.buttons["Appearance.dark"].frame
        let light = app.buttons["Appearance.light"].frame
        XCTAssertEqual(dark.midY, light.midY, accuracy: dark.height / 4, "Tiles sit side by side")
        XCTAssertLessThan(dark.midX, light.midX)
    }

    @MainActor
    func testAccessibilitySizesDropTheArcAndDotsAndStackTheTiles() throws {
        let app = launch(["-ui-notifications-denied",
                          "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])

        XCTAssertTrue(primary(app).waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["OnboardingDayArc"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["OnboardingStepCount"].exists)
        primary(app).tap()
        primary(app).tap()
        XCTAssertTrue(app.navigationBars["Make it yours"].waitForExistence(timeout: 3))

        let dark = app.buttons["Appearance.dark"].frame
        let auto = app.buttons["Appearance.system"].frame
        XCTAssertLessThan(dark.maxY, auto.midY, "Tiles stack at accessibility sizes")
    }

    // MARK: Helpers

    @MainActor
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-onboarding"] + arguments
        app.launch()
        return app
    }

    @MainActor
    private func primary(_ app: XCUIApplication) -> XCUIElement {
        let button = app.buttons["OnboardingPrimary"]
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        return button
    }

    /// Taps the switch itself, at the trailing end of its row.
    @MainActor
    private func flip(_ toggle: XCUIElement) {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }

    @MainActor
    private func assertNoPrompt(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(app.alerts["UITestNotificationPrompt"].waitForExistence(timeout: 1), file: file, line: line)
    }

    @MainActor
    private func openSettings(_ app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: 4).tap()
        let gear = app.navigationBars.buttons["Settings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 3))
        gear.tap()
    }

    @MainActor
    private func assertSwitch(_ app: XCUIApplication, _ identifier: String, isOn: Bool,
                              file: StaticString = #filePath, line: UInt = #line) {
        let toggle = app.switches[identifier].firstMatch
        for _ in 0..<4 where !toggle.isHittable { app.swipeUp() }
        XCTAssertEqual(toggle.value as? String, isOn ? "1" : "0", identifier, file: file, line: line)
    }

    /// The grouped background beside the large title, from 0 (black) to 1.
    @MainActor
    private func backgroundBrightness(_ app: XCUIApplication) -> Double {
        let image = app.screenshot().image
        guard let cgImage = image.cgImage else { return -1 }
        let x = Int(Double(cgImage.width) * 0.03)
        let y = Int(Double(cgImage.height) * 0.16)
        guard let cropped = cgImage.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else { return -1 }
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (Double(pixel[0]) + Double(pixel[1]) + Double(pixel[2])) / (3 * 255)
    }

    /// The repaint animates; poll until it settles past the threshold.
    @MainActor
    private func waitForBrightness(_ app: XCUIApplication, above: Bool) -> Double {
        var value = backgroundBrightness(app)
        for _ in 0..<10 {
            if above ? value > 0.8 : value < 0.2 { break }
            Thread.sleep(forTimeInterval: 0.2)
            value = backgroundBrightness(app)
        }
        return value
    }
}
