# Think design system

Resolves [Design system: tokens, type roles, spacing scale and icon vocabulary](https://github.com/Vankata03/Think/issues/72), part of the [Think UI redesign map](https://github.com/Vankata03/Think/issues/68). Decided with the owner on 2026-09-16.

This document is the contract every screen brief in `design/` cites. It names tokens and the SwiftUI expression each one maps to, so the build tickets compile against shared names instead of restating values. HIG facts come from the research notes on branch `research/ios26-hig` (`research/ios26-hig.md`).

Scope: the iOS app. Widgets and the Live Activity inherit the tokens; [widgets.md](widgets.md) lists their substitutions. The Watch app, share cards and wallpapers (`QuoteCardView`) are out of scope and keep their current values.

## 1. Principles

1. **Native chrome, Think content.** Tab bar, navigation bars, toolbars, lists and sections are the iOS 26 system components with their Liquid Glass. The identity lives in the content layer: serif lines, black and yellow, whitespace. No custom bar backgrounds, no glass on content cards.
2. **Dark is the reference.** Dark is the shipped default appearance and the scheme mockups are drawn in first. Light is first-class: every token carries both values and every brief passes the acceptance floor in both. Onboarding shows the choice once, as three picture tiles with Dark selected ([onboarding.md](onboarding.md) section 5.1); Settings keeps the inline picker.
3. **Yellow means "do this now" or "evidence of practice".** One primary action per screen, the streak, progress rings, achievements. Everything else uses system label colours; bars stay monochrome.
4. **Text styles, never point sizes.** Every text role is a Dynamic Type text style. Numeric layout values that sit next to text go through `@ScaledMetric`. The timer countdown is the single fixed-origin size, and it scales too.
5. **Lists by default.** Screens are `List` or `Form` with `.insetGrouped`; that gives the tab-bar inset, section radius, scroll-edge effect and accessibility layout for free. Today uses clear rows for the day arc and daily line, then a `surface` section for the next act ([today.md](today.md) section 2). Focus is the one exception: a stage with no cards and no list ([focus.md](focus.md) section 2).

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
| `success` | `.green` | `.green` | Done states (move completed, step confirmed) and the Focus break phase in the timer and Live Activity: rest reads as the same green because a break is the earned outcome of a work interval. Widgets.md section 2 relies on this; no separate break token exists. |
| `destructive` | `.red` | `.red` | Delete and reset actions; via `Button(role: .destructive)`, not a colour literal. |

The `accent` values were confirmed on device by the Today prototype ([today.md](today.md)) in both schemes: dark `#FFD433`, light `#F2C41C` as a fill with black ink. Light must use the fill, not the ink, on graphics such as the day arc.

Removed by this document: the hand-rolled `accessibleAccent(for:)` and `prominentButtonForeground(for:)` in `Think/Views/ViewStyle.swift`, the literal `Color(red: 1.0, green: 0.83, blue: 0.20)` and `Color(red: 0.43, green: 0.36, blue: 0.02)` scattered through the views, and the orange streak flame. `Think/Assets.xcassets/AccentColor` takes the `accent` values (light `#F2C41C`, dark `#FFD433`) and stays the app's global tint; the token colour sets themselves live in `ThinkShared/Design/ThinkColors.xcassets` (`ThinkAccent`, `ThinkAccentInk`) so the widget extension, which compiles no other catalog, can read them (section 10).

### 2.2 Rules

- Bars (tab bar, navigation bar, toolbars) are monochrome, with two identity marks: the selected tab and the streak toolbar item on Today, both `accentInk`; and the one `.glassProminent` primary action, tinted `accent`. Nothing else in a bar carries colour (section 13).
- No yellow on section header symbols, list row symbols or links, other than `accentInk` on tappable text. Tested and rejected in the black-surfaces prototype (owner, 2026-09-16): bars, headers and row symbols stay monochrome.
- Near-black appears nowhere as a surface, and black is never a button fill. Black is the ink on yellow, the app icon and the wordmark. Decided in the black-surfaces prototype (owner, 2026-09-16): a near-black hero card vanishes on the dark `background` and needs a border to read at all, and a black primary button ghosts on the dark `surface`; system surfaces with the `accent` primary (variant A) won in both schemes.
- Custom surfaces (cream papers, tinted cards) are out; a cream hero surface was drawn in the same prototype and rejected. The `CardStyle` palette stays inside the share-card renderer, which is out of scope.
- The [prototype canvas](https://claude.ai/artifact/42ePzdvmmGPRHvWgCXzAtt) (rounds A to I, linked from [#84](https://github.com/Vankata03/Think/issues/84)) and `research/visual-language.md` (branch `research/visual-language`: Stoic, Waking Up, Apple Journal and Books, HIG dark-mode and colour pages, gold accent candidates with contrast figures) are kept for a later revisit of the accent and surfaces; the owner chose A "for now".
- Colour never carries meaning alone: a done state has a checkmark, a locked state has a lock, a streak has a number.

## 3. Typography

System fonts only. The serif is the system serif (New York) through `.fontDesign(.serif)`; it covers all seven locales, including Cyrillic for `bg`, and scales with Dynamic Type without extra work. Rounded is reserved for numerals.

### 3.1 Roles

| Role | Text style | Design | Weight | Where |
| --- | --- | --- | --- | --- |
| `lineLarge` | `.title` | serif | regular | The daily line on Today. Was `.largeTitle`; on device the larger size plus the day arc pushed the next act below the fold ([today.md](today.md) section 8). |
| `line` | `.title2` | serif | regular | The daily line everywhere else: Saved lines rows, share sheet preview. |
| `question` | `.title3` | serif | regular | The question of the day in Today's next-act panel and its answer detail. |
| `lesson` | `.body` | serif | regular | Path step lesson text, `lineSpacing(4)` scaled. |
| `title` | `.largeTitle` | system | bold | Screen titles, supplied by the navigation bar. Never set by hand in content. |
| `heading` | `.headline` | system | semibold | Section headers inside custom cards; `List` section headers use the system style (title-case text). |
| `body` | `.body` | system | regular | Interface text, journal entries, settings rows. |
| `secondary` | `.subheadline` | system | regular | Supporting text under a row or card title, coloured `secondaryLabel`. |
| `caption` | `.footnote` | system | regular | Timestamps, counts, helper text, coloured `secondaryLabel`. |
| `numeral` | `.title` | rounded | semibold | Streak count, statistics, path step counts. Always `.monospacedDigit()`. |
| `countdown` | `@ScaledMetric(relativeTo: .largeTitle) 64` | rounded | medium | The Focus timer only. Scales with Dynamic Type up to `.xxxLarge`; at accessibility sizes Focus switches to its linear form ([focus.md](focus.md) section 3). |

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
| `card` | 26, continuous | The hero card modifier. Provisional: measure against a real iOS 26 section before use; Today and Focus do not use `thinkCard()`. |
| `nested` | concentric | Anything inside a card or section that has its own corners uses `ConcentricRectangle` (or `.rect(corners: .concentric)`) with `card` as the fallback so inner radii derive from the container. |
| `control` | system | Buttons, chips and text fields keep their system shapes. No custom capsules. |

The card modifier, `thinkCard()`, is: `surface` fill, `card` radius, `l` interior padding, no shadow, no border, no material. Cards live in the content layer, so they never use `glassEffect`. Reduce Transparency and Increase Contrast need no special handling because there is nothing translucent to reduce.

A section that used to be a custom card becomes a `Section` with a title-case header. Its rows are ordinary rows; its actions are row buttons or a trailing toolbar item, not a full-width yellow block.

## 6. Buttons and actions

| Role | Style | Rule |
| --- | --- | --- |
| `primary` | `.buttonStyle(.glassProminent)` tinted `accent`, label `accentOnFill` | At most one per screen. Section 13.6 places it floating bottom-trailing for list creation, inside Today's next-act panel or path detail's step card, centred in Focus's bottom safe-area bar, or in the trailing toolbar otherwise. |
| `secondary` | `.buttonStyle(.bordered)` | Everything that is an action but not the primary one. |
| `tertiary` | `.buttonStyle(.plain)`, text in `accentInk` | Inline links and "See all" rows. |
| `destructive` | `.buttonStyle(.bordered)` with `role: .destructive` | Delete entry, reset streak, delete all data. Confirmed through a `confirmationDialog`. |

Removed: the custom circular chrome buttons, full-width filled yellow blocks in scroll content, and the three ad-hoc capsule treatments the bug inventory counted. Toolbar items follow the HIG: symbols without enclosing circles, grouped with `ToolbarItemGroup` and `ToolbarSpacer(.fixed)`, at most three groups, text and symbol items never mixed inside one group. Every icon-only control is created with a title (`Button("Share", systemImage: ...)` or `Label` with `.labelStyle(.iconOnly)`) so the accessibility label comes from the title.

## 7. Symbols

One SF Symbol per concept. Outline variant in toolbars, lists and content; the tab bar and selected states take the fill variant, which the system applies. Monochrome rendering everywhere; a symbol is tinted `accent` only when it is the primary action or a done state, and `accentInk` only inside tappable text.

| Concept | `ThinkSymbol` | Symbol | Notes |
| --- | --- | --- | --- |
| Daily line | `dailyLine` | `text.quote` | Also the Saved lines list section. |
| Question of the day | `question` | `questionmark.bubble` | Replaces `doc.questionmark`. |
| Move | `move` | `figure.walk` | Replaces the bare `checkmark`; the checkmark remains the done state. |
| Path | `path` | `point.topleft.down.to.point.bottomright.curvepath` | Paths tab and path rows. |
| Path step | `pathStepPending` / `pathStepToday` / `pathStepDone` | `circle` / `circle.inset.filled` / `checkmark.circle.fill` | Pending (widgets) / open today (Paths captions and rows) / confirmed. A step that has not opened yet uses `lock`. The discs of the step trail are drawn, not symbols ([paths.md](paths.md) section 3). |
| Focus session | `focus` | `timer` | Focus tab, the bottom accessory, history rows. |
| Break | `breakPhase` | `cup.and.saucer` | Break state in the timer and Live Activity. |
| Apple Health | `health` | `heart` | "Log focus to Health" in onboarding and Settings. Free for this since saved lines moved to `bookmark`; it means Apple Health and nothing else. |
| Streak | `streak` | `flame` | `accent` tint when the streak is alive; `secondaryLabel` when it reads "Begin again". |
| Meaningful practice | `practice` | `sparkle` | Activity log rows, weekly review counts. |
| Journal | `journal` | `book.closed` | Journal tab and the empty journal state. Entry rows carry their kind symbol instead ([journal.md](journal.md) section 4). |
| Note | `note` | `note.text` | Note rows in the Journal and the Notes kind in its filter. |
| Filter | `filter` / `filterActive` | `line.3.horizontal.decrease` / `line.3.horizontal.decrease.circle.fill` | The Journal's filter menu; the filled form, monochrome, while a filter is on. |
| Unsaved drafts | `drafts` | `doc.badge.clock` | The Journal's drafts row; dropped at accessibility sizes. |
| Mood | `mood` | `face.smiling` | The empty Mood chip in the editor; a chosen mood shows its own symbol. |
| Saved line | `savedLine` | `bookmark` | Replaces `heart`. Save action beside Today's daily line, toolbar item that opens Saved lines. `bookmark.fill` when saved. |
| Achievement | `achievement` | `medal` | Progress section; custom medal art stays for the medals themselves. |
| Retro | `retro` | `moon.stars` | Evening retro panel, arc marker and entry rows. |
| Today | `today` | `sun.max` | The Today tab. The sun on the day arc is a drawn disc, not a symbol. |
| Weekly review | `weeklyReview` | `calendar.badge.checkmark` | Progress card and reflection rows. |
| Settings | `settings` | `gearshape` | Gear toolbar item on Progress. |
| iCloud | `icloud` | `icloud` | Settings row and sync status. |
| Lock | `lock` / `lockOpen` | `lock` / `lock.open` | Journal gate and Privacy settings. |
| Share | `share` | `square.and.arrow.up` | Toolbar and card action. |
| Edit | `edit` | `pencil` | Edit actions in menus. The entry detail's Edit is a text button ([journal.md](journal.md) section 5). |
| Add | `add` | `plus` | New note. |
| Delete | `delete` | `trash` | Row swipe and destructive rows. |
| Done state | `done` | `checkmark.circle.fill` | Tinted `success`. |

Tab bar:

| Tab | Symbol |
| --- | --- |
| Today | `sun.max` |
| Paths | `point.topleft.down.to.point.bottomright.curvepath` |
| Focus | `timer` |
| Journal | `book.closed` |
| Progress | `chart.bar` |

`ThinkSymbol` has exactly the members in the `ThinkSymbol` column; a new concept adds a row here before it adds a member. The tab bar reuses `path`, `focus` and `journal` and adds `today` (`sun.max`) and `progress` (`chart.bar`).

Symbols scale with the text style they sit beside. Symbols that must stay small (tab bar items) get `.accessibilityShowsLargeContentViewer()`.

## 8. States

Resolves [Empty states and Begin-again states across screens](https://github.com/Vankata03/Think/issues/79). Five state classes, defined in `CONTEXT.md`, cover every screen that can have nothing to show. Each brief names the class a screen uses and cites this section rather than restating it.

| Class | When | Presentation | Symbol | Action |
| --- | --- | --- | --- | --- |
| Empty | The user has not created anything yet | Whole screen empty: `ContentUnavailableView` with the concept symbol, one line, one `secondary` button. One section of a populated screen empty: a single `secondaryLabel` row, no symbol. | The concept's own symbol from section 7, `secondaryLabel` | One `secondary` action that does the thing. Section rows carry a `tertiary` link only when the fix lives on another screen; none when the screen's primary already is the fix. |
| No-match | Content exists, search or filters hide it | Search: `ContentUnavailableView.search(text:)`. Filters: one `secondaryLabel` row. | System | Filters: `tertiary` "Clear filters". Search: none. |
| Begin-again | Something ended and can restart | Same layout as Empty | Concept symbol in `secondaryLabel` (`flame` for the streak, path symbol for a completed path) | One `secondary` "Begin again". The lapsed streak has no button: today's practice is the restart. |
| Locked | Content exists behind a gate | Full screen for the journal gate and a locked path's detail; a dimmed row or medal inside a list | `lock` for gates; medals keep their art, dimmed | One `secondary` action that opens the gate ("Unlock", "Open <previous path>"). Locked rows stay tappable and lead to the explaining detail; a dead row reads as a bug. |
| Unavailable | Load or lookup failed | `ContentUnavailableView` with the cause as description. Never replaces content that did load: a storage warning is a row above the list. | `exclamationmark.triangle` | "Try again" where a retry exists, otherwise "Close". |

Rules:

- One sentence per state, present tense, no exclamation mark, under 60 English characters so `bg` and `de` fit two lines at AX3. The line names the thing, never the chrome ("Nothing written yet.", not "Tap + to start."). Button labels are verb phrases.
- Two-state copy (never practised versus lapsed: "Start today" / "Begin again") exists only for the streak. Every other empty state has one line.
- A whole-journal empty state shows the journal line whatever filter is active; the five filter-specific lines in `JournalView` collapse to one.
- Unearned achievements stay visible, dimmed, with the unlock condition as a secondary line and as the accessibility hint. Locked medals are the motivation.
- A week with zero practice days renders the weekly review with zeros and a writable reflection; it has no empty state.
- Never `.glassProminent` inside a state view; the screen's primary stays in the location specified by section 13.6.
- System components carry Dynamic Type, both appearances and Reduce Motion; no custom art, no illustration.

Lines and actions per screen (briefs may tune wording, not shape):

| Screen | Class | Line | Action |
| --- | --- | --- | --- |
| Journal, whole journal | Empty | Nothing written yet. | Write a note |
| Journal, search | No-match | system | none |
| Journal, filters | No-match | No entries match. | Clear filters |
| Journal gate | Locked | Your journal is locked. | Unlock |
| Journal entry or retro | Unavailable | Entry not found. | Close |
| Journal storage | Unavailable | Could not load your journal. | Try again |
| Saved lines | Empty | Lines you keep appear here. | none (pushed from Today; back is the action) |
| Focus history (Progress) | Empty | No focus sessions yet. | Start a session |
| Focus "Last session" line | Empty | Not shown until the first session. | none |
| Today streak, lapsed | Begin-again | Begin again. | none |
| Today streak, never practised | Begin-again | Start today. | none |
| Path detail, completed | Begin-again, as a section above the step trail | Path completed. | Begin again |
| Path detail, locked | Locked | Finish <previous path> first. | Open <previous path> |
| Path step, not open yet | Locked, full screen on the step page | Opens tomorrow at 06:00. / Opens after step <n − 1>. | none |
| Achievements, unearned | Locked | unlock condition | none |

Widgets and the Live Activity take their placeholder and empty treatment from [widgets.md](widgets.md) section 7; onboarding has no state views.

## 9. Motion

Unchanged by this document. `ThinkMotion` in `Think/Views/ViewStyle.swift` keeps its curves and its Reduce Motion fallbacks, and the existing haptic events stay as they are. The redesign defines no shared motion or haptics language: each brief states its own motion and its Reduce Motion behaviour, and those statements are the contract (owner, 2026-09-26).

## 10. Swift naming

The build introduces one file, `ThinkShared/Design/ThinkTheme.swift`, that holds every token above. Briefs and tickets refer to these names.

| Token group | Swift | Example |
| --- | --- | --- |
| Colour | `ThinkColor` static properties backed by colour sets or system colours | `ThinkColor.accent`, `ThinkColor.accentInk`, `ThinkColor.surface` |
| Type role | `Font.think(_ role: ThinkTextRole)` returning the text style plus design and weight | `.font(.think(.line))`, `.font(.think(.numeral)).monospacedDigit()` |
| Spacing | `ThinkSpacing` static `CGFloat` steps, plus `@ScaledMetric` wrappers where they sit next to text | `.padding(ThinkSpacing.l)` |
| Radius | `ThinkRadius.card` | `RoundedRectangle(cornerRadius: ThinkRadius.card, style: .continuous)` |
| Card | `View.thinkCard()` modifier | `VStack { ... }.thinkCard()` |
| Symbol | `ThinkSymbol` static strings, one per concept, the members enumerated in the section 7 table | `Image(systemName: ThinkSymbol.savedLine)`, `ThinkSymbol.focus`, `ThinkSymbol.streak` |
| Button role | `View.thinkButton(_ role: ThinkButtonRole)` mapping to the styles in section 6 | `.thinkButton(.primary)` |

Widgets and the Watch app compile `ThinkShared` into their own targets, so the tokens are reachable there. Colour sets must sit in a catalog inside `ThinkShared/` for that to hold: `ThinkWidgetsExtension` compiles no other asset catalog. The widgets adopt `ThinkColor` (`surface`, `label`, `secondaryLabel`, `accent`, `accentInk`, `accentOnFill`, `success`), `ThinkSpacing`, `ThinkSymbol` and the rounded numeral design; their type styles stay their own because widget frames cannot grow ([widgets.md](widgets.md)). The Watch app adopts nothing yet.

## 11. Acceptance floor for every brief

Restated here so no brief omits it:

- Dynamic Type through AX3 without clipping, overlap or truncation of the daily line, questions or lessons.
- `bg` and `de` string lengths checked on every labelled control and section header.
- Every icon-only control has an accessibility label, supplied by its title.
- Both appearances, with dark as the reference.
- Reduce Motion honoured through `ThinkMotion`.
- The screen's bugs from the UI bug inventory are listed and absorbed.

## 12. Open

- `card` radius: Today and Focus do not use `thinkCard()`, so the radius is still unmeasured; measure it against a system section before a future brief uses it.
- Chrome at AX3 (section 13.7): rules 2 and 3 were shown on device on 2026-09-25. The Settings prototype kept the inline Appearance choices readable at AX3; the Focus prototype switched the arc to a bar. Production bindings and localizations still need build checks.

## 13. Screen chrome

Resolves [Screen chrome baseline: navigation bars, toolbar items and tab-bar insets](https://github.com/Vankata03/Think/issues/82). Decided with the owner on 2026-09-16. Every screen brief inherits this section and cites it instead of re-deciding containers, bars or insets. It absorbs the two app-wide causes behind most of the bug inventory: the missing tab-bar inset (`TOD-1`, `TOD-3`, `PDT-1`, `PDT-6`, `FOC-1`, `FOC-5`, `FST-2`, `PRO-4`, `SET-4`, `SET-6`, `SET-9`, `JRN-5`, `DIS-3`) and the custom circular chrome (`TOD-2`, `PDT-4`, `FOC-6`, `PRA-4`, `PTH-2`).

### 13.1 Container per screen

Every screen is a `NavigationStack` whose root is a `List` or a `Form`, with two exceptions: Focus, which is a `ScrollView` stage with no cards, and the Journal editor sheet, a `ScrollView` writing surface ([journal.md](journal.md) section 8). The old `ScrollView` plus `VStack` card stack, with its per-view horizontal insets, is retired. On list screens, hero content can use a clear row with `.listRowBackground(Color.clear)` and `.listRowInsets(EdgeInsets())`; a brief specifies whether that row has a card. Today has clear rows for the arc and line without `thinkCard()`.

| Screen | Container | Notes |
| --- | --- | --- |
| Today | `List` | Clear rows for the day arc and the daily line, then one `surface` section for the next act and one for the other acts. No `thinkCard()`, no activity log. Full spec in [today.md](today.md). |
| Paths | `List` | Today's step as a hero row with the trail window, then an "All paths" section; unavailable paths as one footer line. Full spec in [paths.md](paths.md). |
| Path detail | `List` | Path name row, today's step card with the screen's primary, then the full step trail as the index of steps. No progress header, no history section. Full spec in [paths.md](paths.md). |
| Focus | `ScrollView` stage | The exception to this section: no `List`, no card. A centred column on the plain background (intention, arc, wheel, last session) with the controls in a bottom safe-area bar ([focus.md](focus.md) section 2). |
| Journal | `List` | Day sections, `.searchable` under the title. Full spec in [journal.md](journal.md). |
| Progress | `List` | Streak hero, weekly review, Practice stats and chart, compact earned achievements, then two recent Focus sessions and See all. Full spec in [progress-settings.md](progress-settings.md). |
| Settings | `Form` | Grouped, `.insetGrouped` by default; the gear on Progress pushes it. Full spec in [progress-settings.md](progress-settings.md). |
| Pushed detail screens | `List` or `Form` | Same rule; the Journal's read detail is a `List` with one clear content row. |
| Onboarding | `NavigationStack` per step | Step 1 a centred `ScrollView`, steps 2 and 3 `Form`s; Skip in the trailing toolbar, page dots and the primary in a bottom safe-area bar. Full spec in [onboarding.md](onboarding.md). |
| Sheets | `NavigationStack` with `List`/`Form` | See 13.5. Editors other than the Journal editor keep their text field inside a `Form`; the Journal editor is a `ScrollView` so the text scrolls above the keyboard (`JRN-4`). |

### 13.2 Insets, scroll edge and the tab bar

- No view sets a bottom inset for the tab bar. `List` and `Form` inside the `NavigationStack` inherit it. The `.padding(.bottom, 120)` on Profile and every other bottom literal go.
- `.toolbarBackground(.hidden, for: .navigationBar)` is banned. It is the cause of the ghosted text behind bars on Today, Focus and Profile: it removes the scroll-edge effect, so content scrolls under bare glass. The scroll-edge effect stays `.automatic` (soft) and is never hidden.
- Anything that must sit above the tab bar uses `.safeAreaBar(edge: .bottom)` (13.6) or `.safeAreaInset`, never an overlay with padding.
- `.tabBarMinimizeBehavior` stays at its default: the bar never minimises. Think's screens are short; a shrinking bar would add motion for nothing.
- `.tabViewBottomAccessory` is reserved for exactly one thing: a running Focus session shown while another tab is selected, in the way Music shows the current track. [focus.md](focus.md) section 6 designs it: one form, shown through `tabViewBottomAccessory(isEnabled:)`, which needs iOS 26.1, so iOS 26.0 has none. No other feature may claim the slot.

### 13.3 Toolbar items and identity elements

Custom circular buttons are gone from every screen: back, add, menu, streak, close. Their replacements are navigation-bar and toolbar items under the rules in section 6 (symbols without enclosing circles, `ToolbarItemGroup` and `ToolbarSpacer(.fixed)`, at most three groups, text and symbol items never mixed in one group, every icon-only item created with a title).

Where the elements that lived in that chrome land:

| Element | Home |
| --- | --- |
| Streak badge | Today, trailing toolbar: `Label("Streak", systemImage: ThinkSymbol.streak)` plus the numeral in `Font.think(.numeral)`, tinted `accentInk`, in its own glass group. Opens the streak calendar sheet. This is the only tinted toolbar item in the app and the only place the streak number appears in chrome. |
| Saved lines bookmark | Today, trailing toolbar, `ThinkSymbol.savedLine`, its own group (a symbol-only item never shares a group with the text-and-symbol streak item). Today's trailing bar reads: bookmark, fixed spacer, streak. |
| Journal shortcut on Today | Removed; the Journal tab replaces it (IA decision). |
| Settings gear | Progress, trailing toolbar, `ThinkSymbol.settings`. |
| Focus tip (lightbulb) | Leaves Focus: a "Silence distractions" row in Settings, in a Focus section. |
| Focus stats | Leaves the Focus tab; history lives on Progress (IA decision). Focus keeps a plain-text "Last session" line, not a link. |
| Achievements medal, stats | Content on Progress, never chrome. |

### 13.4 Titles and what scrolls under the bar

| Screen | Title |
| --- | --- |
| Today, Paths, Journal, Progress, Settings | Large. The system collapses it inline on scroll. |
| Focus | Inline. The timer is the hero; a large title above it wastes the fold. |
| Every pushed screen | Inline. |
| Every sheet | Inline. |

Path detail is titled with the path name, inline. A long `de` or `bg` name truncates in the bar and appears in full as the first content row, so nothing is lost to truncation. Content always scrolls under the bar behind the scroll-edge effect; nothing is pinned above the bar and nothing pads the top to avoid it.

### 13.5 Back navigation and sheets

- The system back button everywhere: parent title, chevron alone at accessibility sizes. No custom back control.
- Sheets: inline title, `.cancellationAction` and `.confirmationAction` items ("Cancel" and "Done"; "Close" alone on read-only sheets). The custom X circles in `ShareCardSheet`, `StreakShareSheet` and `AchievementShareSheet` go.
- On share sheets the one `.glassProminent` primary is "Share" in the trailing slot.
- `.interactiveDismissDisabled` only on editors holding unsaved text.

### 13.6 Where the primary action lives

The primary action has four legal homes. The test, in order:

1. **Floating bottom-trailing** when the action creates something new from a list screen. Built with `.safeAreaBar(edge: .bottom, alignment: .trailing)` holding one `.glassProminent` button, created as `Button("New note", systemImage: ThinkSymbol.add)` with `.labelStyle(.iconOnly)` so the accessibility label comes from the title. The bar floats above the tab bar, extends the scroll-edge effect and insets the list by itself. It coexists with the Focus accessory (13.2): the accessory rides in the tab-bar area, the bar sits above it. Today only Journal's new-note action qualifies; Saved lines, Paths and Progress create nothing.
2. **Inside the content panel it acts on**: Today's next-act panel for the question, move or retro action ([today.md](today.md) section 2), and path detail's step card for "Complete step" ([paths.md](paths.md) section 5.1).
3. **Centred in a bottom safe-area bar** for Focus's Start/Pause, with End and Skip beside it as `.glass`, so the controls stay reachable at every size ([focus.md](focus.md) section 5). Onboarding uses the same home at full width for Continue and Begin practice, under its page dots ([onboarding.md](onboarding.md) section 2).
4. **Trailing toolbar** otherwise: Share on share sheets, Done on editors. Path detail has no toolbar Confirm; its one action lives in the step card (rule 2, owner 2026-09-26).

No screen uses a `.bottomBar` toolbar placement: it would stack a second full-width glass bar over the tab bar. `.overlay(alignment: .bottomTrailing)` with padding is the pattern the bug inventory retires and is not used.

### 13.7 Non-text chrome at accessibility sizes

1. Symbols always carry a text style (`.font(.body)`, `.imageScale`), never `.font(.system(size:))`; SF Symbols then scale with type. Absorbs `TOD-4`.
2. Segmented pickers are not used in Settings. Appearance is a `Picker` with `.pickerStyle(.inline)` inside the `Form`, one row per choice, as in the system Settings app. Absorbs `SET-7`.
3. Fixed-geometry graphics (the Focus session arc, progress rings, the weekly chart) take their size through `@ScaledMetric` with a ceiling. When `dynamicTypeSize.isAccessibilitySize` they switch to a linear form: the arc becomes the numeral over a `ProgressView(value:)` bar, the chart becomes rows. The numeral is the information; the arc is decoration and yields first. Absorbs `FOC-4`.

Rules 2 and 3 were shown on device in the Settings and Focus prototypes and are locked as layout rules (section 12).

### 13.8 Tab bar

- Five tabs, symbols in section 7. Selected tab tinted `accentInk` through `.tint` on the `TabView`; unselected items are system label colour. This and the streak item are the two identity marks a bar may carry.
- No search tab, no badges, no hidden or disabled tabs.

## 14. Day arc

Resolves the graphic decision of [Today: above the fold and glance readability](https://github.com/Vankata03/Think/issues/73). One component, `DayArcView(hour:states:)` in `ThinkShared/Design`, drawn live on Today and once, static, on the first onboarding step.

- A half circle from 06:00 to 22:00: `separator` track, `accent` elapsed stroke, an `accent` sun at the current hour, three markers for the ritual acts (question 08:00, move 14:00, retro 20:00) in `success` / `accent` / dashed `secondaryLabel` for done / next / later, captions in the marker's colour outside the curve, the weekday, count and time in the centre.
- Motion animates the hour fraction along the curve, never the point; Reduce Motion cuts.
- At accessibility sizes the arc becomes "*n* of 3" over a `ProgressView` bar (13.7).
- Sizes, offsets and the accessibility label are in [today.md](today.md) section 3. Onboarding draws it at a fixed 07:00, before the first marker, with no act done and no centre text ([onboarding.md](onboarding.md) section 3). Widgets may adopt it later through [widgets.md](widgets.md); no other screen draws it.

## 15. Removed screens

Practice detail is out of the app (owner, 2026-09-16, [today.md](today.md) section 5): the line, Saved lines and the answer detail carry no door to it, and `PracticeDetailView` is deleted in the Today build together with `TodayView` and `FavoritesView`. Every brief lists the views its build deletes; nothing stays behind a flag.
