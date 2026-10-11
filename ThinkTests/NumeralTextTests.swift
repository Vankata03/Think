import Foundation
import SwiftUI
import Testing

@testable import Think

/// The streak count in the numeral role inside a localized sentence
/// (`design/progress-settings.md` section 8.2). The catalog formats the
/// number, so the run is found in whatever form the locale produced.
@MainActor struct NumeralTextTests {
    private let english = Locale(identifier: "en_US")
    private let german = Locale(identifier: "de_DE")
    private let arabic = Locale(identifier: "ar_EG")

    private func run(_ number: Int, in sentence: String, locale: Locale) -> String? {
        let text = AttributedString(sentence)
        return text.rangeOfNumber(number, locale: locale).map { String(text[$0].characters) }
    }

    @Test func plainDigitsAreFound() {
        #expect(run(12, in: "12 days", locale: english) == "12")
    }

    @Test func groupedNumbersAreFoundWhole() {
        #expect(run(1234, in: "1,234 days", locale: english) == "1,234")
        #expect(run(1234, in: "1.234 Tage", locale: german) == "1.234")
    }

    @Test func nonLatinDigitsAreFound() {
        let formatted = 1234.formatted(.number.locale(arabic))
        #expect(run(1234, in: "\(formatted) يوم", locale: arabic) == formatted)
    }

    /// "1" in "1 of 12 days" is the first token, never the front of "12".
    @Test func aNumberIsNeverFoundInsideALongerOne() {
        #expect(run(1, in: "12 of 1 days", locale: english) == "1")
        #expect(run(2, in: "12 days", locale: english) == nil)
    }

    @Test func aMissingNumberIsLeftAlone() {
        #expect(run(7, in: "A week", locale: english) == nil)
    }

    @Test func onlyTheNumberTakesTheNumeralRole() {
        let text = NumeralText.emphasising(
            1234, in: AttributedString("1,234 days"), body: .body, bodyColor: .primary, locale: english)

        let numeralRuns = text.runs.filter { $0.font == NumeralText.numeralFont }
        #expect(numeralRuns.map { String(text[$0.range].characters) } == ["1,234"])
        #expect(text.runs.filter { $0.font == .body }.map { String(text[$0.range].characters) } == [" days"])
    }

    /// The catalog's own plural forms, through the same path the views use.
    @Test(arguments: [1, 12, 1234])
    func streakDaysMarksTheCountTheCatalogWrote(count: Int) {
        let text = NumeralText.streakDays(count, body: .body, bodyColor: .primary)

        let numeral = text.runs.filter { $0.font == NumeralText.numeralFont }
        #expect(numeral.count == 1)
        let marked = numeral.first.map { String(text[$0.range].characters) }
        #expect(marked == count.formatted() || marked == String(count))
    }
}
