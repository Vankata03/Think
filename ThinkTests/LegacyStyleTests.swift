//
//  LegacyStyleTests.swift
//  ThinkTests
//
//  The contract step of the redesign (#122): the old styling is gone and
//  stays gone. `LegacyStyleScanner` reads source text; the first group of
//  tests proves each banned pattern is caught, the second runs it over the
//  real `Think/` and `ThinkShared/` trees, so CI fails when one comes back.
//

import Foundation
import Testing

struct LegacyStyleScannerTests {

    private func rules(in source: String, path: String = "Think/Views/SomeView.swift") -> [LegacyStyleRule] {
        LegacyStyleScanner.violations(in: source, path: path).map(\.rule)
    }

    @Test(arguments: [
        (".foregroundStyle(Color.accessibleAccent(for: colorScheme))", LegacyStyleRule.accessibleAccent),
        ("static func accessibleAccent(for scheme: ColorScheme) -> Color {", .accessibleAccent),
        (".foregroundStyle(.prominentButtonForeground(for: scheme))", .prominentButtonForeground),
        ("Color(red: 1.0, green: 0.83, blue: 0.20)", .literalAccent),
        ("Color(red: 1, green: 0.83, blue: 0.20)", .literalAccent),
        ("Color(red: 0.43, green: 0.36, blue: 0.02)", .literalAccent),
        ("Color(\"AccentColor\")", .legacyAccentColor),
        (".foregroundStyle(Color.accentColor)", .legacyAccentColor),
        (".foregroundColor(.accentColor)", .legacyAccentColor),
        (".toolbarBackground(.hidden, for: .navigationBar)", .hiddenToolbarBackground),
        (".toolbarBackgroundVisibility(.hidden, for: .navigationBar)", .hiddenToolbarBackground),
        (".font(.system(size: 42, weight: .semibold))", .fixedSystemFontSize),
        (".minimumScaleFactor(0.6)", .minimumScaleFactor),
        (".padding(.bottom, 120)", .tabBarBottomInset),
        (".padding(.bottom, 80)", .tabBarBottomInset),
        (".contentMargins(.bottom, 90, for: .scrollContent)", .tabBarBottomInset),
        (".safeAreaPadding(.bottom, 100)", .tabBarBottomInset),
        (".foregroundStyle(.red)", .rawSemanticColor),
        (".foregroundStyle(.secondary)", .rawSemanticColor),
        (".foregroundStyle( .tertiary )", .rawSemanticColor),
        ("Label(\"Discard\", systemImage: \"trash\")", .literalSymbol),
        ("Image(systemName: \"lock.doc\")", .literalSymbol),
        ("Label(title, systemImage: \"square.and.arrow.up\")", .literalSymbol),
    ])
    func eachBannedPatternIsCaught(source: String, rule: LegacyStyleRule) {
        #expect(rules(in: source) == [rule])
    }

    @Test func reportsPathAndOneBasedLine() {
        let source = """
            Text("fine")
            Text("bad").minimumScaleFactor(0.5)
            """
        let found = LegacyStyleScanner.violations(in: source, path: "Think/Views/A.swift")
        #expect(found.count == 1)
        #expect(found.first?.path == "Think/Views/A.swift")
        #expect(found.first?.line == 2)
    }

    @Test func tokensAndSmallInsetsAreNotFlagged() {
        let source = """
            Text("x").font(.think(.body)).foregroundStyle(ThinkColor.accentInk)
            Text("x").padding(.bottom, ThinkSpacing.s)
            Text("x").padding(.bottom, 4)
            Text("x").padding(.bottom, 16)
            Text("x").foregroundStyle(ThinkColor.secondaryLabel)
            Label("x", systemImage: ThinkSymbol.delete)
            Text("x").font(.system(.largeTitle, design: .rounded, weight: .bold))
            """
        #expect(rules(in: source).isEmpty)
    }

    @Test func commentsAreIgnored() {
        let source = """
            // .toolbarBackground(.hidden, for: .navigationBar) is banned
            /// Replaces accessibleAccent(for:) and the minimumScaleFactor on the line.
            """
        #expect(rules(in: source).isEmpty)
    }

    @Test func shareCardsMayDrawAtFixedSizes() {
        let source = """
            .font(.system(size: 400, weight: .medium, design: .serif))
            .minimumScaleFactor(0.6)
            .padding(.bottom, 120)
            """
        for card in ["QuoteCardView", "StreakCardView", "AchievementCardView"] {
            #expect(rules(in: source, path: "Think/Views/\(card).swift").isEmpty)
        }
        #expect(rules(in: source, path: "Think/Views/SettingsView.swift").count == 3)
    }

    @Test func onlyTheCountdownRoleMayUseAFixedSystemSize() {
        let source = ".system(size: size, weight: .medium, design: .rounded)"
        #expect(rules(in: source, path: "ThinkShared/Design/ThinkTheme.swift").isEmpty)
        #expect(rules(in: source, path: "ThinkShared/Design/DayArcView.swift") == [.fixedSystemFontSize])
    }

    @Test func aMarkedLineIsExempt() {
        let source = """
            let accent = Color(red: 1, green: 0.83, blue: 0.2)  // style-exempt: fixed preview
            // style-exempt: fixed preview
            let other = Color(red: 1, green: 0.83, blue: 0.2)
            let third = Color(red: 1, green: 0.83, blue: 0.2)
            """
        let found = LegacyStyleScanner.violations(in: source, path: "Think/Views/OnboardingView.swift")
        #expect(found.map(\.line) == [4])
    }
}

struct LegacyStyleContractTests {

    /// The repository root, found from this file so the check reads the
    /// sources the test run was built from.
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    private static func swiftFiles(under directory: String) -> [URL] {
        let base = root.appending(path: directory)
        let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil)
        return (walker?.allObjects as? [URL] ?? []).filter { $0.pathExtension == "swift" }
    }

    @Test func theScannerReadsTheRealTrees() {
        #expect(Self.swiftFiles(under: "Think").count > 50)
        #expect(Self.swiftFiles(under: "ThinkShared").count > 20)
    }

    @Test func noBannedPatternRemainsInTheAppOrSharedTargets() throws {
        var found: [String] = []
        for directory in ["Think", "ThinkShared"] {
            for file in Self.swiftFiles(under: directory) {
                let relative = String(file.path.dropFirst(Self.root.path.count + 1))
                let source = try String(contentsOf: file, encoding: .utf8)
                for violation in LegacyStyleScanner.violations(in: source, path: relative) {
                    found.append("\(violation.path):\(violation.line) \(violation.rule)")
                }
            }
        }
        #expect(found.isEmpty, "Banned legacy styling is back:\n\(found.joined(separator: "\n"))")
    }

    /// design-system section 16.1: the views that must not exist, by file
    /// and by type. The files that were replaced whole (`TodayView`,
    /// `JournalView`, `PathsView`, `PathDetailView`, `OnboardingView`,
    /// `WeeklyReviewView`) keep their names, so their old companions are
    /// the check.
    @Test func noViewFromTheBuildLedgerRemains() throws {
        let deletedFiles = [
            "PracticeDetailView", "FavoritesView", "FocusView", "FocusSessionDetailView",
            "RetroSheet", "MoodPicker", "ProfileView", "FocusStatsView",
            "StreakAchievementsSheet", "PracticeDiscoveryView",
        ]
        let deletedTypes =
            [
                "FocusCountdownView", "DurationPairSummary", "FocusDurationSheet", "FocusTipSheet",
                "JournalEntryDetailView", "JournalRetroDetailView", "JournalEntryRow",
                "JournalRetroRow", "RetroFieldText", "JournalMoodBadge", "JournalDayVariantsView",
            ] + deletedFiles

        var found: [String] = []
        for directory in ["Think", "ThinkShared"] {
            for file in Self.swiftFiles(under: directory) {
                if deletedFiles.contains(file.deletingPathExtension().lastPathComponent) {
                    found.append("file \(file.lastPathComponent)")
                }
                let source = try String(contentsOf: file, encoding: .utf8)
                for name in deletedTypes {
                    if source.range(of: #"\b(struct|class|enum)\s+\#(name)\b"#, options: .regularExpression) != nil {
                        found.append("type \(name) in \(file.lastPathComponent)")
                    }
                }
                if source.contains("Prototype") && source.range(of: #"\b\w+PrototypeView\b"#, options: .regularExpression) != nil {
                    found.append("prototype view in \(file.lastPathComponent)")
                }
            }
        }
        #expect(found.isEmpty, "Ledger views are back:\n\(found.joined(separator: "\n"))")
    }
}
