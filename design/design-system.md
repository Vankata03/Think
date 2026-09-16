# Think design system

Resolves [Design system: tokens, type roles, spacing scale and icon vocabulary](https://github.com/Vankata03/Think/issues/72), part of the [Think UI redesign map](https://github.com/Vankata03/Think/issues/68). Decided with the owner on 2026-09-16.

This document is the contract every screen brief in `design/` cites. It names tokens and the SwiftUI expression each one maps to, so the build tickets compile against shared names instead of restating values. HIG facts come from the research notes on branch `research/ios26-hig` (`research/ios26-hig.md`).

Scope: the iOS app. Widgets and the Live Activity inherit the tokens (their own ticket covers the alignment). The Watch app, share cards and wallpapers (`QuoteCardView`) are out of scope and keep their current values.

## 1. Principles

1. **Native chrome, Think content.** Tab bar, navigation bars, toolbars, lists and sections are the iOS 26 system components with their Liquid Glass. The identity lives in the content layer: serif lines, black and yellow, whitespace. No custom bar backgrounds, no glass on content cards.
2. **Dark is the reference.** Dark is the shipped default appearance and the scheme mockups are drawn in first. Light is first-class: every token carries both values and every brief passes the acceptance floor in both. Onboarding offers Auto and Light so the choice is visible once.
3. **Yellow means "do this now" or "evidence of practice".** One primary action per screen, the streak, progress rings, achievements. Everything else uses system label colours; bars stay monochrome.
4. **Text styles, never point sizes.** Every text role is a Dynamic Type text style. Numeric layout values that sit next to text go through `@ScaledMetric`. The timer countdown is the single fixed-origin size, and it scales too.
5. **Lists by default.** Screens are `List` or `Form` with `.insetGrouped`; that gives the tab-bar inset, section radius, scroll-edge effect and accessibility layout for free. A custom card appears only for hero content (the daily line on Today, the Focus timer) and uses the one card modifier so it matches the sections beside it.

## 2. Colour

### 2.1 Tokens

| Token | Dark | Light | Use |
| --- | --- | --- | --- |
| `accent` | `#FFD433` | `#F2C41C` | Fills only: the primary action, progress rings, streak flame, achievement medals, selected state. Ink on top is always `accentOnFill`. |
| `accentInk` | `#FFD433` (same as `accent`) | `#6E5C05` | Text, links and tinted symbols. Never used as a fill. Light value contrasts about 6.6:1 on white. |
| `accentOnFill` | `#000000` | `#000000` | Label and symbol colour on an `accent` fill (7:1 or better on both accents). |
| `label`, `secondaryLabel`, `tertiaryLabel` | system | system | All interface text. Yellow text only through `accentInk`. |
| `background` | `systemGroupedBackground` | `systemGroupedBackground` | Screen background. Black in dark. |
| `surface` | `secondarySystemGroupedBackground` | `secondarySystemGroupedBackground` | List sections and the hero card. |
| `surfaceRaised` | `tertiarySystemGroupedBackground` | `tertiarySystemGroupedBackground` | Elements nested inside a section or card (chips, inner tiles). |
| `separator` | system | system | Row separators only; never drawn by hand. |
| `success` | `.green` | `.green` | Done states (move completed, step confirmed). |
| `destructive` | `.red` | `.red` | Delete and reset actions; via `Button(role: .destructive)`, not a colour literal. |

The `accent` values are provisional. They are locked after the Today prototype runs on a device in both schemes; the brief that changes them updates this table.

Removed by this document: the hand-rolled `accessibleAccent(for:)` and `prominentButtonForeground(for:)` in `Think/Views/ViewStyle.swift`, the literal `Color(red: 1.0, green: 0.83, blue: 0.20)` and `Color(red: 0.43, green: 0.36, blue: 0.02)` scattered through the views, and the orange streak flame. `Assets.xcassets/AccentColor` becomes `accent` (light `#F2C41C`, dark `#FFD433`); a new `AccentInk` colour set carries `accentInk`.

### 2.2 Rules

- Bars (tab bar, navigation bar, toolbars) are monochrome. The only colour in a bar is the one `.glassProminent` primary action, tinted `accent`.
- No yellow on section header symbols, list row symbols or links, other than `accentInk` on tappable text. The black-surfaces prototype ticket may test yellow on section header symbols; until it decides, this rule stands.
- Near-black appears nowhere as a surface. Black is the ink on yellow, the app icon and the wordmark. Whether a black hero card or black primary buttons earn a place is the question of the black-surfaces prototype ticket; this document does not pre-empt it.
- Custom surfaces (cream papers, tinted cards) are out. The `CardStyle` palette stays inside the share-card renderer, which is out of scope.
- Colour never carries meaning alone: a done state has a checkmark, a locked state has a lock, a streak has a number.

## 3. Typography

System fonts only. The serif is the system serif (New York) through `.fontDesign(.serif)`; it covers all seven locales, including Cyrillic for `bg`, and scales with Dynamic Type without extra work. Rounded is reserved for numerals.

### 3.1 Roles

| Role | Text style | Design | Weight | Where |
| --- | --- | --- | --- | --- |
| `lineLarge` | `.largeTitle` | serif | regular | The daily line on Today's hero card. |
| `line` | `.title2` | serif | regular | The daily line everywhere else: practice detail, Saved lines rows, share sheet preview. |
| `lesson` | `.body` | serif | regular | Path step lesson text, `lineSpacing(4)` scaled. |
| `title` | `.largeTitle` | system | bold | Screen titles, supplied by the navigation bar. Never set by hand in content. |
| `heading` | `.headline` | system | semibold | Section headers inside custom cards; `List` section headers use the system style (title-case text). |
| `body` | `.body` | system | regular | Interface text, journal entries, settings rows. |
| `secondary` | `.subheadline` | system | regular | Supporting text under a row or card title, coloured `secondaryLabel`. |
| `caption` | `.footnote` | system | regular | Timestamps, counts, helper text, coloured `secondaryLabel`. |
| `numeral` | `.title` | rounded | semibold | Streak count, statistics, path day number. Always `.monospacedDigit()`. |
| `countdown` | `@ScaledMetric(relativeTo: .largeTitle) 64` | rounded | medium | The Focus timer only. Scales with Dynamic Type but is clamped so it never pushes the controls off screen; the Focus brief sets the clamp. |

### 3.2 Rules

- No `.font(.system(size:))` outside `countdown`. The existing 32, 40, 42, 44, 48, 56, 72, 88 and 160 point sizes in the views map to the roles above; the brief for each screen names the mapping.
- Emphasis inside a role is weight, never a second size: `.bold()` on the same text style.
- Lines break naturally. No `minimumScaleFactor` on a daily line; a long line gets height, not a smaller font.
- At accessibility sizes (`dynamicTypeSize.isAccessibilitySize`) horizontal pairs stack vertically. This applies to every row that puts a label next to a value or a control.

## 4. Spacing

A 4-point scale. Named steps, no other literals in layout code.

| Token | Points | Use |
| --- | --- | --- |
| `xs` | 4 | Between a symbol and its text, between stacked caption lines. |
| `s` | 8 | Between related elements inside a row (title and secondary text). |
| `m` | 12 | Between groups inside a card; vertical padding of a compact row. |
| `l` | 16 | Card interior padding; gap between a section header and its first row when custom. |
| `xl` | 24 | Between cards in a `ScrollView`; between major blocks inside a hero card. |
| `xxl` | 32 | Top of a hero block, empty-state breathing room. |
| `xxxl` | 48 | Above and below an empty state illustration or a centred timer. |

Rules:

- Screen edges use the system list margins. No custom horizontal inset anywhere; this retires the 17, 21, 28, 33, 36, 38 and 61 point insets found in the bug inventory.
- Content never sets a bottom inset for the tab bar. `List`, `Form` and `ScrollView` inside a `NavigationStack` inherit it; a custom overlay that needs the space uses `.safeAreaBar` or `.safeAreaInset`, never a padding literal.
- Every step that sits next to text is read through `@ScaledMetric` so the spacing grows with the type.
- `List` row and section spacing stay at the iOS 26 defaults; `.listSectionSpacing` is set only where a brief says why.

## 5. Shape, cards and sections

| Token | Value | Use |
| --- | --- | --- |
| `section` | system | `List` and `Form` sections keep the iOS 26 radius. Not set by hand. |
| `card` | 26, continuous | The hero card modifier. Provisional: measured against a real iOS 26 section in the Today prototype and adjusted so both read as one radius. |
| `nested` | concentric | Anything inside a card or section that has its own corners uses `ConcentricRectangle` (or `.rect(corners: .concentric)`) with `card` as the fallback so inner radii derive from the container. |
| `control` | system | Buttons, chips and text fields keep their system shapes. No custom capsules. |

The card modifier, `thinkCard()`, is: `surface` fill, `card` radius, `l` interior padding, no shadow, no border, no material. Cards live in the content layer, so they never use `glassEffect`. Reduce Transparency and Increase Contrast need no special handling because there is nothing translucent to reduce.

A section that used to be a custom card becomes a `Section` with a title-case header. Its rows are ordinary rows; its actions are row buttons or a trailing toolbar item, not a full-width yellow block.

## 6. Buttons and actions

| Role | Style | Rule |
| --- | --- | --- |
| `primary` | `.buttonStyle(.glassProminent)` tinted `accent`, label `accentOnFill` | At most one per screen. Lives in the trailing toolbar, or at the bottom of the hero card when the action is the screen's reason to exist (Today's move, Focus start). The Focus start button is the one primary allowed inside content. |
| `secondary` | `.buttonStyle(.bordered)` | Everything that is an action but not the primary one. |
| `tertiary` | `.buttonStyle(.plain)`, text in `accentInk` | Inline links and "See all" rows. |
| `destructive` | `.buttonStyle(.bordered)` with `role: .destructive` | Delete entry, reset streak, delete all data. Confirmed through a `confirmationDialog`. |

Removed: the custom circular chrome buttons, full-width filled yellow blocks in scroll content, and the three ad-hoc capsule treatments the bug inventory counted. Toolbar items follow the HIG: symbols without enclosing circles, grouped with `ToolbarItemGroup` and `ToolbarSpacer(.fixed)`, at most three groups, text and symbol items never mixed inside one group. Every icon-only control is created with a title (`Button("Share", systemImage: ...)` or `Label` with `.labelStyle(.iconOnly)`) so the accessibility label comes from the title.

## 7. Symbols

One SF Symbol per concept. Outline variant in toolbars, lists and content; the tab bar and selected states take the fill variant, which the system applies. Monochrome rendering everywhere; a symbol is tinted `accent` only when it is the primary action or a done state, and `accentInk` only inside tappable text.

| Concept | Symbol | Notes |
| --- | --- | --- |
| Daily line | `text.quote` | Also the Saved lines list section. |
| Question of the day | `questionmark.bubble` | Replaces `doc.questionmark`. |
| Move | `figure.walk` | Replaces the bare `checkmark`; the checkmark remains the done state. |
| Path | `point.topleft.down.to.point.bottomright.curvepath` | Paths tab and path rows. |
| Path step | `circle` / `checkmark.circle.fill` | Pending / confirmed. |
| Focus session | `timer` | Focus tab, presets, history rows. |
| Break | `cup.and.saucer` | Break state in the timer and Live Activity. |
| Streak | `flame` | `accent` tint when the streak is alive; `secondaryLabel` when it reads "Begin again". |
| Meaningful practice | `sparkle` | Activity log rows, weekly review counts. |
| Journal | `book.closed` | Journal tab, entry rows. |
| Mood | `face.smiling` | Mood picker and entry detail. |
| Saved line | `bookmark` | Replaces `heart`. Save action on Today's card, toolbar item that opens Saved lines. `bookmark.fill` when saved. |
| Achievement | `medal` | Progress section; custom medal art stays for the medals themselves. |
| Retro | `moon.stars` | Evening retro card and entry rows. |
| Weekly review | `calendar.badge.checkmark` | Progress card and reflection rows. |
| Settings | `gearshape` | Gear toolbar item on Progress. |
| iCloud | `icloud` | Settings row and sync status. |
| Lock | `lock` / `lock.open` | Journal gate and Privacy settings. |
| Share | `square.and.arrow.up` | Toolbar and card action. |
| Edit | `pencil` | Entry detail toolbar. |
| Add | `plus` | New note. |
| Delete | `trash` | Row swipe and destructive rows. |
| Done state | `checkmark.circle.fill` | Tinted `success`. |

Tab bar:

| Tab | Symbol |
| --- | --- |
| Today | `sun.max` |
| Paths | `point.topleft.down.to.point.bottomright.curvepath` |
| Focus | `timer` |
| Journal | `book.closed` |
| Progress | `chart.bar` |

Symbols scale with the text style they sit beside. Symbols that must stay small (tab bar items) get `.accessibilityShowsLargeContentViewer()`.

## 8. Motion

Unchanged by this document. `ThinkMotion` in `Think/Views/ViewStyle.swift` keeps its curves and its Reduce Motion fallbacks. Whether the redesign defines a motion and haptics language is an open map question.

## 9. Swift naming

The build introduces one file, `ThinkShared/Design/ThinkTheme.swift`, that holds every token above. Briefs and tickets refer to these names.

| Token group | Swift | Example |
| --- | --- | --- |
| Colour | `ThinkColor` static properties backed by colour sets or system colours | `ThinkColor.accent`, `ThinkColor.accentInk`, `ThinkColor.surface` |
| Type role | `Font.think(_ role: ThinkTextRole)` returning the text style plus design and weight | `.font(.think(.line))`, `.font(.think(.numeral)).monospacedDigit()` |
| Spacing | `ThinkSpacing` static `CGFloat` steps, plus `@ScaledMetric` wrappers where they sit next to text | `.padding(ThinkSpacing.l)` |
| Radius | `ThinkRadius.card` | `RoundedRectangle(cornerRadius: ThinkRadius.card, style: .continuous)` |
| Card | `View.thinkCard()` modifier | `VStack { ... }.thinkCard()` |
| Symbol | `ThinkSymbol` static strings, one per concept | `Image(systemName: ThinkSymbol.savedLine)` |
| Button role | `View.thinkButton(_ role: ThinkButtonRole)` mapping to the styles in section 6 | `.thinkButton(.primary)` |

Widgets and the Watch app compile `ThinkShared` into their own targets, so the tokens are reachable there; the widget alignment ticket decides which ones they adopt.

## 10. Acceptance floor for every brief

Restated here so no brief omits it:

- Dynamic Type through AX3 without clipping, overlap or truncation of the daily line, questions or lessons.
- `bg` and `de` string lengths checked on every labelled control and section header.
- Every icon-only control has an accessibility label, supplied by its title.
- Both appearances, with dark as the reference.
- Reduce Motion honoured through `ThinkMotion`.
- The screen's bugs from the UI bug inventory are listed and absorbed.

## 11. Open

- `accent` values and `card` radius: lock after the Today prototype on device.
- Black surfaces and yellow on section header symbols: black-surfaces prototype ticket.
- Motion and haptics language: map fog.
