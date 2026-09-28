# Progress and Settings

Resolves [Progress and Settings after the IA split](https://github.com/Vankata03/Think/issues/77), part of the [Think UI redesign map](https://github.com/Vankata03/Think/issues/68). The owner chose the compact inline achievements layout, the order after the streak, and two recent Focus rows on 2026-09-25. The [HTML study](https://github.com/Vankata03/Think/blob/prototype/progress-settings/prototype-progress/index.html) compares three achievements treatments; the [throwaway SwiftUI prototype](https://github.com/Vankata03/Think/blob/prototype/progress-settings/Think/Views/ProgressPrototypeView.swift) shows the chosen layout and Settings on a Simulator. Its numbers and actions are sample data, not production behavior.

This brief inherits [design-system.md](design-system.md): colours, type, spacing, symbols, states, and iOS 26 chrome. Progress owns evidence of practice; Settings owns controls and account or device status. Neither screen adds a way to start a new practice.

## 1. Structure and navigation

The fifth tab is **Progress** (`ThinkSymbol.progress`), replacing Profile. `ProgressView` is a `List` in a `NavigationStack`, with a large system title and a monochrome `ThinkSymbol.settings` gear in the trailing toolbar. The gear pushes **Settings**; no Settings row sits in Progress content. Settings is one grouped `Form` with a large title and the system back button. The tab bar and both navigation bars use the native chrome from design-system section 13.

Progress reads top to bottom:

1. Streak hero card. The current streak numeral, “days,” and “View calendar” sit together with an accent flame. The whole card opens the streak sheet as a sheet, the same presentation as Today's toolbar item, never a push (section 8). Zero uses the design-system's “Start today” or “Begin again” state; the streak calendar stays available, and sharing does once there is any practice day. Today's streak toolbar item remains where the chrome decision put it.
2. **Weekly review**, immediately after the streak. A short row gives this week's practice days out of seven and pushes `WeeklyReviewView`. A zero week still shows “0 of 7 days” and can open a writable reflection. The review's private text and next-week intention stay inside its existing journal gate. The build makes a saved reflection push `JournalEntryDetailView` from the review; the current review renders that text without a link.
3. **Practice**. Three all-time values: practice days, completed Path steps, and completed Focus sessions. Below them, a small Monday–Sunday chart shows completed Focus sessions for this calendar week. These are counts from `ProgressStore`; partial effort is not a completed Focus session. The chart yields to labelled day rows at accessibility text sizes. With no sessions, show a plain zero summary rather than an empty grid.
4. **Achievements**. A compact inline strip displays up to three earned medals, with title and earned state, followed by “All achievements.” The row pushes a full `AchievementsView` list grouped by Streak, Paths, and Focus sessions. The full list shows unearned medals dimmed, their unlock conditions, and the existing share action on earned medals. If none are earned, use a single explanatory row in the compact strip; the full list still shows locked milestones. Achievements are content, never a toolbar item or a modal sheet.
5. **Focus history**. Show the two most recent sessions, newest first, then “See all sessions” pushing `FocusHistoryView`. Each row gives date and time, completed or partial status, actual active time when known, and the optional intention only while the journal is unlocked. No row opens a session detail; the full history is a non-navigating list. With no sessions, show the design-system's empty line and a route to Focus. The full list retains the 365-day history boundary and explains that older actual durations can be unknown while all-time totals remain.

The compact medals and two history rows keep evidence visible without making Progress a catalogue. Long rows wrap at Dynamic Type sizes; the `List` supplies tab-bar clearance. No fixed bottom padding, custom chevrons, or nested stat cards.

## 2. Focus totals and private intentions

`FocusStatsView` is replaced by the Practice chart and `FocusHistoryView`; it does not remain as a second statistics destination. The full history begins with the existing weekly completed sessions, completed planned minutes, and partial active effort, then the retained sessions. Completed minutes use planned session lengths; partial effort uses recorded active time. Keep the existing explanatory footnote and all-time Focus count. A weekly review link is unnecessary there because its card is above Practice on Progress.

The records and aggregates come from `ProgressStore`; intentions come from `JournalRepository.sessionMetadata(sessionID:)`. Do not fetch or display private metadata while `JournalLock.isLocked`. On lock changes, clear any cached intention text immediately. If metadata cannot be read, fail closed: show the non-private timing and status only. No outcome, energy, or closing note is read or shown. These remain stored but unused under [focus.md](focus.md) sections 8–9. The Focus redesign deletes `FocusSessionDetailView`; this brief removes any remaining links to it.

## 3. Settings sections

Each control is a native row with one monochrome SF Symbol where the concept has a symbol; labels and values use system colours. The sections are:

| Section | Rows and behavior |
| --- | --- |
| Appearance | Inline `Picker` with Auto, Light, Dark as separate rows. Dark is the default for a new installation, as decided in the design system; a saved user choice wins. |
| Reminders | Daily line and Evening retro switches; each enabled reminder reveals its time picker. A denied notification permission shows the current explanatory text and an “Open Settings” action. |
| Focus | “Silence distractions” pushes the guide moved from Focus. “Session end alerts” controls phase-end notifications; permission is handled in onboarding, never at timer Start. “Log focus to Health” retains the existing Health authorization and unavailable/denied explanations. |
| iCloud | Status, syncing indication, and last successful upload when available. It is informational, never a sync toggle: mirroring is selected when the SwiftData container is built. Copy must reflect the real state and explain that journal changes, including deletions, sync through the user's iCloud when available; Think has no server or account. |
| Privacy and lock | “Lock journal” keeps its availability and authentication behavior. “Show intention on Lock Screen” controls the Live Activity and Dynamic Island disclosure and keeps its explanatory footer. |
| Data | “Export journal” keeps separate authentication even during an unlocked session and removes the temporary file after sharing. “Delete all data” uses a destructive row and the current detailed confirmation; Health records already sent remain in Health. Preserve both failure alerts. |
| Feedback | Share an idea, Report a problem, Rate Think. Retain current mail subjects, version context, and App Store review behavior. |
| About | Help & Support, Privacy Policy, and the installed app version. |

Use Form row insets and section footers, rather than nested hand-built cards. A switch with a wrapping label uses a vertical arrangement at accessibility sizes so the control does not float between text lines. Keep the notification, Health, iCloud, and journal-lock status refreshed when the app becomes active.

## 4. Existing routes and removal

Journal is its own tab; Saved lines is reached from Today's bookmark. “Find a practice” is removed under the IA decision. Neither gets a duplicate Progress card. The Progress build replaces `Think/Views/ProfileView.swift` with `ProgressView` and `SettingsView`; it replaces `Think/Views/FocusStatsView.swift` with `FocusHistoryView`. The achievements content moves out of `StreakAchievementsSheet` into `AchievementsView`, preserving sharing; the old sheet and its “Scroll for more” overlay are removed. The build updates `RootTabView` and every caller, accessibility identifier, and preview that still names Profile or the removed destinations. Nothing stays behind a flag. The prototype branch never merges into production.

## 5. Absorbed bugs

From `research/ui-bug-inventory.md` on branch `research/ui-bug-inventory`:

| ID | Resolution |
| --- | --- |
| `PRO-1` | Native List sections supply consistent vertical spacing. |
| `PRO-2`, `PRO-3` | One Practice row, no tiles nested inside a card; values become labelled rows at accessibility sizes. |
| `PRO-4` | The List respects the tab-bar safe area and long titles wrap. Saved lines leaves this screen. |
| `SET-1`, `SET-2`, `SET-3`, `SET-5` | Native Form rows, labels, and footers align symbols and wrapped text. |
| `SET-4`, `SET-6`, `SET-9` | The Form scrolls the Data section and every toggle above the tab bar. |
| `SET-7` | Inline Appearance choices scale with Dynamic Type. |
| `SET-8` | iCloud status and explanation are separate rows or footer text with system spacing. |
| `ACH-1` | Full achievement list is a pushed screen, with no detent or overlay on a cut tile. |
| `FST-1` | No empty chart grid; zero Focus activity has a plain summary. |
| `FST-2` | Focus history is a List with native bottom clearance. |
| `STK-1`, `STK-2` | Streak sheet; see section 8.6. |

`WKR-1` and `WKR-2` concern the internals of `WeeklyReviewView`; this brief only places its entry card. They remain for the Weekly review build ticket.

## 6. Acceptance floor

- Dark and Light on device; the default is Dark. Only streak and earned medals use accent as evidence; Settings symbols and chrome remain monochrome. Increase Contrast keeps the status text and earned/locked distinction readable without colour alone.
- Dynamic Type through AX3 in `en`, `bg`, and `de`: titles, settings switches, the inline Appearance picker, medal strip, weekly chart replacement, and all sections remain reachable by scrolling above the tab bar. Medals stack or become labelled rows when three no longer fit.
- VoiceOver: the streak card announces the count and calendar action; each medal announces name and Earned or Locked plus the unlock condition; the week chart or rows announce day and count; history rows announce time, status, and known duration. Private intentions disappear from the accessibility tree as soon as the journal locks. Gear has the “Settings” label.
- Reduce Motion: no required animation. Native navigation and state changes respect the system setting. The full achievements list has no animated scroll hint.
- No Focus history detail route. An earned medal still shares through the existing flow. Weekly review still opens its journal entry detail under the journal gate. Export and deletion retain their existing confirmations and failure paths.

## 7. Prototype evidence and build checks

The signed SwiftUI prototype ran on an iPhone 17e Simulator with iOS 26.5. Progress and Settings were inspected in dark and light; at AX3, the inline Appearance picker remained readable and Settings scrolled to its final About row without clipping. The prototype uses static content and nonfunctional example rows, so it validates layout only. The production build must test the real store bindings, lock transition, empty and zero states, notification and Health permissions, sharing, export, deletion, all seven localizations, and iOS 26.0 behavior. An earlier unsigned prototype installation exited at launch because its CloudKit entitlement was absent; installing a signed build restored normal launch. This is not evidence of a production crash.

## 8. Streak sheet

Resolves [Streak calendar sheet: detent, header and the two unabsorbed inventory bugs](https://github.com/Vankata03/Think/issues/97), part of the same map. The owner accepted every recommendation on 2026-09-28 after reviewing the options side by side on a [throwaway canvas](https://github.com/Vankata03/Think/blob/prototype/streak-sheet/prototype-streak/index.html). The canvas uses sample data and is not a build reference.

The streak sheet is a glance at the streak and the days behind it. It shows one month at a time. It creates nothing and asks nothing.

### 8.1 Presentation and chrome

- One sheet, `StreakCalendarSheet`. Today's streak toolbar item and the Progress streak hero card both present it as a sheet. Progress never pushes it, so there is one presentation and one set of chrome.
- `NavigationStack` with the inline title "Streak". "Close" sits in `.cancellationAction`. The trailing slot holds `Button("Share", systemImage: ThinkSymbol.share)` with `.labelStyle(.iconOnly)` and the plain glass style, never `.glassProminent`, because the sheet has no primary action (design system 13.5). Share presents `StreakShareSheet` for the displayed month, as it does now.
- Share is hidden for a person who has never practised, because there is nothing to share. A lapsed streak keeps Share, since its calendar cards still show past practice days.
- Detents: one fitted detent plus `.large`, opening at the fitted detent. The fitted height is measured from the content with `onGeometryChange` and applied as `.height(_:)`. The grid always reserves six week rows, so paging between a five-row and a six-row month never resizes the sheet. When `dynamicTypeSize.isAccessibilitySize` is true, or the measured height exceeds the large detent, the sheet opens at `.large`. The drag indicator is visible.

### 8.2 Layout

A `List` (`.insetGrouped`) with two parts and system margins throughout.

1. **Header**, a clear row (`.listRowBackground(Color.clear)`), with no card.
   - Alive: `ThinkSymbol.streak` in `accent`, the numeral in `Font.think(.numeral)` with `.monospacedDigit()`, and the unit in `body`, all in one `HStack(alignment: .firstTextBaseline)`. The unit is plural-aware through the string catalog ("1 day", "12 days").
   - Zero, per design system section 8: `ThinkSymbol.streak` in `secondaryLabel` and "Begin again." for a lapsed streak or "Start today." for a person who has never practised, in `body`. There is no button, because today's practice is the restart.
   - Nothing else. No longest streak (the store keeps none, and no other screen shows one) and no line about keeping the streak alive today, which would lean toward guilt. The today ring in the calendar already shows whether today is practised.
2. **Calendar**, one `surface` section.
   - First, the month pager: `Button("Previous month", systemImage: "chevron.left")` and `Button("Next month", systemImage: "chevron.right")`, icon-only, in `label` colour, with the month and year in `headline` between them. Next is disabled on the current month. Previous is disabled on the month of the first practice day, or on the current month when there is none. There is no swipe gesture: it would compete with sheet dismissal and add a control nobody can see.
   - Then the weekday initials (`veryShortStandaloneWeekdaySymbols`, respecting `firstWeekday`) in `caption2` semibold `secondaryLabel`, and the day grid built from the existing `MonthGrid`. Day discs are 32pt at the default size through `@ScaledMetric`, with a 40pt ceiling.

| Day | Marker |
| --- | --- |
| Practice day | `accent` fill disc, digit in `accentOnFill`, semibold. |
| Today, not yet practised | 1.5pt `accent` ring, digit in `label`. |
| Today, practised | `accent` fill disc with a 1.5pt `accent` ring outside it, separated by a 2pt gap in the section colour. |
| Past day without practice | No disc, digit in `secondaryLabel`. |
| Future day | No disc, digit in `tertiaryLabel`. |

The calendar uses `accent` rather than `success` because it is evidence of practice (design system principle 3), like the flame and the medals. Green keeps its meaning of an act done today on the day arc and the step trail. Meaning never rests on colour alone: a practice day has a filled disc and a heavier digit where other days have neither, and VoiceOver names the state. In light mode the fill falls under the accepted contrast deviation in design system section 2.2.

Changing month slides the new month in from the direction of travel with `ThinkMotion.move` and plays the existing selection haptic. Under Reduce Motion it crossfades with `ThinkMotion.reduced`, as it does now.

### 8.3 Accessibility sizes

When `dynamicTypeSize.isAccessibilitySize` is true, the grid yields to its linear form (design system 13.7 rule 3). The section keeps the pager, whose month title may wrap to two lines rather than truncate. Below it, "*n* of *m* days" appears in `numeral` and `body` over a `ProgressView(value:)` tinted `accent`. For the current month, *m* counts the days up to and including today; for a past month, it is every day of that month. The header scales without limit.

The linear form gives up the visual day-by-day picture; the owner accepted that trade on 2026-09-28 in favour of legible text. It keeps day-level information for VoiceOver: the count is one element whose `accessibilityCustomContent` "Practised days" lists the month's practice days as dates and ranges ("1 to 5, 8, 9, 11 to 14 and 17 to 28 September").

### 8.4 VoiceOver

- The header is one element: "12-day streak", "Begin again" or "Start today".
- Each past or current day is one element, labelled with its date and state: "28 September, practised, today"; "27 September, practised"; "15 September". Future days are hidden from the accessibility tree.
- The chevrons and Share take their labels from their titles. Changing month announces the new month and year.
- In the linear form the section reads "September 2026, 21 of 28 days practised", with the practised days as custom content (section 8.3). Day-level history therefore stays available to VoiceOver at every text size.

### 8.5 Build ledger

- `Think/Views/StreakCalendarSheet.swift` keeps its name, `MonthGrid` and both callers; its body is replaced whole. The build removes the `ScrollView` and `VStack` stack with its 18, 20 and 24pt paddings, the hand-built calendar card (22pt radius and separator stroke), the bordered "Share your streak" button, the "Done" item, the `.large`-only detent, `flame.fill`, the 18% `accentColor` day disc with yellow digits, and the lowercase captions "streak", "start today" and "begin again". `TodayView` looks up the same three string-catalog keys for its streak caption, so the entries are deleted only by whichever build removes the last lookup: this one if the Today build has landed, otherwise the Today build.
- `StreakShareSheet` keeps its content, since share cards are out of scope. Its chrome follows design system 13.5, which already covers it: "Close" leading, "Share" as the one `.glassProminent` item trailing, replacing "Done".
- No view is deleted. Today's caller is specified in [today.md](today.md) and the Progress caller in section 1 of this brief.

### 8.6 Absorbed bugs

| ID | Resolution |
| --- | --- |
| `STK-1` | The fitted detent matches the content, with six grid rows always reserved, so the sheet has no empty lower third; `.large` remains for accessibility sizes. |
| `STK-2` | The flame, numeral and unit share one first baseline. The header row and the calendar section share the `List` system margins, replacing the 21pt and 17pt insets. |

### 8.7 Acceptance floor

- Dark and light. Check six states: streak alive with today practised, alive with today not yet practised, lapsed, never practised, a past month, and the first practice month with Previous disabled.
- Dynamic Type through AX3 in `en`, `bg` and `de`: the header numeral and unit, the state lines ("Begin again.", "Start today."), long month names such as `bg` "септември 2026 г." in the pager, and "*n* of *m* days" all wrap without clipping. The sheet opens at `.large` at accessibility sizes.
- Every icon-only control has a label: Share, Previous month, Next month.
- Reduce Motion: month changes crossfade.
