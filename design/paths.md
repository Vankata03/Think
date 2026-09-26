# Paths

Resolves [Paths list and Path detail: step progress legibility](https://github.com/Vankata03/Think/issues/75), part of the [Think UI redesign map](https://github.com/Vankata03/Think/issues/68). Decided with the owner on 2026-09-26 in two grilling rounds, three canvas rounds (twelve variants, A to L, in `prototype-paths/index.html` on branch `prototype/paths`) and a SwiftUI prototype run on an iPhone 17 Pro Simulator with iOS 26.5 in dark, light and at AX3 (same branch, `Think/Views/PathsPrototypeView.swift`, variants K, L, M and N, screenshots in `prototype-paths/screens/`). Variant N was chosen.

This brief inherits [design-system.md](design-system.md): tokens (section 2), type roles (3), spacing (4), symbols (7), states (8) and the chrome baseline (13). It states only what Paths decides.

## 1. What Paths is

A path is a multi-step programme with one step a day (`CONTEXT.md`: Path, Path step, Run). The Paths tab answers two questions at a glance: what is waiting today, and how far along the run is. The list opens on today's step; the detail puts that step and its one action first and draws the whole run once, below it, as the index of steps.

Paths is the only place a path step appears. Today stays with its three acts and shows no path step; the Paths tab carries no badge. A completed step still counts as meaningful practice for the streak.

## 2. Rules the design depends on

These are product rules settled in this ticket. The build changes `ProgressStore` to match; section 9 lists the work.

- **One step, then wait.** A person completes a step explicitly. The next step opens at **06:00 local time on the day after** the completion, the hour the day arc starts. It then waits, however long, until it is done; missed days advance nothing. This replaces the calendar-day rule in `ProgressStore.canCompletePathStep`, which opened the next step at midnight.
- **Paths unlock in order.** Clear thinking stays locked until a Deep focus run is finished (owner, 2026-09-26). Any finished run keeps the next path open, including while the earlier path is repeated.
- **No run history in the interface.** Runs stay in the data. The interface shows only that a path was finished ("Completed *n* times") and offers Begin again on a finished path. There is no mid-run restart and no way to browse an earlier run.
- **Same-day undo.** A completed step can be undone by a trailing swipe on its done row until midnight of the day it was completed, as Today's move does. The last step of a run cannot be undone: finishing a run unlocks the next path and can earn an achievement, and neither is taken back. Undo takes back everything the completion did, not just the step (section 9). A step carried over from before dated completions existed has no date, so it has no undo.
- **Unit and numbers.** The unit is "Step", never "Day" or "Lesson". Progress reads "Step *n* of *m*" everywhere, which retires the inventory observation that the list said "Day 2 of 21" while detail said "1 of 21 days".

## 3. The step trail

One drawing of a run, in two sizes. It shares its marker language with the day arc (design system section 14), so a finished act and a finished step look the same.

| State | Disc |
| --- | --- |
| Done | `success` fill, black `checkmark`. |
| Today | `accent` fill, the step number in `accentOnFill`, rounded semibold, with an `accent` halo at 25% opacity. |
| Not open yet | `surface` fill, 1.2pt dashed `secondaryLabel` ring, the step number in `secondaryLabel`. |

The discs sit on a 3pt `tertiarySystemFill` track. There is no "today" disc when today's step is done: the next step reads as not open yet.

- **Trail window** (`StepTrailWindow`). Seven discs around today's step (three before, three after, clamped at the ends of the run), 26pt through `@ScaledMetric`, spread across the row. The track and discs fade out through a 12% gradient mask at an edge where the run continues, and stay solid at an edge that is the run's first or last step. It appears only in the list hero (section 4).
- **Full trail** (`StepTrailView`). Every step of the run, seven to a row, 30pt discs through `@ScaledMetric`. Rows snake: the first row runs left to right, the second right to left, joined by a curve at the row end, like the Paths symbol. Each disc is a button that pushes its step (section 6), labelled "Step *n*, *title*" for VoiceOver with the state as the value ("done", "today", "opens tomorrow at 06:00", "not open yet"). A 7-step path is one row. It appears only on path detail (section 5).
- **Accessibility sizes.** When `dynamicTypeSize.isAccessibilitySize`, both forms yield (design system 13.7). The window becomes "*n* of *m* done" in `numeral` over a `ProgressView` bar in `accent`; the full trail becomes one row per step (section 5.3).
- **One drawing per screen.** The list shows the window, detail shows the full trail, and no screen shows both. Drawing the window on the step card and the full trail below it was built (variant L) and rejected on device (owner, 2026-09-26) because the run appeared twice.

## 4. Paths list

`NavigationStack` with a `List`, large title "Paths" (design system 13.4). No toolbar items.

### 4.1 Hero: today's step

The first section holds one row, the hero, on `surface`. It is a `NavigationLink` to the path's detail; the chevron is the system's.

| Part | Content |
| --- | --- |
| Trail window | Section 3. Top of the row. |
| Caption | `pathStepToday` symbol and "Today on *path* · Step *n*" in `secondary` weight semibold, `accentInk`. |
| Title | The step title, `.title2` semibold. |
| Lesson preview | The lesson in the `lesson` role, `secondaryLabel`, two lines at most. Hidden at accessibility sizes, where it would truncate after three words. |
| Time | "*n* min" in `secondary` semibold, `accentInk`. |

Which step the hero shows:

1. **A step is open.** The open step of the path practised most recently, by its last completion date (section 9 gives the fallback for runs carried over without dates; a path with no date at all ranks last); on a tie, library order (Deep focus first). A path that is unlocked but not started counts as having step 1 open, so a person who finishes Deep focus sees Clear thinking's first step next. A second path with an open step says "Step *n* today" on its row in section 4.2.
2. **No step is open, one was done today.** The hero stays and changes to its done form: caption "Step *n* done" with the `done` symbol in `success`, the next step's title in `secondaryLabel`, and "Opens tomorrow at 06:00". The window shows the step just done and no today disc.
3. **Every available path is finished.** No hero. The list starts with "All paths".

The hero is one accessibility element: "Today on Deep focus, step 5 of 21, Single-tab work, 25 minutes", or the done form's text.

### 4.2 All paths

A section headed "All paths", one row per available path, each a `NavigationLink` to its detail:

| Path state | Row |
| --- | --- |
| In a run | Path symbol (`scope`, `lightbulb`, from `ThinkingPath.icon`), name, trailing "*done*/*total*" in `numeral` design at `.subheadline` with monospaced digits, `secondaryLabel`. With a step open that the hero does not show: "Step *n* today" under the name in `secondary`. |
| Finished, no new run | Name, "Completed *n* times" under it in `secondary`. |
| Locked | `lock` symbol in `secondaryLabel`, name, "Finish *previous path* first" under it. The row stays tappable (design system section 8) and pushes the Locked detail (section 5.4). |

The section footer reads "Two more paths are in development." (the count follows `PathLibrary` paths with `isAvailable == false`; no footer when there are none). Unavailable paths have no rows: a row that leads nowhere reads as a bug.

## 5. Path detail

A `List`, inline title with the path name (design system 13.4). The first content row is the path name in full, `.largeTitle` bold, on a clear row background, so a long `de` or `bg` name that truncates in the bar is still read in full. The tagline is not shown; it cost the step card its place above the fold. No toolbar items: there is no mid-run restart and no history to open.

### 5.1 Today's step card

When a step is open, the next section is the step card, on `surface`. It carries no progress mark; progress is the caption's number and the full trail below.

1. Caption: `pathStepToday` symbol and "Today · Step *n* of *m* · *minutes* min", `secondary` weight semibold, `accentInk`.
2. Title: `.title2` semibold.
3. Lesson: the `lesson` role.
4. Task: "Task" in `caption` weight semibold, `secondaryLabel`, then the task in `body`. The text wraps; it never truncates.
5. "A smaller version": a `DisclosureGroup` in `accentInk` holding the smaller task, collapsed by default. Omitted when the step has none.
6. Actions, stacked, full width, same height and radius: "Focus for *n* min" as `secondary` (only when the step suggests Focus minutes), then **"Complete step" as the screen's one `primary`** (design system 13.6, rule 2). At accessibility sizes both labels wrap inside full-width buttons; the pill that wrapped lopsided (`PDT-5`) is gone.

"Focus for *n* min" sets the Focus wheel to *n* minutes of work and 5 of break, sets the intention to the step title unless the journal is locked, and switches to the Focus tab without starting the timer. If a session is already running it only switches tabs. [focus.md](focus.md) section 4 records the same entry point.

"Complete step" completes the step with `ThinkMotion.stateAnimation` and the success haptic, and the card becomes the done form (5.2).

### 5.2 Done today

When today's step is done, the step card is replaced by one section with two rows:

- Done row: `done` symbol in `success`, "Step *n* done", the step title under it in `secondary`. Static: no chevron, no tap. Trailing swipe reveals "Undo" under the rule in section 2. When the step completed the run, the finished state (5.4) shows instead and there is no undo.
- Next row: `lock` symbol in `secondaryLabel`, "Step *n+1* · *title*", "Opens tomorrow at 06:00" under it. Pushes the step page (section 6).

No primary on the screen in this state; nothing is left to do today.

### 5.3 Steps

A section headed "Steps".

- **Default sizes:** one row holding the full trail (section 3). The row has no separator and no chevron; each disc is its own target, at least 44pt including its spacing.
- **Accessibility sizes:** one row per step: status symbol (`done` in `success`, `pathStepToday` in `accent`, `lock` in `secondaryLabel`), "*n*" in `secondaryLabel` then the title, and a trailing value: the completion date for done steps, "Today" in `accentInk`, "Tomorrow, 06:00" for the next step after today's is done. The value stacks under the title (design system 3.2); the symbol aligns to the title's first baseline, which absorbs the misaligned status circle in `PDT-5`.

### 5.4 Other states

| State | Presentation |
| --- | --- |
| Run finished | Instead of the step card, one section: the path symbol and "Path completed." in `heading`, "Completed *n* times · last on *date*" in `secondary` (just "Completed *n* times" when the finished run has no date, section 9), and "Begin again" as a `secondary` button in `accentInk`. The Begin-again state (design system section 8) is a section here, not the whole screen, because the finished steps stay readable in the trail below. Begin again starts a new run at step 1 immediately; step 1 is open at once. For Clear thinking the path's `continuation` text sits under the count. |
| Locked path | The Locked state full screen (design system section 8): `ContentUnavailableView` with `lock`, "Finish *previous path* first." and one `secondary` "Open *previous path*", which replaces the stack with the previous path's detail. |

## 6. Step page

Pushed from a trail disc, a step row or the next row in 5.2. A `List`, inline title "Step *n*".

- First row, clear background: the step title in `.title` bold, "Step *n* of *m* · *path*" under it in `secondary`.
- **Done or today's step:** one section with the lesson in the `lesson` role and the task under "Task". A done step adds a row "Completed *date*" with the `done` symbol in `success`. Read only: the action for today's step lives on path detail, never here.
- **Not open yet:** the Locked state (design system section 8) as a `ContentUnavailableView` with `lock` and one line: "Opens tomorrow at 06:00." for the next step after today's is done, "Opens after step *n − 1*." for any later step, naming the step before the one on screen (step 7's page reads "Opens after step 6."). No lesson, no task, no action. The title stays visible so the run's shape can be read ahead; the content waits (owner, 2026-09-26).

## 7. Strings

| Key idea | English | Notes |
| --- | --- | --- |
| Hero caption | Today on %@ · Step %lld | Path name, step number. |
| Hero done caption | Step %lld done | |
| Opening time | Opens tomorrow at 06:00 | The time follows the locale's format; "06:00" is the English 24-hour form used in the prototype, 12-hour locales show "6:00 AM". |
| Row value | %lld/%lld | Done and total. |
| Row, second open step | Step %lld today | |
| Row, finished | Completed %lld times | Plural rule through the string catalog ("1 time"). |
| Locked row | Finish %@ first | |
| Footer | Two more paths are in development. | Count through the string catalog. |
| Card caption | Today · Step %lld of %lld · %lld min | |
| Primary | Complete step | Replaces "Mark day complete" and "Come back tomorrow". |
| Secondary | Focus for %lld min | |
| Done row | Step %lld done | |
| Next row | Step %lld · %@ | |
| Finished | Path completed. / Completed %lld times · last on %@ / Begin again | |
| Step page, locked | Opens after step %lld. | The number of the preceding step, *n − 1*. |

`bg` and `de` were checked on the canvas with the German set ("Schritt abschließen", "Öffnet sich morgen um 06:00", "Schließe zuerst „Tiefe Konzentration“ ab"): every string wraps inside its row at the default size. The build measures them again at AX3.

## 8. Removed views and code

The build that ships this brief deletes what it replaces; nothing stays behind a flag:

- `Think/Views/PathsView.swift` is replaced whole: the `ScrollView` card stack with its 20pt insets, `pathCard` with the hand-built rounded rectangle, the per-card `ProgressView`, the "In development" `DisclosureGroup`, and the selection-haptic gesture.
- `Think/Views/PathDetailView.swift` is replaced whole: the top `ProgressView` with "*n* of *m* days", the "All days" and "Practice runs" `DisclosureGroup`s, `selectedRunID` and the reviewing mode, the mid-run "Start a new run?" confirmation, the inline lesson push, "Mark day complete" and "Come back tomorrow", and the content-width "Focus for *n* min" pill.
- New views: the path list and detail as above, `PathStepView` (section 6), and `StepTrailWindow`, `StepTrailView` and `StepDisc` in `ThinkShared/Design` next to `DayArcView`, so the day arc and the trail can share the disc drawing.

## 9. Data and build work

- `ProgressStore.canCompletePathStep` opens the next step at 06:00 on the day after the last completion, not at midnight (section 2). The Deep focus legacy fields and `canCompletePathStepToday` follow the same rule; `ProgressStoreTests` cover 05:59 and 06:00 on the next day, a completion at 23:30, and a gap of several days.
- `ProgressStore` gains a same-day undo for a path step, refused for the last step of a run and for a run's legacy, undated steps (section 2). It reverses everything `completePathStep` did, following `setMoveCompleted(false)`: remove the step's `PathStepCompletion` and its `.path` practice activity; if the day is not a legacy day and no other activity remains on it, remove it from the completed days and recompute the streak, otherwise the day stays credited by the other activity; call `updateLegacyPathFields` so Deep focus's `pathCompletedDays` and `lastPathCompletionDay` fall back to the previous completion; persist and emit a path change so widgets and sync see the reversal. Tests cover an undo on a day with no other practice (the day and streak drop) and on a day with a move done (both stay).
- **Last completion date.** A path's last completion is its active run's `lastCompletionDate`. A Deep focus run carried over from before dated completions (`startedAt == nil`, empty `completions`, a `legacyCompletedSteps` count) has none; it falls back to `lastPathCompletionDay`, the same fallback `canCompletePathStep` already uses. With no date either way, the path ranks last in the hero's choice (section 4.1) and the 06:00 rule treats its next step as open.
- "Completed *n* times" counts finished runs per path; "last on" is the last completion date of the latest finished run under the same fallback, and is omitted when there is no date. No new storage.
- `startNewRun` is called only from Begin again on a finished path.
- No other target calls the completion rule. The Watch app's Today shows Deep focus's next step read-only from the legacy `pathCompletedDays` field, with "Day *n*" wording; the Watch is out of the redesign's scope, so the wording and the 06:00 opening on the Watch are left to the map's Watch question.

## 10. Absorbed bugs

From the UI bug inventory (`research/ui-bug-inventory.md` on branch `research/ui-bug-inventory`):

| Bug | Absorbed by |
| --- | --- |
| `PTH-1` three leading insets on one screen | `List` with system margins (design system section 4); no custom insets. |
| `PTH-2` empty toolbar reserve above the title | Design system 13.2 and 13.4; Paths has no toolbar items. |
| `PTH-3` icon-to-title gap larger than title-to-subtitle | Hand-built cards gone; rows use `Label` spacing, the hero stacks with `ThinkSpacing`. |
| `PDT-1` expanded day list drawn behind the tab bar | `List` inherits the tab-bar inset (13.2); no disclosure group. |
| `PDT-2` two CTAs with different widths, radii and weights | One `primary` and one `secondary`, both full width, stacked, same height (5.1). |
| `PDT-3` progress bar at a wider inset than the card | The top progress bar is gone; progress is the trail inside a section. |
| `PDT-4` ghosted glyphs under the navigation bar | Scroll-edge effect kept (13.2). |
| `PDT-5` lopsided wrapped Focus pill; status circle aligned only to the first line at AX3 | Full-width buttons (5.1); step rows align the symbol to the first baseline (5.3). |
| `PDT-6` "Day 2" overlapped by the tab bar at AX3 | 13.2. |
| Observation: "Day 2 of 21" against "1 of 21 days" | "Step *n* of *m*" everywhere (section 2). |

## 11. Acceptance floor

Section 11 of the design system applies. Specific to Paths:

- Dynamic Type through AX3: seen on the prototype, the hero's window and the card's caption hold, the trail yields to rows and the window to "*n* of *m* done" with a bar. The hero's lesson preview truncated at AX3 in the prototype and is hidden there by this brief (4.1).
- `bg` and `de`: the hero caption, "Complete step", "Opens tomorrow at 06:00" and the locked row at AX3; the path names in the inline title (truncation is expected; the first content row carries the full name).
- Every disc in the full trail has an accessibility label from its step, and the trail window is one element with the value "*n* of *m* steps done".
- Both appearances, dark the reference; in light the today disc uses the `accent` fill, never the ink, as on the day arc.
- Reduce Motion: completing a step cuts from the card to the done rows; no disc animation.

## 12. Open for the build

- The disc spacing in the full trail is computed from the row width. Check the 44pt tap targets on the narrowest supported iPhone and at the largest non-accessibility size, and shrink the disc before the gap if they collide.
- `plans/002-animate-path-day-completion.md` predates this brief; its animation applies to the card-to-done-rows change and the trail disc turning green, under `ThinkMotion` and Reduce Motion.
