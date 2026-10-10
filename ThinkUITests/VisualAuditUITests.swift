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
        XCTAssertTrue(app.descendants(matching: .any)["TodayDayArc"].waitForExistence(timeout: 5))
        capture(app, "01 Today top")
        app.swipeUp()
        capture(app, "02 Today acts")
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
        capture(app, "07 Progress")
        app.navigationBars.buttons["Settings"].tap()
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
        app.tabBars.buttons["Journal"].tap()
        let answer = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "PRIVATE AUDIT ANSWER")).firstMatch
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

    /// Progress across the acceptance floor (`progress-settings.md`
    /// section 6): both appearances, AX3 in `en`, `bg` and `de`, and the
    /// zero states. At AX3 the medals stack and the week chart becomes
    /// labelled day rows; every section scrolls above the tab bar.
    @MainActor
    func testCaptureProgress() throws {
        continueAfterFailure = false
        let runs: [(name: String, appearance: String, language: String, locale: String, ax3: Bool, seeded: Bool)] = [
            ("dark en", "dark", "en", "en_US", false, true),
            ("light en", "light", "en", "en_US", false, true),
            ("dark en empty", "dark", "en", "en_US", false, false),
            ("dark en AX3", "dark", "en", "en_US", true, true),
            ("light bg AX3", "light", "bg", "bg_BG", true, true),
            ("dark de AX3", "dark", "de", "de_DE", true, true),
        ]
        for run in runs {
            let app = XCUIApplication()
            app.launchArguments = [
                "-ui-testing", "-appearance", run.appearance,
                "-AppleLanguages", "(\(run.language))", "-AppleLocale", run.locale,
            ]
            if run.seeded { app.launchArguments += ["-ui-seed-progress"] }
            if run.ax3 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"] }
            app.launch()
            app.tabBars.buttons.element(boundBy: 4).tap()
            XCTAssertTrue(app.buttons["ProgressStreak"].waitForExistence(timeout: 3))
            capture(app, "Progress \(run.name) top")

            if run.ax3 {
                // Labelled day rows replace the chart; medals stack.
                XCTAssertFalse(app.descendants(matching: .any)["PracticeWeekChart"].exists)
                let first = app.descendants(matching: .any)["EarnedMedal.streak-7"]
                let second = app.descendants(matching: .any)["EarnedMedal.focus-10"]
                var swipes = 0
                while !(second.exists && second.isHittable) && swipes < 20 {
                    app.swipeUp()
                    swipes += 1
                }
                if first.exists && second.exists {
                    XCTAssertGreaterThanOrEqual(second.frame.minY, first.frame.maxY, "Medals stack at AX3")
                }
            }

            let last = app.buttons[run.seeded ? "SeeAllSessions" : "StartFocusSession"]
            var swipes = 0
            while !(last.exists && last.isHittable) && swipes < 30 {
                app.swipeUp()
                swipes += 1
                if swipes % 3 == 0 { capture(app, "Progress \(run.name) scroll \(swipes / 3)") }
            }
            app.swipeUp()
            XCTAssertTrue(last.isHittable)
            XCTAssertLessThanOrEqual(last.frame.maxY, app.tabBars.firstMatch.frame.minY, "Last row sits above the tab bar")
            capture(app, "Progress \(run.name) bottom")

            if run.seeded {
                let all = app.buttons["AllAchievements"]
                scrollClearOfBars(all, in: app, defaultUp: false)
                all.tap()
                XCTAssertTrue(app.descendants(matching: .any)["AchievementsView"].waitForExistence(timeout: 3))
                capture(app, "Achievements \(run.name) top")
                app.swipeUp()
                app.swipeUp()
                capture(app, "Achievements \(run.name) bottom")
                app.navigationBars.buttons.element(boundBy: 0).tap()

                scrollClearOfBars(last, in: app, defaultUp: true)
                last.tap()
                XCTAssertTrue(app.descendants(matching: .any)["FocusHistoryView"].waitForExistence(timeout: 3))
                capture(app, "Focus history \(run.name) top")
                app.swipeUp()
                capture(app, "Focus history \(run.name) lower")
            }
            app.terminate()
        }
    }

    /// Settings across the acceptance floor (`progress-settings.md`
    /// section 6): both appearances, and AX3 in `en`, `bg` and `de`. The
    /// gear is labelled "Settings", and the Form scrolls its last row,
    /// About's version, fully above the tab bar.
    @MainActor
    func testCaptureSettings() throws {
        continueAfterFailure = false
        let runs: [(name: String, appearance: String, language: String, locale: String, ax3: Bool)] = [
            ("dark en", "dark", "en", "en_US", false),
            ("light en", "light", "en", "en_US", false),
            ("dark en AX3", "dark", "en", "en_US", true),
            ("light bg AX3", "light", "bg", "bg_BG", true),
            ("dark de AX3", "dark", "de", "de_DE", true),
        ]
        for run in runs {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-appearance", run.appearance,
                                   "-AppleLanguages", "(\(run.language))", "-AppleLocale", run.locale]
            if run.ax3 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"] }
            app.launch()
            app.tabBars.buttons.element(boundBy: 4).tap()
            let gear = app.navigationBars.buttons["Settings"]
            XCTAssertTrue(gear.waitForExistence(timeout: 3))
            if run.language == "en" { XCTAssertEqual(gear.label, "Settings") }
            gear.tap()
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "DailyLineReminder").firstMatch.waitForExistence(timeout: 3))
            capture(app, "Settings \(run.name) top")

            let version = app.descendants(matching: .any).matching(identifier: "AppVersion").firstMatch
            var swipes = 0
            while !(version.exists && version.isHittable) && swipes < 30 {
                app.swipeUp()
                swipes += 1
                if swipes % 3 == 0 { capture(app, "Settings \(run.name) scroll \(swipes / 3)") }
            }
            app.swipeUp()
            XCTAssertTrue(version.isHittable)
            XCTAssertLessThanOrEqual(version.frame.maxY, app.tabBars.firstMatch.frame.minY, "About sits above the tab bar")
            capture(app, "Settings \(run.name) bottom")
            app.terminate()
        }
    }

    /// The Journal list across the acceptance floor (`design/journal.md`
    /// section 13): both appearances, AX3, and `de` and `bg` on the filter
    /// names and headers. Captures the timeline, the filter menu, a filter
    /// with its active line, the Empty state and the Locked state, for the
    /// comparison with `JRN-1`, `JRN-2` and `JRN-5` in the inventory.
    @MainActor
    func testCaptureJournalList() throws {
        continueAfterFailure = false
        let runs: [(name: String, appearance: String, language: String, locale: String, ax3: Bool, retros: String)] = [
            ("dark en", "dark", "en", "en_GB", false, "Retros"),
            ("light en", "light", "en", "en_GB", false, "Retros"),
            ("dark de AX3", "dark", "de", "de_DE", true, "Rückblicke"),
            ("light bg AX3", "light", "bg", "bg_BG", true, "Равносметки"),
        ]
        for run in runs {
            var arguments = ["-ui-testing", "-appearance", run.appearance,
                             "-AppleLanguages", "(\(run.language))", "-AppleLocale", run.locale]
            if run.ax3 { arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"] }

            let app = XCUIApplication()
            app.launchArguments = arguments + ["-ui-seed-journal-list"]
            app.launch()
            app.tabBars.buttons.element(boundBy: 3).tap()
            let menu = app.buttons["JournalFilterMenu"]
            XCTAssertTrue(menu.waitForExistence(timeout: 3))
            XCTAssertTrue(app.buttons["RecoverDrafts"].exists)
            let width = app.windows.firstMatch.frame.width
            for row in app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'JournalRow.'")).allElementsBoundByIndex
            where row.isHittable {
                XCTAssertLessThanOrEqual(row.frame.maxX, width)
            }
            capture(app, "Journal \(run.name) timeline")
            // The detail at the same size, for `JRN-5` and `JRN-6`.
            // At AX3 a row's centre can sit under the tab bar; tap its top.
            let firstRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'JournalRow.'")).firstMatch
            firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
            XCTAssertTrue(app.descendants(matching: .any)["JournalEntryDetail"].waitForExistence(timeout: 3))
            capture(app, "Journal \(run.name) detail")
            app.swipeUp()
            capture(app, "Journal \(run.name) detail scrolled")
            // Reselecting the tab pops to the list in every language.
            app.tabBars.buttons.element(boundBy: 3).tap()
            XCTAssertTrue(menu.waitForExistence(timeout: 3) && menu.isHittable)
            app.swipeUp()
            capture(app, "Journal \(run.name) timeline scrolled")
            app.swipeDown()
            app.swipeDown()

            menu.tap()
            capture(app, "Journal \(run.name) filter menu")
            app.buttons[run.retros].firstMatch.tap()
            let line = app.descendants(matching: .any)["JournalActiveFilters"]
            XCTAssertTrue(line.waitForExistence(timeout: 3))
            XCTAssertLessThanOrEqual(app.buttons["JournalClearFilters"].frame.maxX, width)
            XCTAssertFalse(app.buttons["RecoverDrafts"].exists)
            capture(app, "Journal \(run.name) filtered")
            if run.language == "en" {
                // The No-match states of design-system section 8, with their lines.
                app.buttons["JournalClearFilters"].tap()
                menu.tap()
                app.buttons["Theme"].firstMatch.tap()
                app.buttons["Money"].firstMatch.tap()
                XCTAssertTrue(app.staticTexts["No entries match."].waitForExistence(timeout: 3))
                XCTAssertTrue(app.buttons["Clear filters"].exists)
                capture(app, "Journal \(run.name) filter no match")
                app.buttons["Clear filters"].tap()
                let search = app.searchFields.firstMatch
                search.tap()
                search.typeText("zzqx")
                let noResults = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "zzqx")).firstMatch
                XCTAssertTrue(noResults.waitForExistence(timeout: 3))
                capture(app, "Journal \(run.name) search no match")
            }
            app.terminate()

            app.launchArguments = arguments
            app.launch()
            app.tabBars.buttons.element(boundBy: 3).tap()
            XCTAssertTrue(app.descendants(matching: .any)["JournalEmpty"].waitForExistence(timeout: 3))
            XCTAssertFalse(app.buttons["JournalFilterMenu"].exists)
            if run.language == "en" {
                XCTAssertTrue(app.staticTexts["Nothing written yet."].exists)
                XCTAssertTrue(app.buttons["Write a note"].exists)
            }
            capture(app, "Journal \(run.name) empty")
            app.terminate()

            app.launchArguments = arguments + ["-ui-journal-locked", "-ui-auth-failure", "-ui-seed-journal-list"]
            app.launch()
            app.tabBars.buttons.element(boundBy: 3).tap()
            XCTAssertTrue(app.buttons["UnlockJournal"].waitForExistence(timeout: 3))
            capture(app, "Journal \(run.name) locked")
            app.terminate()
        }
    }

    /// Today across its acceptance floor (`today.md` section 7): both
    /// appearances, `de` and `bg` arc captions at the default size, and the
    /// linear arc and wrapping button at AX3. At the default size the arc,
    /// the line and the next-act panel with its button sit above the fold.
    @MainActor
    func testCaptureToday() throws {
        continueAfterFailure = false
        let runs: [(name: String, appearance: String, language: String, locale: String, ax3: Bool)] = [
            ("dark en", "dark", "en", "en_US", false),
            ("light en", "light", "en", "en_US", false),
            ("dark de", "dark", "de", "de_DE", false),
            ("light bg", "light", "bg", "bg_BG", false),
            ("dark de AX3", "dark", "de", "de_DE", true),
            ("light bg AX3", "light", "bg", "bg_BG", true),
        ]
        for run in runs {
            for hour in ["10.5", "20.5"] {
                let app = XCUIApplication()
                app.launchArguments = ["-ui-testing", "-ui-seed-answer", "-ui-today-hour", hour,
                                       "-appearance", run.appearance,
                                       "-AppleLanguages", "(\(run.language))", "-AppleLocale", run.locale]
                if run.ax3 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"] }
                app.launch()
                let button = app.buttons["MarkMoveDone"]
                XCTAssertTrue(app.descendants(matching: .any)["TodayDayArc"].waitForExistence(timeout: 5))
                if run.ax3 {
                    capture(app, "Today \(run.name) \(hour) arc")
                    for _ in 0..<8 where !button.isHittable { app.swipeUp() }
                }
                XCTAssertTrue(button.waitForExistence(timeout: 3))
                if !run.ax3 {
                    let fold = app.tabBars.firstMatch.frame.minY
                    XCTAssertLessThanOrEqual(button.frame.maxY, fold, "Next-act button below the fold, \(run.name) at \(hour)")
                }
                capture(app, "Today \(run.name) \(hour) top")
                if hour == "20.5" {
                    button.tap()
                    XCTAssertTrue(app.buttons["BeginRetro"].waitForExistence(timeout: 3))
                    capture(app, "Today \(run.name) \(hour) retro")
                    app.swipeUp()
                    capture(app, "Today \(run.name) \(hour) acts")
                }
                app.terminate()
            }
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

    /// Short drags until the element sits between the navigation bar and
    /// the tab bar, so a tap cannot land on either bar. At AX3 a full
    /// swipe can carry a row from below the tab bar to under the title.
    @MainActor
    private func scrollClearOfBars(_ element: XCUIElement, in app: XCUIApplication, defaultUp: Bool) {
        let tabTop = app.tabBars.firstMatch.frame.minY
        let navBottom = app.navigationBars.firstMatch.frame.maxY
        for _ in 0..<40 {
            let up: Bool
            if element.exists {
                let frame = element.frame
                if frame.minY >= navBottom && frame.maxY <= tabTop && element.isHittable { return }
                up = frame.maxY > tabTop
            } else {
                up = defaultUp
            }
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.6 : 0.4))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.4 : 0.6))
            from.press(forDuration: 0.05, thenDragTo: to)
        }
        XCTFail("\(element.identifier) never cleared the bars")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
