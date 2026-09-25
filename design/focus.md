# Focus

Resolves [Focus: timer screen and session close flow](https://github.com/Vankata03/Think/issues/76), part of the [Think UI redesign map](https://github.com/Vankata03/Think/issues/68). Decided with the owner on 2026-09-25 after six canvas rounds (hero forms, placements, eleven duration mechanisms, the wheel and a close-flow sheet; `prototype-focus/` on branch `prototype/focus-stage`) and a SwiftUI prototype run on the Simulator in dark and at AX3 (same branch, `Think/Views/FocusPrototypeView.swift`).

This brief inherits [design-system.md](design-system.md): tokens (section 2), type roles (3), spacing (4), states (8) and the chrome baseline (13). It states only what Focus decides, including the places where Focus is the exception to section 13.

## 1. What Focus is

Focus starts a timed work interval, runs it, rests, and stops. It asks for nothing afterwards: the close flow (outcome, energy and a closing note) is removed. A session keeps its optional intention; completing the work phase counts as practice, as before. History and statistics live on Progress (IA decision); Focus shows only the most recent session as one line.

## 2. Structure: the stage

Focus is the one screen that is not a `List`. It is a stage: everything sits on the plain `background`, with no cards, sections or grouped rows. `NavigationStack`, inline title "Focus", no toolbar items. The content is a `ScrollView` with one centred column, so accessibility sizes can scroll; the controls ride in a centred `.safeAreaBar(edge: .bottom)` above the tab bar, so they never scroll away (`FOC-5`).

Top to bottom:

| Element | Idle | Running or paused | Break |
| --- | --- | --- | --- |
| Headline | The intention as a `TextField` in the `line` role (`.title2` serif), centred, placeholder "What are you working on?". Under it, when the field is empty, the reuse suggestion as a plain button in `accentInk`. | The intention as read-only text in the `line` role; "Deep work" in `secondaryLabel` when none was set. | As running. |
| Done line | none | none | "Session done · *n* min" in `secondary`, the checkmark in `success`. |
| Arc | Previews the split (section 3). | Shows progress. | Shows progress through the break. |
| Wheel | Work and break minutes (section 4). | Hidden. | Hidden. |
| Last session | "Last session · *n* min · *time*" in `secondary`. Plain text, not a link. Absent until the first session. | Same. | Same. |
| Controls | Start. | End · Pause · Skip (paused: End · Resume · Skip). | Pause · Skip to work. |

The journal lock still guards the intention: while locked, the headline is an "Unlock private intention" button and nothing private is drawn.

## 3. Arc

The session drawn as a half circle in the style of Today's day arc (`today.md` section 3): the work part and the break part share one curve.

- Proportion: the work part spans `work / (work + break)` of the curve, the break tail the rest, separated by a small gap and a hollow `success` dot at the boundary.
- Track: `separator`, 3pt, round caps. Break tail: `success` at 45%, dashed while idle, solid once a session starts.
- Progress: the elapsed work in `accent`; the elapsed break in `success`. The sun (24pt disc with an 18% halo) sits at now: at the left end while idle, moving through work, then along the tail, where it turns `success`.
- Captions: the end of work as a clock time in `caption2` semibold `accentInk`, outside the curve at the boundary; "done" there during the break. The end of the break in `caption2` semibold `success` under the right end. "now" in `caption2` `secondaryLabel` under the left end while idle. Clock times use the device format (12h in en_US, 24h in `bg` and `de`).
- Centre: the countdown in the `countdown` role, its Dynamic Type ceiling at `.xxxLarge` (the clamp section 3.1 asked for); past that the layout is the accessibility form below, then one caption in `secondary`: "then *n* min break" (the break in `success`) while idle, "until *time*" while running, "Paused", or "Break" in `success`.
- While idle, the arc follows the wheel live: the proportion and the captions move as the wheel turns.
- Motion: the sun moves along the curve (the fraction is the animatable value, as `ArcPosition` on Today), 0.8s ease-in-out; proportion changes 0.3s. Reduce Motion: no animation.
- Accessibility: the arc and its captions are one element, labelled with the countdown, the phase and the end time. At accessibility sizes (section 13.7) the arc is replaced by the countdown, the caption and a `ProgressView(value:)` bar tinted `accent` (`success` in the break), with the end time under its trailing end.
- Swift: `SessionArcView` beside `DayArcView` in `ThinkShared/Design`, sharing the positioning modifier.

## 4. Duration: the wheel

Two system wheels side by side, as in the Clock app's Timers tab: `Picker` with `.pickerStyle(.wheel)`, three rows visible (about 120pt), each column headed in `caption` semibold `secondaryLabel` ("Work", "Break").

- Work: 5 to 120 minutes in steps of 5. Break: 1 to 30 minutes in steps of 1. Each row reads "*n* min", the unit in `accentInk` for work and `success` for break.
- Turning either wheel sets the duration at once; there is no Done. The pair 25/5 selects the classic preset and 50/10 the long one, so Siri, the Control and the Watch keep their names; every other pair is the custom preset. Presets are not named anywhere on the screen.
- A stored custom work length that is not a multiple of 5 (possible from the old pickers) initializes the wheel at the nearest step, clamped to 5–120 minutes. Start uses that displayed wheel value, never the old stored value, and saves it as the new work length before starting the session. Turning the wheel still saves the selected duration at once. The displayed and started lengths must always agree.
- The wheel exists only while idle. The duration cannot change mid-session, so changing it can no longer end a session silently (the old sheet recorded partial effort without saying so).
- At accessibility sizes the columns stack vertically. The wheel rows keep the system wheel's type size, as in Clock.

## 5. Controls

In the bottom safe-area bar, centred, `ThinkSpacing` between buttons; stacked vertically at accessibility sizes.

- **Start / Pause / Resume**: the screen's one `primary` (`.glassProminent`, `accent`, `accentOnFill` label and symbol).
- **End**: `.glass`, shown while a work phase is running or paused. Ends the session and records partial effort, as Reset did. It asks first ("End this session?", message "The time you've done so far is kept as partial effort.", destructive "End session") only once at least one minute of work has been done; before that it ends at once.
- **Skip** / **Skip to work**: `.glass`. Unchanged behaviour: skipping never counts the session.
- Haptics as today: start, pause, reset on End, selection on Skip and on each wheel step, success when a phase ends by itself.

## 6. Bottom accessory

While a session is running or paused and another tab is selected, the tab view shows `tabViewBottomAccessory(isEnabled:)` (section 13.2):

- Content: the `focus` symbol (`accentInk`, `success` in the break), the countdown in the `countdown` design at `.subheadline` semibold with monospaced digits, one line in `secondaryLabel`, and a trailing Pause/Resume button created with its title. The line reads "Break" during a break, the intention during work only while the journal is unlocked, and "Deep work" during work while locked or when there is no intention. Apply the same lock check to the accessory's accessibility label and update it as soon as the lock state changes; no private intention appears across tabs while locked.
- Tapping anywhere else on the accessory selects the Focus tab.
- One form only: the tab bar never minimises (section 13.2), so the inline placement never occurs.
- `isEnabled:` needs iOS 26.1. The app targets 26.0, where an accessory cannot be hidden; on 26.0 there is no accessory. The Live Activity carries the session there.

## 7. Where the removed Focus elements go

| Element | Now |
| --- | --- |
| Focus cue (the daily quote under the timer) | Removed. The daily line belongs to Today. |
| "*n* today" pill | Removed. Counts live on Progress. |
| Stats toolbar button and `FocusStatsView` | Leaves Focus. History and stats are the Progress brief's. |
| Tip button and "Silence distractions" sheet | A "Silence distractions" row in Settings, in a Focus section, pushing the same guide. |
| Notification permission | Asked in onboarding and switchable in Settings ("Session end alerts"). Never asked at Start: the timer no longer requests authorisation. If alerts are off, phase ends are not announced; the Live Activity and the accessory still show them. |
| Close flow: "Reflect on your session", `FocusSessionDetailView`, outcome, energy, closing note | Removed. |

## 8. Data

- The intention is still stored per session in `FocusSessionMetadata`.
- Outcome, energy and the closing-note link stay in the store and in the model, unread and unwritten. No migration; nothing is deleted. If the close flow ever returns, the history is there.
- Focus notes already written stay in the Journal as entries. No new focus notes are created. How the Journal shows and edits them (the editor's outcome and energy pickers go) is the Journal brief's decision.

## 9. Removed views and code

The build that ships this brief deletes what it replaces; nothing stays behind a flag:

- `Think/Views/FocusView.swift`, replaced whole, including `FocusCountdownView`, `DurationPairSummary`, `FocusDurationSheet` and `FocusTipSheet` (the guide's text moves to the Settings row).
- `Think/Views/FocusSessionDetailView.swift` and every link to it (`FocusView`, `FocusStatsView`).
- In `PomodoroTimer`: `pendingFocusNote`, `FocusNotePrompt`, `focusNotePromptWindow`, `focusNotePromptExpiry`, `clearPendingFocusNote`, `discardStalePendingFocusNote`, the `focus.pendingFocusNote.v1` key, and the `requestAuthorizationIfNeeded` calls in `start()` and in remote-state adoption. Tests that cover them change with them.
- The outcome and energy seeding in the audit fixture in `ThinkApp.swift`.
- `Think/Views/FocusPrototypeView.swift` never merges; it stays on `prototype/focus-stage`.

## 10. Absorbed bugs

From `research/ui-bug-inventory.md` (branch `research/ui-bug-inventory`):

| ID | Fix |
| --- | --- |
| `FOC-1` | No session-duration card; the controls sit in the safe-area bar above the tab bar. |
| `FOC-2` | One alignment: a single centred column. |
| `FOC-3` | The "today" pill is removed. |
| `FOC-4` | At accessibility sizes the arc yields to the linear bar; the time and progress stay. |
| `FOC-5` | Controls pinned in the safe-area bar; the primary never needs a scroll. |
| `FOC-6` | No custom header; the inline navigation title and the scroll-edge effect (no `.toolbarBackground(.hidden)`). |
| `FOC-7` | The arc fills with elapsed time and the sun marks now. |
| `FOC-8` | The cue is removed; nothing appears or disappears above the arc when a session starts. The wheel folds away below it. |
| `FST-1`, `FST-2` | Focus stats leave Focus; the Progress brief owns them. |
| Observation "Break as a system green dot" | Break is the `success` token throughout (section 2.1). |
| Observation "German leaves Deep Work untranslated" | "Deep work" and "Break" are localised strings in all seven locales; the build checks the catalogue. |
| Observation "notification alert at the first session start" | The timer no longer asks (section 7). |

## 11. Acceptance floor

Section 11 of the design system applies. Specific to Focus:

- Dynamic Type through AX3: the arc yields to the bar, the controls stack and stay in the bar, the wheel columns stack and the screen scrolls to reach the break wheel. Seen on the prototype at AX3: the controls and the bar hold; the headline placeholder truncated to "What are you…". The build must let the placeholder wrap (a placeholder `Text` in the `line` role behind the field, or a shorter string), and measure it in `bg` and `de`.
- `bg` and `de`: the arc captions ("then *n* min break", "until *time*") and the done line at the default size; End, Skip and "Skip to work" at AX3.
- Every icon-only control has a title: the accessory's Pause/Resume.
- Both appearances, dark the reference; light uses the `accent` fill (`#F2C41C`) on the arc and the sun, never the ink.
- Reduce Motion: the sun and the proportion do not animate; state changes cut.
- VoiceOver: each wheel is adjustable with its unit read ("25 minutes"); the arc is one element (section 3).

## 12. Open for the build

- The end-of-work caption crowds the trailing edge on a 402pt-wide screen when work ends past about 80% of the curve (seen at 25/5 in the prototype, "10:41 PM" in 12h format). Keep it on screen by moving it inside the curve at those positions; the exact threshold is set on device.
- The wheel sits close under the arc's end captions at the default size; the spacing step between them is set on device.
