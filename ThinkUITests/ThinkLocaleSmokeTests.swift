//
//  ThinkLocaleSmokeTests.swift
//  ThinkUITests
//

import XCTest

final class ThinkLocaleSmokeTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testBulgarianCoreLoop() throws {
        assertCoreLoop(language: "bg", locale: "bg_BG")
    }

    @MainActor
    func testGermanCoreLoop() throws {
        assertCoreLoop(language: "de", locale: "de_DE")
    }

    @MainActor
    func testSpanishCoreLoop() throws {
        assertCoreLoop(language: "es", locale: "es_ES")
    }

    @MainActor
    func testFrenchCoreLoop() throws {
        assertCoreLoop(language: "fr", locale: "fr_FR")
    }

    @MainActor
    func testItalianCoreLoop() throws {
        assertCoreLoop(language: "it", locale: "it_IT")
    }

    @MainActor
    func testBrazilianPortugueseCoreLoop() throws {
        assertCoreLoop(language: "pt-BR", locale: "pt_BR")
    }

    @MainActor
    private func assertCoreLoop(language: String, locale: String) {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-AppleLanguages",
            "(\(language))",
            "-AppleLocale",
            locale,
        ]
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["QuestionOfTheDayCard"].waitForExistence(timeout: 5),
            "Question card did not load for \(language)"
        )
        XCTAssertTrue(
            app.buttons["ShareQuote"].waitForExistence(timeout: 2),
            "Share action did not load for \(language)"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["TrainingLog"].waitForExistence(timeout: 2),
            "Training log did not load for \(language)"
        )

        app.terminate()
    }
}
