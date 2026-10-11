//
//  NumeralRun.swift
//  Think
//

import Foundation

extension AttributedString {
    /// Where `number` sits in a localized sentence, so it can take the
    /// numeral role while the rest stays body text. The catalog formats
    /// the number, so the run is looked up in the form the locale uses
    /// (grouping, non-Latin digits) and falls back to the plain digits.
    /// Only a whole number matches: "1" is never found inside "12".
    func rangeOfNumber(_ number: Int, locale: Locale = .current) -> Range<AttributedString.Index>? {
        let forms = [
            number.formatted(.number.locale(locale)),
            number.formatted(.number.grouping(.never).locale(locale)),
            String(number),
        ]
        for form in forms where !form.isEmpty {
            var searchStart = startIndex
            while let found = self[searchStart...].range(of: form) {
                if isWholeNumber(found) { return found }
                searchStart = found.upperBound
            }
        }
        return nil
    }

    private func isWholeNumber(_ range: Range<AttributedString.Index>) -> Bool {
        func isDigit(_ character: Character) -> Bool { character.isNumber }
        if range.lowerBound > startIndex, let before = self[..<range.lowerBound].characters.last, isDigit(before) {
            return false
        }
        if range.upperBound < endIndex, let after = self[range.upperBound...].characters.first, isDigit(after) {
            return false
        }
        return true
    }
}
