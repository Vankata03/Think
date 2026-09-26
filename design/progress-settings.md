# Progress and Settings

Resolves [Progress and Settings after the IA split](https://github.com/Vankata03/Think/issues/77), part of the [Think UI redesign map](https://github.com/Vankata03/Think/issues/68). The owner chose the compact inline achievements layout, the order after the streak, and two recent Focus rows on 2026-09-25. The [HTML study](https://github.com/Vankata03/Think/blob/prototype/progress-settings/prototype-progress/index.html) compares three achievements treatments; the [throwaway SwiftUI prototype](https://github.com/Vankata03/Think/blob/prototype/progress-settings/Think/Views/ProgressPrototypeView.swift) shows the chosen layout and Settings on a Simulator. Its numbers and actions are sample data, not production behavior.

This brief inherits [design-system.md](design-system.md): colours, type, spacing, symbols, states, and iOS 26 chrome. Progress owns evidence of practice; Settings owns controls and account or device status. Neither screen adds a way to start a new practice.

## 1. Structure and navigation

The fifth tab is **Progress** (`ThinkSymbol.progress`), replacing Profile. `ProgressView` is a `List` in a `NavigationStack`, with a large system title and a monochrome `ThinkSymbol.settings` gear in the trailing toolbar. The gear pushes **Settings**; no Settings row sits in Progress content. Settings is one grouped `Form` with a large title and the system back button. The tab bar and both navigation bars use the native chrome from design-system section 13.

Progress reads top to bottom:

1. Streak hero card. The current streak numeral, “days,” and “View calendar” sit together with an accent flame. The whole card opens the existing `StreakCalendarSheet`. Zero uses the design-system's “Start today” or “Begin again” state; the streak calendar and sharing stay available. Today's streak toolbar item remains where the chrome decision put it.
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

`WKR-1` and `WKR-2` concern the internals of `WeeklyReviewView`; this brief only places its entry card. They remain for the Weekly review build ticket.

## 6. Acceptance floor

- Dark and Light on device; the default is Dark. Only streak and earned medals use accent as evidence; Settings symbols and chrome remain monochrome. Increase Contrast keeps the status text and earned/locked distinction readable without colour alone.
- Dynamic Type through AX3 in `en`, `bg`, and `de`: titles, settings switches, the inline Appearance picker, medal strip, weekly chart replacement, and all sections remain reachable by scrolling above the tab bar. Medals stack or become labelled rows when three no longer fit.
- VoiceOver: the streak card announces the count and calendar action; each medal announces name and Earned or Locked plus the unlock condition; the week chart or rows announce day and count; history rows announce time, status, and known duration. Private intentions disappear from the accessibility tree as soon as the journal locks. Gear has the “Settings” label.
- Reduce Motion: no required animation. Native navigation and state changes respect the system setting. The full achievements list has no animated scroll hint.
- No Focus history detail route. An earned medal still shares through the existing flow. Weekly review still opens its journal entry detail under the journal gate. Export and deletion retain their existing confirmations and failure paths.

## 7. Prototype evidence and build checks

The signed SwiftUI prototype ran on an iPhone 17e Simulator with iOS 26.5. Progress and Settings were inspected in dark and light; at AX3, the inline Appearance picker remained readable and Settings scrolled to its final About row without clipping. The prototype uses static content and nonfunctional example rows, so it validates layout only. The production build must test the real store bindings, lock transition, empty and zero states, notification and Health permissions, sharing, export, deletion, all seven localizations, and iOS 26.0 behavior. An earlier unsigned prototype installation exited at launch because its CloudKit entitlement was absent; installing a signed build restored normal launch. This is not evidence of a production crash.
