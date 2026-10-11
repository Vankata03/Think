//
//  LegacyStyleScanner.swift
//  ThinkTests
//
//  Finds the legacy styling the redesign removed (design-system sections
//  2.1, 3.2 and 13.2) in Swift source text. `LegacyStyleTests` runs it over
//  `Think/` and `ThinkShared/`.
//
//  Where a pattern is allowed:
//  - the share-card renderers draw to a fixed canvas, so they keep fixed
//    font sizes, scale factors and insets;
//  - `ThinkTheme.swift` defines the one fixed size, the `countdown` role;
//  - the Watch app and the widgets are not scanned;
//  - a line carrying `style-exempt: <reason>`, or the line under a comment
//    that does, is skipped. Use it for a fixed value that must not follow
//    the appearance, and say why.
//

import Foundation

enum LegacyStyleRule: CaseIterable {
    /// `Color.accessibleAccent(for:)`, replaced by `ThinkColor.accentInk`.
    case accessibleAccent
    /// `Color.prominentButtonForeground(for:)`, replaced by `accentOnFill`
    /// through `thinkButton(.primary)`.
    case prominentButtonForeground
    /// The two gold literals the old helpers were built from.
    case literalAccent
    /// The `AccentColor` asset read by hand; tokens are `ThinkColor.accent`
    /// and `ThinkColor.accentInk`. The asset stays the global tint.
    case legacyAccentColor
    /// `.toolbarBackground(.hidden, ...)` removes the scroll-edge effect.
    case hiddenToolbarBackground
    /// `.font(.system(size:))` outside the `countdown` role.
    case fixedSystemFontSize
    /// A daily line gets height, not a smaller font.
    case minimumScaleFactor
    /// A literal bottom inset standing in for the tab bar.
    case tabBarBottomInset

    fileprivate var pattern: String {
        switch self {
        case .accessibleAccent:
            #"accessibleAccent"#
        case .prominentButtonForeground:
            #"prominentButtonForeground"#
        case .literalAccent:
            #"red:\s*1(\.0*)?\s*,\s*green:\s*0\.83\d*\s*,\s*blue:\s*0\.2\d*|red:\s*0\.43\d*\s*,\s*green:\s*0\.36\d*\s*,\s*blue:\s*0\.02"#
        case .legacyAccentColor:
            #"\.accentColor\b|"AccentColor""#
        case .hiddenToolbarBackground:
            #"toolbarBackground(Visibility)?\(\s*\.hidden"#
        case .fixedSystemFontSize:
            #"\.system\(\s*size:"#
        case .minimumScaleFactor:
            #"minimumScaleFactor"#
        case .tabBarBottomInset:
            #"\.(padding|contentMargins|safeAreaPadding)\(\s*\.bottom\s*,\s*([4-9]\d|\d{3,})\b"#
        }
    }

    fileprivate func isAllowed(in path: String) -> Bool {
        let file = (path as NSString).lastPathComponent
        let shareCards = ["QuoteCardView.swift", "StreakCardView.swift", "AchievementCardView.swift"]
        switch self {
        case .fixedSystemFontSize:
            return shareCards.contains(file) || file == "ThinkTheme.swift"
        case .minimumScaleFactor, .tabBarBottomInset:
            return shareCards.contains(file)
        default:
            return false
        }
    }
}

struct LegacyStyleViolation: Equatable {
    let path: String
    let line: Int
    let rule: LegacyStyleRule
}

enum LegacyStyleScanner {
    static let exemptionMarker = "style-exempt:"

    static func violations(in source: String, path: String) -> [LegacyStyleViolation] {
        let lines = source.components(separatedBy: "\n")
        var found: [LegacyStyleViolation] = []

        for (index, text) in lines.enumerated() {
            if text.trimmingCharacters(in: .whitespaces).hasPrefix("//") { continue }
            if text.contains(exemptionMarker) { continue }
            if index > 0, isExemptionComment(lines[index - 1]) { continue }

            for rule in LegacyStyleRule.allCases where !rule.isAllowed(in: path) {
                if text.range(of: rule.pattern, options: .regularExpression) != nil {
                    found.append(LegacyStyleViolation(path: path, line: index + 1, rule: rule))
                }
            }
        }
        return found
    }

    private static func isExemptionComment(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("//") && trimmed.contains(exemptionMarker)
    }
}
