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

    /// The weekly review across the acceptance floor (`progress-settings.md`
    /// section 9.5): both appearances, AX3 in `en`, `bg` and `de`, with
    /// "Write reflection", "Your reflection" and the longest count label
    /// ("Partial effort, not completed") on screen, then the Saved row.
    @MainActor
    func testCaptureWeeklyReview() throws {
        continueAfterFailure = false
        let runs: [(name: String, appearance: String, language: String, locale: String, ax3: Bool)] = [
            ("dark en", "dark", "en", "en_US", false),
            ("light en", "light", "en", "en_US", false),
            ("dark en AX3", "dark", "en", "en_US", true),
            ("light bg AX3", "light", "bg", "bg_BG", true),
            ("dark de AX3", "dark", "de", "de_DE", true),
        ]
        for run in runs {
            for saved in [false, true] {
                let app = XCUIApplication()
                app.launchArguments = ["-ui-testing", "-ui-seed-progress", "-appearance", run.appearance,
                                       "-AppleLanguages", "(\(run.language))", "-AppleLocale", run.locale]
                if saved { app.launchArguments += ["-ui-seed-weekly-review"] }
                if run.ax3 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"] }
                app.launch()
                app.tabBars.buttons.element(boundBy: 4).tap()
                let open = app.buttons["OpenWeeklyReview"]
                reveal(open, in: app)
                open.tap()
                let view = app.descendants(matching: .any).matching(identifier: "WeeklyReviewView").firstMatch
                XCTAssertTrue(view.waitForExistence(timeout: 3))
                let thisWeek = app.descendants(matching: .any).matching(identifier: "WeeklyReviewThisWeek").firstMatch
                XCTAssertTrue(thisWeek.waitForExistence(timeout: 3))
                capture(app, "Weekly review \(run.name) \(saved ? "saved" : "unwritten") top")
                thisWeek.buttons.firstMatch.tap()

                let row = app.buttons[saved ? "WeeklyReviewSaved" : "WriteReflection"]
                var swipes = 0
                while !(row.exists && row.isHittable && row.frame.maxY <= app.tabBars.firstMatch.frame.minY) && swipes < 12 {
                    app.swipeUp()
                    swipes += 1
                    if swipes % 3 == 0 { capture(app, "Weekly review \(run.name) \(saved ? "saved" : "unwritten") scroll \(swipes / 3)") }
                }
                XCTAssertTrue(row.isHittable)
                XCTAssertLessThanOrEqual(row.frame.maxY, app.tabBars.firstMatch.frame.minY, "The reflection row sits above the tab bar")
                XCTAssertFalse(app.buttons["SaveWeeklyReview"].exists)
                capture(app, "Weekly review \(run.name) \(saved ? "saved" : "unwritten") reflection")
                app.terminate()
            }
        }
    }

    /// The Focus stage across the acceptance floor (`design/focus.md`
    /// section 11): both appearances, AX3, and `de` and `bg` on the arc
    /// captions at the default size and on End, Skip and Skip to work at AX3.
    /// Asserts the controls stay in the bar above the tab bar and the wheel
    /// columns stack at AX3; captures idle, running, paused, the break and
    /// the accessory on Today.
    @MainActor
    func testCaptureFocusStage() throws {
        continueAfterFailure = false
        let runs: [(name: String, appearance: String, language: String, locale: String, ax3: Bool)] = [
            ("dark en", "dark", "en", "en_US", false),
            ("light en", "light", "en", "en_US", false),
            ("dark de", "dark", "de", "de_DE", false),
            ("light bg", "light", "bg", "bg_BG", false),
            ("dark en AX3", "dark", "en", "en_US", true),
            ("dark de AX3", "dark", "de", "de_DE", true),
            ("light bg AX3", "light", "bg", "bg_BG", true),
        ]
        for run in runs {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-appearance", run.appearance,
                                   "-AppleLanguages", "(\(run.language))", "-AppleLocale", run.locale]
            if run.ax3 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"] }
            app.launch()
            app.tabBars.buttons.element(boundBy: 2).tap()
            XCTAssertTrue(app.descendants(matching: .any)["FocusTimer"].waitForExistence(timeout: 3))
            let tabBarTop = app.tabBars.firstMatch.frame.minY
            let width = app.windows.firstMatch.frame.width
            let primary = app.buttons["FocusPrimary"]
            XCTAssertTrue(primary.isHittable)
            XCTAssertLessThanOrEqual(primary.frame.maxY, tabBarTop)
            capture(app, "Focus \(run.name) idle")
            if run.ax3 {
                let work = app.pickerWheels.element(boundBy: 0)
                let rest = app.pickerWheels.element(boundBy: 1)
                for _ in 0..<6 where !(rest.exists && rest.isHittable) { app.swipeUp() }
                XCTAssertGreaterThanOrEqual(rest.frame.minY, work.frame.maxY, "Wheel columns stack at AX3")
                capture(app, "Focus \(run.name) idle wheel")
            }

            primary.tap()
            for id in ["FocusEnd", "FocusPrimary", "FocusSkip"] {
                let button = app.buttons[id]
                XCTAssertTrue(button.isHittable, id)
                XCTAssertLessThanOrEqual(button.frame.maxY, tabBarTop, id)
                XCTAssertLessThanOrEqual(button.frame.maxX, width, id)
            }
            capture(app, "Focus \(run.name) running")
            primary.tap()
            capture(app, "Focus \(run.name) paused")
            primary.tap()
            app.buttons["FocusSkip"].tap()
            XCTAssertTrue(app.buttons["FocusSkip"].isHittable)
            XCTAssertLessThanOrEqual(app.buttons["FocusSkip"].frame.maxX, width)
            capture(app, "Focus \(run.name) break")

            app.tabBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.buttons["FocusAccessory"].waitForExistence(timeout: 3))
            capture(app, "Focus \(run.name) accessory")
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
            XCTAssertTrue(app.descendants(matching: .any)["JournalDetail"].waitForExistence(timeout: 3))
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

    /// The Paths list across the acceptance floor (`paths.md` section 11):
    /// both appearances, AX3, and `de` and `bg` on the hero caption and the
    /// locked row, plus the hero's done form. Asserts the hero and the
    /// locked row stay inside the screen.
    @MainActor
    func testCapturePathsList() throws {
        continueAfterFailure = false
        let runs: [(name: String, appearance: String, language: String, locale: String, ax3: Bool, seedDone: Bool)] = [
            ("dark en", "dark", "en", "en_US", false, false),
            ("light en", "light", "en", "en_US", false, false),
            ("dark en done", "dark", "en", "en_GB", false, true),
            ("dark de AX3", "dark", "de", "de_DE", true, false),
            ("light bg AX3", "light", "bg", "bg_BG", true, false),
        ]
        for run in runs {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-appearance", run.appearance,
                                   "-AppleLanguages", "(\(run.language))", "-AppleLocale", run.locale]
            if run.ax3 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"] }
            if run.seedDone { app.launchArguments += ["-ui-seed-path-step"] }
            app.launch()
            app.tabBars.buttons.element(boundBy: 1).tap()
            let hero = app.buttons["PathsHero"]
            XCTAssertTrue(hero.waitForExistence(timeout: 5))
            let width = app.windows.firstMatch.frame.width
            XCTAssertLessThanOrEqual(hero.frame.maxX, width)
            if run.language == "en" {
                XCTAssertTrue(hero.label.hasPrefix(run.seedDone ? "Step 1 done" : "Today on Deep focus, step 1 of 21"))
                XCTAssertEqual(hero.value as? String, run.seedDone ? "1 of 21 steps done" : "0 of 21 steps done")
            }
            capture(app, "Paths \(run.name) top")

            let locked = app.buttons["Path.clear-thinking"]
            reveal(locked, in: app)
            XCTAssertLessThanOrEqual(locked.frame.maxX, width)
            capture(app, "Paths \(run.name) all paths")
            locked.tap()
            XCTAssertTrue(app.descendants(matching: .any)["PathDetail.clear-thinking"].waitForExistence(timeout: 3))
            app.terminate()
        }
    }

    /// Path detail across the acceptance floor (`paths.md` section 11):
    /// both appearances, the done and finished states, and `de` and `bg` at
    /// AX3 on "Complete step" and "Opens tomorrow at 06:00", where the
    /// trail turns into one row per step.
    @MainActor
    func testCapturePathDetail() throws {
        continueAfterFailure = false
        let runs: [(name: String, appearance: String, language: String, locale: String, ax3: Bool, seed: String?)] = [
            ("dark en", "dark", "en", "en_GB", false, nil),
            ("light en", "light", "en", "en_US", false, nil),
            ("dark en done", "dark", "en", "en_GB", false, "-ui-seed-path-step"),
            ("light en finished", "light", "en", "en_GB", false, "-ui-seed-path-finished"),
            ("dark de AX3", "dark", "de", "de_DE", true, nil),
            ("light bg AX3", "light", "bg", "bg_BG", true, nil),
            ("dark de AX3 done", "dark", "de", "de_DE", true, "-ui-seed-path-step"),
            ("light bg AX3 done", "light", "bg", "bg_BG", true, "-ui-seed-path-step"),
        ]
        for run in runs {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-appearance", run.appearance,
                                   "-AppleLanguages", "(\(run.language))", "-AppleLocale", run.locale]
            if run.ax3 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"] }
            if let seed = run.seed { app.launchArguments.append(seed) }
            app.launch()
            app.tabBars.buttons.element(boundBy: 1).tap()
            let finished = run.seed == "-ui-seed-path-finished"
            let entry = finished ? app.buttons["Path.deep-focus"] : app.buttons["PathsHero"]
            XCTAssertTrue(entry.waitForExistence(timeout: 5))
            entry.tap()
            XCTAssertTrue(app.descendants(matching: .any)["PathDetail.deep-focus"].waitForExistence(timeout: 5))
            let width = app.windows.firstMatch.frame.width
            capture(app, "Path detail \(run.name) top")

            let action: XCUIElement =
                switch run.seed {
                case "-ui-seed-path-step": app.buttons["PathNextRow"]
                case "-ui-seed-path-finished": app.buttons["BeginAgain"]
                default: app.buttons["CompleteStep"]
                }
            XCTAssertTrue(action.waitForExistence(timeout: 3))
            reveal(action, in: app)
            XCTAssertLessThanOrEqual(action.frame.maxX, width)
            XCTAssertGreaterThanOrEqual(action.frame.minX, 0)
            capture(app, "Path detail \(run.name) action")

            let firstStep = run.ax3 ? app.buttons["PathStepRow.1"] : app.buttons["StepDisc.1"]
            reveal(firstStep, in: app)
            XCTAssertFalse(app.buttons[run.ax3 ? "StepDisc.1" : "PathStepRow.1"].exists)
            if !run.ax3 {
                // Every disc keeps a 44pt target (paths.md section 12).
                XCTAssertGreaterThanOrEqual(firstStep.frame.width, 44)
                XCTAssertGreaterThanOrEqual(firstStep.frame.height, 44)
            }
            capture(app, "Path detail \(run.name) steps")
            app.terminate()
        }
    }

    /// The read detail across the acceptance floor (`journal.md` sections
    /// 5 and 13): both appearances, AX3 in `de` and `bg`, with "Another
    /// version from this day", the delete dialog and the versions list.
    /// In `en` every kind is opened for its prompt rule.
    @MainActor
    func testCaptureJournalDetail() throws {
        continueAfterFailure = false
        let runs: [(name: String, appearance: String, language: String, locale: String, ax3: Bool)] = [
            ("dark en", "dark", "en", "en_GB", false),
            ("light en", "light", "en", "en_GB", false),
            ("dark de AX3", "dark", "de", "de_DE", true),
            ("light bg AX3", "light", "bg", "bg_BG", true),
        ]
        for run in runs {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-appearance", run.appearance,
                                   "-AppleLanguages", "(\(run.language))", "-AppleLocale", run.locale,
                                   "-ui-seed-journal-list", "-ui-seed-journal-versions"]
            if run.ax3 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"] }
            app.launch()
            app.tabBars.buttons.element(boundBy: 3).tap()
            let primary = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "VERSION C")).firstMatch
            XCTAssertTrue(primary.waitForExistence(timeout: 3))
            // At AX3 a row's centre can sit under the tab bar; tap its top.
            primary.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
            XCTAssertTrue(app.descendants(matching: .any)["JournalDetail"].waitForExistence(timeout: 3))
            // The writing is its own element, so VoiceOver reaches it.
            XCTAssertTrue(app.staticTexts["JournalDetailText.0"].exists)
            capture(app, "Detail \(run.name)")

            let width = app.windows.firstMatch.frame.width
            let another = app.buttons["AnotherVersion"]
            reveal(another, in: app)
            XCTAssertLessThanOrEqual(another.frame.maxX, width)
            let delete = app.buttons["DeleteEntry"]
            reveal(delete, in: app)
            capture(app, "Detail \(run.name) scrolled")
            delete.tap()
            XCTAssertTrue(app.buttons["ConfirmDeleteEntry"].firstMatch.waitForExistence(timeout: 3))
            capture(app, "Detail \(run.name) delete dialog")
            // Outside the dialog dismisses it without deleting. The dialog
            // points at the Delete row; at AX3 it fills everything under
            // the bar, so the bar is the clear spot.
            let dialogFrame = app.buttons["ConfirmDeleteEntry"].firstMatch.frame
            let height = app.windows.firstMatch.frame.height
            let clear = dialogFrame.midY > height / 2 ? 0.07 : 0.8
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: clear)).tap()
            XCTAssertTrue(app.buttons["ConfirmDeleteEntry"].firstMatch.waitForNonExistence(timeout: 3))

            another.tap()
            XCTAssertTrue(app.descendants(matching: .any)["JournalVersions"].waitForExistence(timeout: 3))
            capture(app, "Detail \(run.name) versions")

            if run.language == "en" {
                for (kind, text) in [("note", "Lunch with Maya"), ("retro", "Shipped the draft"),
                                     ("focus note", "Got the opening scene"), ("weekly review", "Week of")] {
                    app.tabBars.buttons.element(boundBy: 3).tap()
                    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
                    for _ in 0..<4 where !row.isHittable { app.swipeUp() }
                    row.tap()
                    XCTAssertTrue(app.descendants(matching: .any)["JournalDetail"].waitForExistence(timeout: 3))
                    capture(app, "Detail \(run.name) \(kind)")
                }
            }
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
