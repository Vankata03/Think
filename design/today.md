# Today

Resolves [Today: above the fold and glance readability](https://github.com/Vankata03/Think/issues/73), part of the [Think UI redesign map](https://github.com/Vankata03/Think/issues/68). Decided with the owner on 2026-09-16 after seven canvas rounds (twenty variants, [canvas](https://claude.ai/artifact/SfeaxohE2wChH4YbCr7iWX)) and a SwiftUI prototype run on the Simulator in both appearances and at AX3 (branch `prototype/today-sun-arc`, `Think/Views/TodayPrototypeView.swift`).

This brief inherits [design-system.md](design-system.md): tokens (section 2), type roles (3), spacing (4), states (8) and the chrome baseline (13). It states only what Today decides.

## 1. What Today is

Today walks the person through the **ritual**: the three acts of a practice, in order: answer the question, do the move, write the retro. The screen shows the day as time, the daily line, and one act at a time. Everything else the old screen carried (date header, carried intention as a header, activity log with six kinds, stats tiles, Journal shortcut, Find a practice) is gone; the IA decision and the glossary (`CONTEXT.md`: Ritual, Day rail) name what replaces it.

## 2. Structure

`NavigationStack` with a `List` (section 13.1). Large title "Today". Trailing toolbar: Saved lines bookmark, fixed spacer, streak (section 13.3). No leading item.

| Row | Content | Background |
| --- | --- | --- |
| Day arc | The day as a half circle, 06:00 to 22:00 (section 3 below). | clear |
| Daily line | The line in `line` role (`.title`, serif), then a row with the attribution as plain text on the left and two icon-only buttons on the right: save (`bookmark` / `bookmark.fill`) and share. No link anywhere on the line. | clear |
| Next act | One panel (`surface` section) for the act that is next: caption `Next · <act>` in `accentInk` with the act's symbol, the text (question in `line`-style serif at `.title3`; move and retro in `body`), and the screen's one `primary` button: "Write answer", "Done", "Begin retro". When every act is done the panel becomes one row: green check, "Practice complete", "Day *n* of your streak." | `surface` |
| Acts done or later | One section, one row per remaining act in ritual order. Done: green `checkmark.circle.fill`, "Question answered" / "Move done" / "Retro written". Later: the act's symbol in `secondaryLabel`, "Today's move · after the question" / "Evening retro · 20:00". | `surface` |

The retro act appears at 20:00 (owner, Q6 (b)); before that it exists only as the dashed marker on the arc and the later row. Nothing else appears or disappears during the day; the panel's content rotates.

Fold on a 6.1-inch phone at the default size: arc, line, next-act panel with its button. That is the glance: where the day is, what the line says, what to do now.

## 3. Day arc

The one graphic on the screen. A half circle whose diameter is the content width minus 60pt, capped at a 132pt radius; the height of the row is the radius plus 78pt.

- Track: `separator`, 3pt, round caps. Elapsed: `accent`, same stroke, from 06:00 to now. Before 06:00 the elapsed arc is empty; after 22:00 it is full.
- Sun: 18pt `accent` disc with a 30pt `accent` at 25% halo, at the current hour. Drawn under the markers.
- Markers at 08:00 (question), 14:00 (move) and 19:00 (retro): 28pt discs. Done: `success` fill, black check. Next: `accent` fill, the act's symbol in `accentOnFill`. Later: `background` fill, 1.5pt dashed `secondaryLabel` ring, symbol in `secondaryLabel`.
- Captions: `caption2` semibold, in the marker's colour (`success`, `accentInk`, `secondaryLabel`), outside the curve: above and 16pt left of the question marker, above the move marker, above and 16pt right of the retro marker. Captions never cross the arc.
- Centre: "<Weekday> · *n* of 3" in `footnote` semibold `secondaryLabel`, and the time in `numeral` (`.title` rounded bold, monospaced digits). "06:00" and "22:00" in `caption2` under the arc ends, in the device's clock format.
- Motion: the elapsed arc and the sun move along the curve (the animatable value is the hour fraction, never the point), 0.8s ease-in-out on an hour change; a marker's state change uses `ThinkMotion.stateAnimation`. Reduce Motion: no animation.
- Accessibility: the arc is one element, label "Your day. *n* of 3 done. Now <time>." At accessibility sizes (`dynamicTypeSize.isAccessibilitySize`) the arc is replaced by "*n* of 3" in `numeral` over a `ProgressView(value:)` bar tinted `accent`, per section 13.7; the time is dropped there because "10:57 PM" wraps at AX3.
- Swift: `DayArcView(hour:states:)` in `ThinkShared/Design`, so widgets can reuse it later; the `ArcPosition` modifier from the prototype is the reference for the sun's motion.

## 4. Behaviour

- **One answer a day.** "Write answer" opens the editor for a new answer; once one exists, the done row opens a read-only detail (question in serif, the answer, "Written <time>", Edit in the trailing slot) and Edit opens the same editor on that record. The newest edit is the answer. There is no version list on Today or in its detail; how iCloud conflicts collapse to one record is the Journal brief's decision, under the assumption "latest edit wins".
- **Move.** "Done" marks the move and moves the panel on. The done row is static: no chevron, no tap. A trailing swipe reveals "Undo" for a mistaken tap; the reversal stays possible without being advertised.
- **Retro.** "Begin retro" opens the retro sheet; the done row opens the retro detail (three prompts, three answers, time, Edit).
- **Locked journal.** Writing needs no unlock. Opening an answer or retro asks Face ID first; the row text never shows journal content.
- **Saved lines.** Pushed from the toolbar bookmark, inline title. A `List` of lines in `line` role with the attribution in `caption`; swipe to remove, long-press for Share and Remove. Empty state per section 8 ("Lines you keep appear here.", no button: back is the action). A row opens nothing.
- **No practice door.** The line, the Saved lines rows and the answer detail have no link to a practice screen. Practice detail leaves the app (map: out of scope).

## 5. Removed views

The build that ships this brief deletes what it replaces; nothing stays behind a flag:

- `Think/Views/TodayView.swift` (replaced whole), including the activity log, stats tiles, `ritualHeader`, the toolbar Journal button and the circular streak badge.
- `Think/Views/PracticeDetailView.swift` and every `NavigationLink` to it (`FavoritesView`, `JournalDetailView` "View this practice", `TodayView`).
- `Think/Views/FavoritesView.swift`, replaced by the Saved lines list above; the `heart` symbol goes with it (section 7: `bookmark`).
- `Think/Views/TodayPrototypeView.swift` never merges; it stays on `prototype/today-sun-arc`.

## 6. Absorbed bugs

From `research/ui-bug-inventory.md` (branch `research/ui-bug-inventory`):

| ID | Fix |
| --- | --- |
| `TOD-1` | `List` root inherits the tab-bar inset; no content sits under the bar at rest. |
| `TOD-2` | No `.toolbarBackground(.hidden)`; the scroll-edge effect stays. |
| `TOD-3` | Same as `TOD-1` at AX3; the panel's button is a list row. |
| `TOD-4` | Save and share are `Button(title, systemImage:)` on `.body`, so they scale with type. |
| Observation "three names for Profile" | Not Today's; the streak toolbar item is the only chrome Today adds. |
| Observation "empty states: grey sentence in a pill" | Saved lines uses `ContentUnavailableView` per section 8. |
| Observation "date header duplicates the device" | Date header removed; the weekday sits in the arc's centre. |

## 7. Acceptance floor

Section 11 applies. Specific to Today:

- Dynamic Type through AX3: the arc yields to the linear form; the line, the question and the move never truncate; the panel's button wraps onto its own line at AX sizes.
- `bg` and `de`: arc captions ("Въпрос / Ход / Ретро", "Frage / Bewegung / Rückblick") measured under the arc at the default size; the row texts ("Today's move · after the question") checked at AX3.
- Every icon-only control has a title: bookmark, share, streak.
- Both appearances: dark is the reference; light uses the `accent` fill (`#F2C41C`) on the arc, never the ink.
- Reduce Motion: the sun and the arc do not animate; state changes cut.
- Time in the arc uses the device clock format (12h in en_US, 24h in `bg` and `de`).

## 8. Open for the build

- The sun overlaps a marker when the hour is within about 20 minutes of it (seen at 08:30 against the question at 08:00). Either shift the question marker to 07:30, or hide the sun's halo within 20pt of a marker. Decide in the build ticket after both are tried.
- `line` role on Today is `.title`, not `.largeTitle` as section 3.1 said; the doc is updated. `.largeTitle` plus the arc pushed the panel below the fold on device.
