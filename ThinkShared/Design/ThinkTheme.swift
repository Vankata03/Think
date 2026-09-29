//
//  ThinkTheme.swift
//  ThinkShared
//
//  Every token design/design-system.md names (section 10), in one file so
//  the app, the widgets and the Watch compile against the same names.
//

import SwiftUI

// MARK: - Colour (design-system section 2.1)

enum ThinkColor {
    /// Fills only: the primary action, rings, the streak flame, practised
    /// days, medals, selected state. Ink on top is always `accentOnFill`.
    static let accent = Color("ThinkAccent")
    /// Text, links, tinted symbols and "now" captions. Never a fill.
    static let accentInk = Color("ThinkAccentInk")
    /// Label and symbol colour on an `accent` fill.
    static let accentOnFill = Color.black

    static let success = Color.green
    static let destructive = Color.red

    #if os(watchOS)
    // The Watch adopts none of these yet (design-system section 10); they
    // exist so shared views compile there.
    static let label = Color.primary
    static let secondaryLabel = Color.secondary
    static let tertiaryLabel = Color.primary.opacity(0.3)
    static let background = Color.black
    static let surface = Color(white: 0.11)
    static let surfaceRaised = Color(white: 0.17)
    static let fill = Color.gray.opacity(0.18)
    static let track = Color.gray.opacity(0.24)
    static let separator = Color.gray.opacity(0.4)
    #else
    static let label = Color(uiColor: .label)
    static let secondaryLabel = Color(uiColor: .secondaryLabel)
    static let tertiaryLabel = Color(uiColor: .tertiaryLabel)
    /// Screen background. Black in dark.
    static let background = Color(uiColor: .systemGroupedBackground)
    /// List sections and hero rows.
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    /// Elements nested inside a section: chips, inner tiles.
    static let surfaceRaised = Color(uiColor: .tertiarySystemGroupedBackground)
    /// A small shape behind a symbol inside a row.
    static let fill = Color(uiColor: .quaternarySystemFill)
    /// The track under the Paths step trail.
    static let track = Color(uiColor: .tertiarySystemFill)
    /// Row separators, and the track of the day arc and session arc.
    static let separator = Color(uiColor: .separator)
    #endif
}

// MARK: - Type (design-system section 3.1)

enum ThinkTextRole: CaseIterable {
    /// The daily line on Today.
    case lineLarge
    /// The daily line everywhere else.
    case line
    /// The question of the day.
    case question
    /// Path step lesson text; pair with a scaled `lineSpacing(4)`.
    case lesson
    /// Screen titles. The navigation bar supplies them; set by hand only
    /// for the full path name on path detail.
    case title
    /// A path step's title.
    case stepTitle
    /// Headings inside a section row.
    case heading
    case body
    /// Supporting text under a row or card title, in `secondaryLabel`.
    case secondary
    /// Timestamps, counts and helper text, in `secondaryLabel`.
    case caption
    /// Text drawn into a graphic: arc captions, end times, weekday initials.
    case graphicCaption
    /// Streak count, statistics, step counts. Monospaced digits.
    case numeral
    /// The Focus timer only; see `View.thinkCountdownFont()`.
    case countdown

    /// The base size of `countdown`, scaled relative to `.largeTitle`.
    static let countdownSize: CGFloat = 64
}

extension Font {
    static func think(_ role: ThinkTextRole) -> Font {
        switch role {
        case .lineLarge: .system(.title, design: .serif)
        case .line: .system(.title2, design: .serif)
        case .question: .system(.title3, design: .serif)
        case .lesson: .system(.body, design: .serif)
        case .title: .system(.largeTitle, weight: .bold)
        case .stepTitle: .system(.title2, weight: .semibold)
        case .heading: .system(.headline, weight: .semibold)
        case .body: .system(.body)
        case .secondary: .system(.subheadline)
        case .caption: .system(.footnote)
        case .graphicCaption: .system(.caption2, weight: .semibold)
        case .numeral: .system(.title, design: .rounded, weight: .semibold).monospacedDigit()
        // Unscaled here because a static font cannot read Dynamic Type;
        // the Focus timer applies it through `thinkCountdownFont()`.
        case .countdown: .thinkCountdown(size: ThinkTextRole.countdownSize)
        }
    }

    /// The single fixed-origin size in the system (design-system 3.2).
    fileprivate static func thinkCountdown(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded).monospacedDigit()
    }
}

private struct ThinkCountdownFont: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size = ThinkTextRole.countdownSize

    func body(content: Content) -> some View {
        content
            .font(.thinkCountdown(size: size))
            // Beyond this Focus switches to its linear form.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

extension View {
    /// The `countdown` role, scaled with Dynamic Type from 64pt.
    func thinkCountdownFont() -> some View {
        modifier(ThinkCountdownFont())
    }
}

// MARK: - Spacing (design-system section 4)

enum ThinkSpacing {
    /// Between a symbol and its text, between stacked caption lines.
    static let xs: CGFloat = 4
    /// Between related elements inside a row.
    static let s: CGFloat = 8
    /// Between groups inside a card; vertical padding of a compact row.
    static let m: CGFloat = 12
    /// Interior padding of a clear hero row.
    static let l: CGFloat = 16
    /// Between blocks of a `ScrollView` stage or inside a hero row.
    static let xl: CGFloat = 24
    /// Top of a hero block, empty-state breathing room.
    static let xxl: CGFloat = 32
    /// Above and below an empty state or a centred timer.
    static let xxxl: CGFloat = 48

    /// A spacing step that grows with Dynamic Type, for spacing that sits
    /// next to text: `@ThinkSpacing.Scaled(ThinkSpacing.s) private var gap`.
    @propertyWrapper
    struct Scaled: DynamicProperty {
        @ScaledMetric private var value: CGFloat

        init(_ step: CGFloat, relativeTo textStyle: Font.TextStyle = .body) {
            _value = ScaledMetric(wrappedValue: step, relativeTo: textStyle)
        }

        var wrappedValue: CGFloat { value }
    }
}

// MARK: - Symbols (design-system section 7)

/// One SF Symbol per concept. A new concept adds a row to the section 7
/// table before it adds a member here.
enum ThinkSymbol {
    static let dailyLine = "text.quote"
    static let question = "questionmark.bubble"
    static let move = "figure.walk"
    static let path = "point.topleft.down.to.point.bottomright.curvepath"
    static let pathStepPending = "circle"
    static let pathStepToday = "circle.inset.filled"
    static let pathStepDone = "checkmark.circle.fill"
    static let focus = "timer"
    static let breakPhase = "cup.and.saucer"
    static let health = "heart"
    static let streak = "flame"
    static let practice = "sparkle"
    static let journal = "book.closed"
    static let note = "note.text"
    static let filter = "line.3.horizontal.decrease"
    static let filterActive = "line.3.horizontal.decrease.circle.fill"
    static let drafts = "doc.badge.clock"
    static let mood = "face.smiling"
    static let savedLine = "bookmark"
    static let achievement = "medal"
    static let retro = "moon.stars"
    static let today = "sun.max"
    static let progress = "chart.bar"
    static let unavailable = "exclamationmark.triangle"
    static let weeklyReview = "calendar.badge.checkmark"
    static let settings = "gearshape"
    static let icloud = "icloud"
    static let lock = "lock"
    static let lockOpen = "lock.open"
    static let share = "square.and.arrow.up"
    static let edit = "pencil"
    static let add = "plus"
    static let delete = "trash"
    static let done = "checkmark.circle.fill"
}

// MARK: - Buttons (design-system section 6)

enum ThinkButtonRole {
    /// At most one per screen, in one of the four homes of section 13.6.
    case primary
    case secondary
    /// Inline links and "See all" rows.
    case tertiary
    /// Pair with `Button(role: .destructive)` and a confirmation dialog.
    case destructive
}

extension View {
    @ViewBuilder
    func thinkButton(_ role: ThinkButtonRole) -> some View {
        switch role {
        case .primary:
            buttonStyle(.glassProminent)
                .tint(ThinkColor.accent)
                .foregroundStyle(ThinkColor.accentOnFill)
        case .secondary, .destructive:
            buttonStyle(.bordered)
        case .tertiary:
            buttonStyle(.plain)
                .foregroundStyle(ThinkColor.accentInk)
        }
    }
}
