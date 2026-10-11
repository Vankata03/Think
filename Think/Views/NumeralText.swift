//
//  NumeralText.swift
//  Think
//

import SwiftUI

/// A localized sentence with one number in the numeral role and the rest
/// in a body role, so every locale keeps its own grammar and number form.
enum NumeralText {
    /// The numeral run: rounded semibold with monospaced digits
    /// (`design/progress-settings.md` section 8.2).
    static var numeralFont: Font { .think(.numeral).monospacedDigit() }

    static func emphasising(
        _ number: Int, in sentence: AttributedString, body: Font, bodyColor: Color,
        numeralColor: Color? = nil, locale: Locale = .current
    ) -> AttributedString {
        var text = sentence
        text.font = body
        text.foregroundColor = bodyColor
        if let range = text.rangeOfNumber(number, locale: locale) {
            text[range].font = numeralFont
            if let numeralColor { text[range].foregroundColor = numeralColor }
        }
        return text
    }

    /// "12 days": the streak count, pluralised by the string catalog.
    static func streakDays(
        _ count: Int, body: Font, bodyColor: Color, numeralColor: Color? = nil
    ) -> AttributedString {
        emphasising(
            count, in: AttributedString(localized: "streak.days \(count)"),
            body: body, bodyColor: bodyColor, numeralColor: numeralColor)
    }
}
