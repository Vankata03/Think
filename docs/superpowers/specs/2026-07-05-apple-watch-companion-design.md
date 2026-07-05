# Think Apple Watch Companion Design

## Goal

Create a companion-first Apple Watch app for Think that gives the user the daily practice and a local focus timer on the wrist while keeping the iPhone app as the product source of truth.

## Current State

Think is an iOS 26 SwiftUI app with Today, Paths, Focus, Profile, SwiftData journal entries, `UserDefaults`-backed progress, WidgetKit quote widgets, and ActivityKit Pomodoro Live Activities. There is no Watch target yet. The current focus timer is implemented in `Think/State/PomodoroTimer.swift`, and progress is stored in `Think/State/ProgressStore.swift`.

`xcodebuild` cannot currently run on this machine until the Xcode license is accepted with `sudo xcodebuild -license`.

## Product Scope

Watch v1 includes two surfaces:

- Today: daily quote, author, current streak, daily progress count, and next Deep Focus task summary.
- Focus: watch-local Pomodoro timer with 25/5 and 50/10 presets, start/pause, reset, skip, work and break phases.

Watch v1 excludes:

- Journal writing or viewing.
- Full path lesson reader.
- Phone timer mirroring.
- WatchConnectivity live sync.
- Watch complications.
- Paywall or Pro gating.

Phone-synced timer mirroring remains a later feature. It is tracked in the SecondBrain Think project page as an open question.

## Architecture

Add a Watch app target inside `Think.xcodeproj`. The Watch target should compile a small set of shared files used by both iOS and Watch:

- `ContentLibrary.swift`
- `ThinkingPath.swift`
- `ProgressStore.swift`
- `PomodoroTimer.swift`

Progress storage should use an App Group-backed `UserDefaults` suite named `group.com.ivanterziev.Think`. App Groups only share data between targets on the same device: on the iPhone that is the app, its widgets, and tests; on the Watch it is the Watch app and its complications. There is no cross-device sync in v1 — a session recorded on the Watch is visible to the Watch complication but not to the iPhone app. Phone-and-watch progress sync (WatchConnectivity or CloudKit) is explicitly later work. Tests continue to inject temporary `UserDefaults` suites so progress behavior stays deterministic.

The Watch app owns its timer instance locally. A completed Watch work session calls `ProgressStore.recordFocusSession()`, which updates the Watch-local shared progress. The iPhone focus timer and Watch focus timer do not try to stay in lockstep in v1.

## Watch UI

Use SwiftUI and watchOS-native navigation:

- Root: a two-page `TabView` with Today and Focus as the primary screens.
- Today screen: compact vertical layout optimized for quick glances. Quote text uses serif styling where available; stats use rounded monospaced digits; brand yellow stays limited to progress and primary actions.
- Focus screen: large remaining-time label, phase label, progress ring, primary Start/Pause control, secondary Reset/Skip controls, and preset picker.

Controls should be finger-friendly on small watches, with accessibility labels for timer actions and progress summaries.

## Data Flow

Today:

1. `ContentLibrary.dailyQuote()` supplies the daily quote.
2. `PathLibrary.deepFocus` and `ProgressStore.pathCompletedDays` determine the next task summary.
3. `ProgressStore.displayedStreak`, `focusSessionsToday`, and `completedPathStepToday` feed daily progress.

Focus:

1. Watch `FocusView` owns `@State private var timer = PomodoroTimer(systemSideEffectsEnabled: false)`.
2. Starting, pausing, skipping, and resetting only mutate local Watch timer state.
3. `onWorkSessionComplete` calls `progress.recordFocusSession()`.
4. Shared defaults make the completed session visible to other targets on the same device (the Watch complication); the iPhone app keeps its own progress until cross-device sync ships.

## Error Handling

If the App Group suite is unavailable, both apps fall back to `.standard` so the app still runs in debug builds. This fallback lives in a small helper so it can be tested and changed without touching call sites.

The Watch timer disables system side effects. It should not request notification authorization, start Live Activities, or schedule iPhone notifications.

## Testing

Use TDD for shared behavior:

- Add tests that verify the shared defaults helper returns an injected suite when provided and falls back safely when the configured suite cannot be opened.
- Extend `ProgressStoreTests` only if constructor or defaults behavior changes.
- Keep existing `PomodoroTimerTests` passing with `systemSideEffectsEnabled: false`.
- Add Watch UI smoke coverage only if Xcode project support makes it practical without brittle simulator setup.

Verification commands after Xcode license acceptance:

```bash
xcodebuild test -project Think.xcodeproj -scheme Think -testPlan Think -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' CODE_SIGNING_ALLOWED=NO
```

```bash
xcodebuild build -project Think.xcodeproj -scheme ThinkWatchApp -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest' CODE_SIGNING_ALLOWED=NO
```

## Release Notes

This feature should update `README.md` and `PLAN.md` after implementation to mention the Watch companion. The SecondBrain already records the deferred phone-synced Watch timer follow-up.
