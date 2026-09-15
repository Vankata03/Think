# 008 — Give each focus session an intention and a closing note

- **Status**: DONE
- **Severity**: MEDIUM
- **Category**: Missed opportunity / product differentiation
- **Estimated scope**: 7–9 files, about 320 lines including tests and localized strings
- **Depends on**: —

## Problem

A focus session is anonymous. `Think/Views/FocusView.swift:198` starts the timer with no context:

```swift
Button {
    let isManualStart = !timer.isRunning
    let isManualWorkStart = isManualStart && timer.phase == .work
    ...
    timer.toggle()
```

Nothing records *what* the session was for, so the Live Activity shows a bare countdown, focus stats (`Think/Views/FocusStatsView.swift`) show counts without content, and the pomodoro loop stays disconnected from the journaling loop that is the app's actual identity ("Stoic gym for your mind", not a plain timer).

Every competing pomodoro app has a timer. Almost none tie the session to a written reflection.

## Target

### Before the session

Optional one-line intention, captured without adding friction:

- tapping Start with no intention set starts immediately, exactly as today — the intention must never become a required step;
- a compact field above the controls ("What are you working on?", single line, 60-character cap) sets it;
- the last intention is offered as a one-tap suggestion for the next session of the same day;
- the intention clears when a work phase completes and the follow-up note is saved or skipped.

### During the session

Show the intention in the Live Activity and Dynamic Island. `ThinkWidgets/PomodoroActivityAttributes.swift:19` gains `var intention: String?`, and because `ContentState` has hand-written `Codable` conformance the decoder must use `decodeIfPresent` (`ThinkWidgets/PomodoroActivityAttributes.swift:38`) so activities encoded by 1.1.1 still decode. Render it truncated to one line in the expanded Live Activity and in the Dynamic Island expanded bottom region only — the compact and minimal presentations stay as they are.

The intention stays phone-local: it is not added to the timer sync payload (`ThinkShared/Sync/SyncPayloads.swift`, `SyncCodec.swift`), so the watch timer and its codec version are untouched. Guard the storage with `#if os(iOS)` in `ThinkShared/State/PomodoroTimer.swift` where the Live Activity code already is.

### After the session

When a work phase completes with an intention set and the app is in the foreground, offer a single-line note:

- a sheet with the intention as the prompt and a "How did it go?" free-text field;
- Save writes a `JournalEntry` with `kind` = new constant `JournalEntry.kindFocus` = `"focus"`, `prompt` = the intention, `text` = the note;
- Skip dismisses and records nothing;
- if the phase completed in the background, no sheet is queued on next launch — a stale prompt hours later is worse than nothing.

`Think/Views/JournalView.swift:10` gains a fourth section, "Focus", filtered by the new kind; `Think/State/JournalExport.swift` includes focus notes in the export with the intention as their heading.

Saving a focus note does **not** call `progress.markTodayComplete()` — the completed session already credited the day through `ProgressStore.recordFocusSession` (`ThinkShared/State/ProgressStore.swift:373`). Double-crediting would inflate the practice rail.

## Verification

- Unit test: `ContentState` decodes 1.1.1-shaped JSON (no `intention` key) without throwing, and round-trips with an intention.
- Unit test: intention longer than 60 characters is rejected at the input boundary; whitespace-only is treated as absent.
- Unit test: the completion sheet is offered only for foreground work-phase completions with a non-empty intention.
- Unit test: saving a focus note inserts one `JournalEntry` of kind `focus` and does not mutate `ProgressStore`.
- Manual: start with an intention, confirm it appears in the Live Activity and the Dynamic Island expanded view; complete the phase and save a note; find it under Journal → Focus and in the export.
- Manual: start without an intention — no extra taps, no sheet at completion.

## Out of scope

- Watch-side intention entry.
- Intention history analytics or tags in focus stats.
- Editing an intention mid-session.
