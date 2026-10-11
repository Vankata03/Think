//
//  StreakSheetUITests.swift
//  ThinkUITests
//

import XCTest

/// The streak sheet against `design/progress-settings.md` section 8:
/// chrome, header states, pager bounds, the reserved six-row height
/// (`STK-1`) and what VoiceOver can reach.
final class StreakSheetUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNeverPractisedShowsStartTodayWithoutShareOrPaging() throws {
        let app = openSheet(seed: nil)

        XCTAssertEqual(app.descendants(matching: .any)["StreakHeader"].label, "Start today.")
        XCTAssertFalse(app.buttons["ShareStreak"].exists, "Nothing to share before the first practice day")
        XCTAssertTrue(app.buttons["CloseStreak"].exists)
        XCTAssertFalse(app.buttons["StreakPreviousMonth"].isEnabled)
        XCTAssertFalse(app.buttons["StreakNextMonth"].isEnabled)
    }

    @MainActor
    func testLapsedStreakSaysBeginAgainAndKeepsShare() throws {
        let app = openSheet(seed: "lapsed")

        XCTAssertEqual(app.descendants(matching: .any)["StreakHeader"].label, "Begin again.")
        XCTAssertTrue(app.buttons["ShareStreak"].exists)
    }

    @MainActor
    func testAliveStreakReadsAsOneElementAndDaysCarryTheirState() throws {
        let app = openSheet(seed: "today")

        XCTAssertEqual(app.descendants(matching: .any)["StreakHeader"].label, "13-day streak")
        XCTAssertEqual(app.buttons["StreakPreviousMonth"].label, "Previous month")
        XCTAssertEqual(app.buttons["StreakNextMonth"].label, "Next month")
        XCTAssertEqual(app.buttons["ShareStreak"].label, "Share")

        let today = Date.now
        XCTAssertTrue(app.staticTexts["\(dayName(today)), practised, today"].exists)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        if Calendar.current.isDate(yesterday, equalTo: today, toGranularity: .month) {
            XCTAssertTrue(app.staticTexts["\(dayName(yesterday)), practised"].exists)
        }
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        if Calendar.current.isDate(tomorrow, equalTo: today, toGranularity: .month) {
            XCTAssertFalse(app.staticTexts[dayName(tomorrow)].exists, "Future days are hidden")
        }
    }

    @MainActor
    func testTodayNotYetPractisedKeepsTheStreakAlive() throws {
        let app = openSheet(seed: "yesterday")

        XCTAssertEqual(app.descendants(matching: .any)["StreakHeader"].label, "13-day streak")
        XCTAssertTrue(app.staticTexts["\(dayName(.now)), today"].exists)
    }

    /// Paging from the current month back to the first practice month
    /// never moves the sheet's top edge, and stops there.
    @MainActor
    func testPagingStopsAtTheFirstPracticeMonthWithoutResizing() throws {
        let app = openSheet(seed: "today")
        let previous = app.buttons["StreakPreviousMonth"]
        let next = app.buttons["StreakNextMonth"]
        let title = app.staticTexts["StreakMonthTitle"]
        let sheetTop = app.navigationBars["Streak"].frame.minY

        XCTAssertFalse(next.isEnabled)
        var pages = 0
        while previous.isEnabled && pages < 4 {
            let before = title.label
            previous.tap()
            pages += 1
            XCTAssertTrue(waitForChange(of: title, from: before))
            XCTAssertEqual(app.navigationBars["Streak"].frame.minY, sheetTop, accuracy: 1, "STK-1: paging resized the sheet")
        }
        // Practice began 40 days ago: one or two months back.
        XCTAssertTrue((1...2).contains(pages))
        XCTAssertFalse(previous.isEnabled)
        XCTAssertTrue(next.isEnabled)
    }

    @MainActor
    func testLinearFormAtAccessibilitySizes() throws {
        let app = openSheet(
            seed: "today",
            extra: [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL",
            ])
        let linear = app.descendants(matching: .any)["StreakLinear"]

        XCTAssertTrue(linear.waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["StreakGrid"].exists)
        let day = Calendar.current.component(.day, from: .now)
        let title = Date.now.formatted(.dateTime.month(.wide).year())
        XCTAssertTrue(linear.label.hasPrefix("\(title), "))
        XCTAssertTrue(linear.label.hasSuffix(" of \(day) days practised"))
    }

    // MARK: - Helpers

    private func openSheet(seed: String?, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        if let seed { app.launchArguments += ["-ui-seed-streak", seed] }
        app.launch()
        let streak = app.buttons["TodayStreak"]
        XCTAssertTrue(streak.waitForExistence(timeout: 5))
        streak.tap()
        let bar = app.navigationBars["Streak"]
        XCTAssertTrue(bar.waitForExistence(timeout: 3))
        // Let the presentation and the fitted detent settle.
        var last = CGFloat.nan
        for _ in 0..<20 {
            let top = bar.frame.minY
            if top == last { break }
            last = top
            usleep(500_000)
        }
        return app
    }

    /// The day's spoken date as the sheet formats it in `en_US`.
    private func dayName(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: Locale(identifier: "en_US")).day().month(.wide))
    }

    private func waitForChange(of element: XCUIElement, from label: String) -> Bool {
        let predicate = NSPredicate(format: "label != %@", label)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 3)
            == .completed
    }
}
