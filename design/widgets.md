# Widgets and Live Activity: token and symbol alignment

Resolves [Widgets and Live Activity: align to tokens and icon vocabulary](https://github.com/Vankata03/Think/issues/81), part of the [Think UI redesign map](https://github.com/Vankata03/Think/issues/68). Decided with the owner on 2026-09-16.

This document lists the concrete substitutions that bring the iOS widget extension onto the [design system](design-system.md). It changes colours, type, spacing and symbols only. Layouts, families, timelines, intents and copy stay as they are; the widget bug the substitutions expose is recorded in section 8 for the build ticket.

Scope: `ThinkWidgets/DailyQuoteWidget.swift` (Daily line: small, medium, lock-screen inline and rectangular), `ThinkWidgets/StreakWidget.swift` (Streak: small, lock-screen circular and rectangular), `ThinkWidgets/StartFocusControl.swift` (Control Center) and `ThinkWidgets/PomodoroLiveActivity.swift` (lock screen and Dynamic Island). The Watch widgets in `ThinkWatchWidgets/` are out of scope with the Watch app and keep their values.

## 1. Rules for the widget surface

1. **System container, Think content.** The home-screen widgets drop the hand-rolled near-black container (`Color(red: 0.07, green: 0.07, blue: 0.08)`). The container is `ThinkColor.surface`, the same surface as the hero card in the app, so a widget is the hero card off-app: white in light, dark grey in dark. Design-system rule 2.2 ("near-black appears nowhere as a surface") applies to widgets as it does to screens; the black-surfaces prototype ([#84](https://github.com/Vankata03/Think/issues/84)) kept system surfaces in the app too, and a later revisit of the app's surfaces would not reopen the widget container.
2. **Both appearances.** Nothing in a widget forces a colour scheme. `label`, `secondaryLabel`, `accent` and `accentInk` resolve per appearance, so the light widget is a light widget. Dark remains the reference scheme for mockups.
3. **Yellow is a fill or a done state.** The accent rule, the progress bar, the gauge, the Live Activity progress and the one primary button are `accent` fills. Text is `label` or `secondaryLabel`; the only yellow text is the attribution on the Daily line widget, in `accentInk`.
4. **One primary per widget.** The Start focus button on the small Streak widget is that widget's primary and keeps `.borderedProminent` (widgets do not host `.glassProminent`), tinted `accent` with `accentOnFill` ink.
5. **Text styles, never point sizes.** Already true in the extension. Numerals and the countdown take the rounded design per the `numeral` and `countdown` roles.
6. **Rendering modes.** In `.accented` mode (tinted home screens) the system flattens colour; every element that should keep its accent tint carries `.widgetAccentable()`. In `.vibrant` mode (lock-screen accessories) colour is ignored and no substitution applies.

## 2. Colour

| File, element | Today | Token |
| --- | --- | --- |
| `DailyQuoteWidget`, container (`systemSmall`, `systemMedium`) | `ink` `#121214` | `ThinkColor.surface` via `.containerBackground(for: .widget) { ThinkColor.surface }` |
| `DailyQuoteWidget`, accent rule (28×3) | `brandYellow` `#FFD433` | `ThinkColor.accent` (fill) plus `.widgetAccentable()` |
| `DailyQuoteWidget`, line text | `.white` | `ThinkColor.label` |
| `DailyQuoteWidget`, attribution | `brandYellow` | `ThinkColor.accentInk` |
| `StreakWidget`, container (`systemSmall`) | `ink` | `ThinkColor.surface` |
| `StreakWidget`, small and rectangular streak `Label` | whole label `brandYellow` | Text `ThinkColor.label`; flame symbol `ThinkColor.accent` when `streak > 0`, `ThinkColor.secondaryLabel` when the text reads "Begin today" (section 7 streak rule; the Begin-again state of section 8) |
| `StreakWidget`, "Daily practice" row and `todayText` | `.white` | `ThinkColor.label` for the row title, `ThinkColor.secondaryLabel` for `todayText` |
| `StreakWidget`, `ProgressView` | `.tint(brandYellow)` | `.tint(ThinkColor.accent)` plus `.widgetAccentable()` |
| `StreakWidget`, circular `Gauge` | `.tint(brandYellow)` | `.tint(ThinkColor.accent)` (keeps `.widgetAccentable()`) |
| `StreakWidget`, Start focus button | `.tint(brandYellow)`, `.foregroundStyle(ink)` | `.tint(ThinkColor.accent)`, `.foregroundStyle(ThinkColor.accentOnFill)`, `.widgetAccentable()` |
| `PomodoroLiveActivity`, `LiveActivityStyle.work` | `#FFE45C` (a third yellow) | `ThinkColor.accent` |
| `PomodoroLiveActivity`, `LiveActivityStyle.rest` | `.green` | `ThinkColor.success` (section 2.1 of the design system names the Focus break phase as a use of this token; there is no separate break token) |
| `PomodoroLiveActivity`, progress bar end dots | phase colour | same token as the bar (`accent` or `success`) |
| `PomodoroLiveActivity`, background | system (no `activityBackgroundTint`) | unchanged: system material, no tint |
| `StartFocusControl` | system | unchanged; Control Center owns its colours |

Removed from the extension by this document: the two private `ink` and `brandYellow` constants (duplicated in both widget views) and the private `LiveActivityStyle` enum. `LiveActivityStyle.accent(for:)` becomes a one-line switch on `ThinkColor`.

## 3. Typography

| File, element | Today | Role |
| --- | --- | --- |
| `DailyQuoteWidget`, line (`systemSmall`) | `.footnote`, serif, `minimumScaleFactor(0.7)` | unchanged. Widget exception to rule 3.2: the frame cannot grow, so the line may shrink to 0.7 before it truncates. Not a role from the app table; `line` (`.title2`) does not fit a small widget. |
| `DailyQuoteWidget`, line (`systemMedium`) | `.callout`, serif, `minimumScaleFactor(0.7)` | unchanged, same exception |
| `DailyQuoteWidget`, line (`accessoryRectangular`) | `.headline`, `minimumScaleFactor(0.8)` | unchanged; system design (the lock screen renders vibrant, serif reads poorly there) |
| `DailyQuoteWidget`, attribution | `.caption2` | unchanged (`caption` is `.footnote` in the app; a small widget keeps `.caption2`) |
| `StreakWidget`, streak label | `.headline` | unchanged |
| `StreakWidget`, gauge count | `.headline.monospacedDigit()` | add `.fontDesign(.rounded)`: the `numeral` role at widget scale |
| `StreakWidget`, "Daily practice" row | `.caption.weight(.semibold)` | unchanged; `todayText` keeps `.monospacedDigit()` |
| `PomodoroLiveActivity`, lock-screen countdown | `.title.weight(.medium)`, monospaced digits | add `.fontDesign(.rounded)`: the `countdown` role (rounded, medium) at the Live Activity's own size |
| `PomodoroLiveActivity`, island expanded countdown | `.title2.weight(.medium)` | add `.fontDesign(.rounded)` |
| `PomodoroLiveActivity`, compact countdown | default | unchanged |
| `PomodoroLiveActivity`, intention | `.subheadline`, `secondary`, one line | unchanged; matches the `secondary` role |

Serif stays on the Daily line in the system families only. Numerals are the only rounded text, per section 3 of the design system.

## 4. Spacing

Literals in the extension mapped to the 4-point scale. Geometry that is not spacing (the 28×3 accent rule, the 8-point progress dots, the 12-point bar height, the 48-point compact timer width) stays.

| File, literal | Today | Token |
| --- | --- | --- |
| `DailyQuoteWidget`, `VStack` spacing | 8 | `ThinkSpacing.s` |
| `StreakWidget`, small outer `VStack` | 9 | `ThinkSpacing.s` |
| `StreakWidget`, small inner `VStack` | 5 | `ThinkSpacing.xs` |
| `StreakWidget`, small `Spacer(minLength:)` | 4 | `ThinkSpacing.xs` |
| `StreakWidget`, rectangular `VStack` | 3 | `ThinkSpacing.xs` |
| `PomodoroLiveActivity`, lock-screen `VStack` | 12 | `ThinkSpacing.m` |
| `PomodoroLiveActivity`, lock-screen `.padding()` | system | unchanged |
| `PomodoroLiveActivity`, island leading and trailing padding | 8 | `ThinkSpacing.s` |
| `PomodoroLiveActivity`, island bottom `VStack` | 6 | `ThinkSpacing.s` |
| `PomodoroLiveActivity`, island bottom horizontal padding | 22 | `ThinkSpacing.xl` |
| `PomodoroLiveActivity`, island bottom top and bottom padding | 8, 6 | `ThinkSpacing.s`, `ThinkSpacing.s` |
| `PomodoroLiveActivity`, progress bar horizontal padding | 4 | `ThinkSpacing.xs` |

Widgets do not wrap these in `@ScaledMetric`; the system caps widget text scaling and the frames are fixed, so scaled spacing would only steal room from the text.

## 5. Symbols

| File, element | Today | `ThinkSymbol` |
| --- | --- | --- |
| `StreakWidget`, streak label (small, rectangular) | `flame.fill` | `streak` (`flame`, outline; content variant per section 7) |
| `StreakWidget`, circular gauge label | `figure.mind.and.body` | `practice` (`sparkle`): the gauge measures meaningful practice |
| `StreakWidget`, circular gauge complete | `checkmark` | unchanged: the gauge ring is the circle, so the bare checkmark is the done state here |
| `StreakWidget`, rectangular today row | `checkmark.circle.fill` / `circle.dotted` | `done` (`checkmark.circle.fill`) / `pathStepPending` (`circle`) |
| `StreakWidget`, Start focus button | `timer` | `focus` (`timer`) |
| `PomodoroLiveActivity`, work phase | `brain.head.profile` | `focus` (`timer`) |
| `PomodoroLiveActivity`, rest phase | `cup.and.saucer` | `breakPhase` (`cup.and.saucer`), unchanged |
| `PomodoroLiveActivity`, minimal island | `timer` | `focus` (`timer`), unchanged |
| `StartFocusControl` | `timer` | `focus` (`timer`), unchanged |

The `ThinkSymbol` member names above are the ones enumerated in the section 7 table of the design system. The Daily line widget carries no symbol and gains none; the serif line is its identifier. `PomodoroLiveActivityPresentation.symbol(for:)` keeps its signature and returns the `ThinkSymbol` names, so `ThinkWidgetsTests.workPhaseUsesDeepWorkPresentation` changes its expected string from `brain.head.profile` to `timer`.

## 6. Accessibility

- Every icon-only control already has a title: the Start focus button and the control use `Label`; the gauge has `accessibilityLabel` and `accessibilityValue`; the Live Activity progress has both. No change.
- Dynamic Type: widget text scales with the system's widget cap. The Daily line keeps its scale factor (section 3); the streak label keeps `lineLimit(1)`.
- `bg` and `de`: "Start focus" ("Започни фокус", "Fokus starten") fits the small widget button at the capped size. "Daily practice" beside "Begin today's practice" ("Ежедневна практика" beside "Започни днешната практика") does not; see section 8.
- Reduce Motion: no animation in the extension beyond the system timer text. No change.
- Rendering modes: `.widgetAccentable()` on the accent rule, flame, progress bar, gauge and Start focus button so the accented home screen keeps the practice evidence tinted and lets text go monochrome.

## 7. Placeholder and empty treatment

Section 8 of the design system delegates widget states here.

| Widget | State | Treatment |
| --- | --- | --- |
| Daily line, placeholder | system redaction of a real quote (`ContentLibrary.dailyQuote()`) | unchanged |
| Streak, placeholder | `StreakPresentation.placeholder` (5-day streak, today complete) | unchanged |
| Streak, never practised or lapsed (`streak == 0`) | Begin-again | flame in `secondaryLabel`, text `label`; copy is `StreakPresentation.streakText` ("Begin today"). The widget owns no copy: when the Today brief settles the two-state streak wording ("Start today" / "Begin again"), it lands in `ThinkShared/Models/StreakPresentation.swift` and the widget inherits it. |
| Streak, today not complete | in progress | gauge count in `label`, progress at 0, `todayText` in `secondaryLabel` |
| Streak, today complete | done | checkmark in the gauge, `done` symbol tinted `success` on the rectangular row |
| Live Activity, stale work phase | rest presentation via `presentationState(isStale:)` | unchanged |
| Live Activity, no intention | row omitted | unchanged |

No widget has an Empty, No-match, Locked or Unavailable state: the Daily line always has a quote and the streak always has a number.

## 8. Bug absorbed

`WID-1` (not in the UI bug inventory, which skipped widgets): in the small Streak widget the `HStack` that puts "Daily practice" beside `todayText` overflows in `bg` and `de` and at larger text sizes; the value clips against the title. Fix in the build ticket: stack the two lines vertically (title `label`, value `secondaryLabel`), which is rule 3.2 applied to a fixed frame. This is the one layout edit this document allows, because it is a clipping bug, not a redesign.

## 9. Build notes

- **Where the colour sets live.** `ThinkWidgetsExtension` has no asset catalog and does not compile `Think/Assets.xcassets`, so a colour set there is unreachable from a widget. `ThinkShared/` is a synchronized folder in the four product targets (`Think`, `ThinkWidgetsExtension`, `ThinkWatchApp`, `ThinkWatchWidgetsExtension`); the test targets do not compile it and reach its symbols through `@testable import` of their host module. The token colour sets therefore go in `ThinkShared/Design/ThinkColors.xcassets` (`ThinkAccent`, `ThinkAccentInk`) and `ThinkColor` reads them from `Bundle.main`. `Think/Assets.xcassets/AccentColor` stays as the app's global tint with the same values. Section 10 of the design system records this.
- **Files touched by the build:** `ThinkWidgets/DailyQuoteWidget.swift`, `ThinkWidgets/StreakWidget.swift`, `ThinkWidgets/PomodoroLiveActivity.swift`, `ThinkWidgetsTests/ThinkWidgetsTests.swift` (symbol expectation). `StartFocusControl.swift` changes only its symbol constant.
- **Tests to keep green:** `ThinkWidgetsTests` builds every family and configuration; the two presentation tests assert titles and symbols. No colour or spacing assertion exists, so none is added; the previews in each widget file are the visual check, in both appearances.
- **Order:** this lands with or after `ThinkShared/Design/ThinkTheme.swift`, since every substitution names a `ThinkColor`, `ThinkSpacing` or `ThinkSymbol` member.

## 10. Open

- The Watch widgets (`ThinkWatchWidgets/`) still carry the old yellow and `flame.fill`. Out of scope with the Watch app; token drift is a map question.
