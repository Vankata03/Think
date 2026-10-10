//
//  ProgressUITests.swift
//  ThinkUITests
//

import XCTest

/// The Progress tab against `design/progress-settings.md` sections 1, 2
/// and 6: real store data, empty states, the lock on intentions, medals
/// and the Focus history without a detail route.
final class ProgressUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSeededProgressShowsEverySectionInOrder() throws {
        let app = openProgress(["-ui-seed-progress"])

        let streak = app.buttons["ProgressStreak"]
        XCTAssertTrue(streak.waitForExistence(timeout: 3))
        XCTAssertEqual(streak.label, "7 day streak")
        XCTAssertTrue(app.buttons["OpenWeeklyReview"].label.contains("of 7 days"))

        let ordered = [
            element(app, "ProgressStreak"),
            element(app, "OpenWeeklyReview"),
            element(app, "Practice.focusSessions"),
            element(app, "PracticeWeekChart"),
            element(app, "EarnedMedal.streak-7"),
            element(app, "AllAchievements"),
            element(app, "FocusSession.audit-progress-partial"),
            element(app, "SeeAllSessions"),
        ]
        var previous: XCUIElement?
        for item in ordered {
            reveal(item, in: app)
            // Sections come down the List in the brief's order.
            if let previous, previous.exists, previous.isHittable {
                XCTAssertLessThan(previous.frame.minY, item.frame.minY, item.identifier)
            }
            previous = item
        }
        // Ten completed sessions; the partial one is not counted.
        XCTAssertTrue(element(app, "Practice.focusSessions").label.hasPrefix("10"))
        XCTAssertTrue(element(app, "EarnedMedal.focus-10").exists)
        // Two recent rows, newest first: the partial session, then the intention's session.
        let partial = element(app, "FocusSession.audit-progress-partial")
        XCTAssertTrue(partial.label.contains("Partial effort"))
        let newest = element(app, "FocusSession.audit-progress-day-0")
        XCTAssertTrue(newest.label.contains("Draft the Progress audit"))
        XCTAssertLessThan(partial.frame.minY, newest.frame.minY)
    }

    @MainActor
    func testEmptyProgressShowsZeroStatesAndRoutesToFocus() throws {
        let app = openProgress([])

        let streak = app.buttons["ProgressStreak"]
        XCTAssertTrue(streak.waitForExistence(timeout: 3))
        XCTAssertEqual(streak.label, "Start today.")
        XCTAssertTrue(app.buttons["OpenWeeklyReview"].label.contains("0 of 7 days"))
        XCTAssertTrue(element(app, "PracticeWeekEmpty").exists)
        XCTAssertFalse(element(app, "PracticeWeekChart").exists)
        XCTAssertTrue(app.staticTexts["Medals you earn appear here."].exists)

        let start = app.buttons["StartFocusSession"]
        reveal(start, in: app)
        XCTAssertTrue(app.staticTexts["No focus sessions yet."].exists)
        XCTAssertFalse(app.buttons["SeeAllSessions"].exists)
        start.tap()
        XCTAssertTrue(app.descendants(matching: .any)["FocusTimer"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testStreakHeroOpensTheStreakSheet() throws {
        let app = openProgress(["-ui-seed-progress"])
        app.buttons["ProgressStreak"].tap()
        XCTAssertTrue(app.navigationBars["Streak"].waitForExistence(timeout: 3))
        // A sheet, not a push: Progress stays underneath, without a back button.
        XCTAssertFalse(app.navigationBars["Streak"].buttons["Progress"].exists)
    }

    @MainActor
    func testAllAchievementsLocksAndSharesMedals() throws {
        let app = openProgress(["-ui-seed-progress"])
        let all = app.buttons["AllAchievements"]
        reveal(all, in: app)
        all.tap()
        XCTAssertTrue(app.navigationBars["Achievements"].waitForExistence(timeout: 3))

        let locked = element(app, "Achievement.streak-21")
        XCTAssertTrue(locked.waitForExistence(timeout: 2))
        XCTAssertEqual(locked.label, "21 day streak")
        XCTAssertEqual(locked.value as? String, "Locked")
        XCTAssertTrue(app.staticTexts["Reach a 21-day streak to unlock"].exists)

        let earned = app.buttons["Achievement.focus-10"]
        reveal(earned, in: app)
        XCTAssertEqual(earned.value as? String, "Earned")
        earned.tap()
        XCTAssertTrue(app.descendants(matching: .any)["AchievementShareSheet"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["AchievementShare"].exists)
        XCTAssertEqual(app.buttons["DismissAchievementShare"].label, "Close")
        app.buttons["DismissAchievementShare"].tap()
        XCTAssertTrue(app.navigationBars["Achievements"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testLockingTheJournalRemovesIntentionsAtOnce() throws {
        let app = openProgress(["-ui-seed-progress", "-ui-journal-locked", "-ui-auth-success", "-ui-relock-on-background"])
        let row = element(app, "FocusSession.audit-progress-day-0")
        reveal(row, in: app)
        XCTAssertFalse(row.label.contains("Draft the Progress audit"))

        app.tabBars.buttons["Journal"].tap()
        let unlock = app.buttons["UnlockJournal"]
        if unlock.waitForExistence(timeout: 2) { unlock.tap() }
        XCTAssertTrue(app.descendants(matching: .any)["JournalView"].waitForExistence(timeout: 3))
        app.tabBars.buttons.element(boundBy: 4).tap()
        reveal(row, in: app)
        XCTAssertTrue(row.label.contains("Draft the Progress audit"))

        XCUIDevice.shared.press(.home)
        app.activate()
        reveal(row, in: app)
        XCTAssertFalse(row.label.contains("Draft the Progress audit"))
        XCTAssertFalse(app.staticTexts["Draft the Progress audit"].exists)
    }

    @MainActor
    func testFocusHistoryListsSessionsWithoutADetailRoute() throws {
        let app = openProgress(["-ui-seed-progress"])
        let seeAll = app.buttons["SeeAllSessions"]
        reveal(seeAll, in: app)
        seeAll.tap()
        XCTAssertTrue(app.navigationBars["Focus history"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["This week"].exists || app.staticTexts["THIS WEEK"].exists)

        let row = element(app, "FocusSession.audit-progress-extra-0")
        reveal(row, in: app)
        XCTAssertTrue(row.label.contains("Actual duration unknown"))
        row.tap()
        XCTAssertTrue(app.navigationBars["Focus history"].exists)
        XCTAssertFalse(app.navigationBars["After the session"].exists)
    }

    @MainActor
    func testFocusTabNoLongerLinksToStats() throws {
        let app = launch([])
        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.descendants(matching: .any)["FocusTimer"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["FocusStats"].exists)
    }

    // MARK: - Helpers

    @MainActor
    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        app.launch()
        return app
    }

    @MainActor
    private func openProgress(_ extra: [String]) -> XCUIApplication {
        let app = launch(extra)
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 3))
        return app
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, element.identifier)
    }
}
