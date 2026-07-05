# Premium UI UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign Think's visible tabs into a premium, calm daily practice experience while preserving existing app behavior.

**Architecture:** Add a small SwiftUI design layer with reusable colors, surfaces, metric tiles, and progress components. Refactor Today, Focus, Paths, and Profile to use those components while keeping existing models, state, navigation, and tests intact.

**Tech Stack:** SwiftUI, SwiftData, Observation, existing `ProgressStore`, existing `PomodoroTimer`, existing Xcode test plan.

---

## File Structure

- Create `Think/Views/ThinkDesign.swift`: shared visual tokens and reusable UI components.
- Modify `Think/Views/TodayView.swift`: daily ritual layout and answer-completion feedback.
- Modify `Think/Views/FocusView.swift`: focus chamber layout, ring glow, primary controls.
- Modify `Think/Views/PathsView.swift`: custom training atlas rows and progress.
- Modify `Think/Views/ProfileView.swift`: quiet dashboard/settings panels and bottom-safe scrolling.
- Modify UI tests only if labels change; preserve current labels where possible.

### Task 1: Shared Design Layer

**Files:**
- Create: `Think/Views/ThinkDesign.swift`

- [x] **Step 1: Create tokens and components**

Add `ThinkPalette`, `ThinkSurface`, `ThinkMetricTile`, `ThinkProgressRail`, and `ThinkSectionLabel`.

- [x] **Step 2: Verify build**

Run:

```bash
xcodebuild build -project Think.xcodeproj -scheme Think -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds.

### Task 2: Today Daily Ritual

**Files:**
- Modify: `Think/Views/TodayView.swift`

- [x] **Step 1: Replace grouped default background with custom ritual layout**

Use `ScrollView`, top ritual header, quote practice card, active question card, and training log row.

- [x] **Step 2: Preserve UI test labels**

Keep visible or accessibility text for:

```text
Question of the day
Share
Focus sessions today
Save answer
Answered
```

- [x] **Step 3: Verify targeted UI test**

Run:

```bash
xcodebuild test -project Think.xcodeproj -scheme Think -testPlan Think -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' -only-testing:ThinkUITests/ThinkUITests/testLaunchShowsTodayCoreLoop CODE_SIGNING_ALLOWED=NO
```

Expected: test passes.

### Task 3: Focus Chamber

**Files:**
- Modify: `Think/Views/FocusView.swift`

- [x] **Step 1: Refactor timer screen**

Keep timer state ownership local. Add layered ring, low-intensity running glow, focus cue, and clear primary action.

- [x] **Step 2: Preserve UI test labels**

Keep visible or accessibility text for:

```text
25:00
50:00
50 / 10
Focus
```

- [x] **Step 3: Verify targeted UI test**

Run:

```bash
xcodebuild test -project Think.xcodeproj -scheme Think -testPlan Think -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' -only-testing:ThinkUITests/ThinkUITests/testFocusPresetChangesTimerDuration CODE_SIGNING_ALLOWED=NO
```

Expected: test passes.

### Task 4: Paths and Profile

**Files:**
- Modify: `Think/Views/PathsView.swift`
- Modify: `Think/Views/ProfileView.swift`

- [x] **Step 1: Replace default List presentation**

Use custom scroll surfaces. Paths show Deep Focus progress and muted locked paths. Profile shows dashboard, journal, settings, and feedback panels.

- [x] **Step 2: Preserve UI test labels**

Keep visible or accessibility text for:

```text
Paths
Deep focus
Today's task
Profile
Progress
Journal
```

- [x] **Step 3: Verify targeted UI tests**

Run:

```bash
xcodebuild test -project Think.xcodeproj -scheme Think -testPlan Think -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' -only-testing:ThinkUITests/ThinkUITests/testTabsExposePrimarySections -only-testing:ThinkUITests/ThinkUITests/testDeepFocusPathOpensCurrentStep -only-testing:ThinkUITests/ThinkUITests/testCanCreateJournalNoteFromProfile CODE_SIGNING_ALLOWED=NO
```

Expected: tests pass.

### Task 5: Full Verification

**Files:**
- Test: `Think.xctestplan`

- [x] **Step 1: Run full local test plan**

Run:

```bash
xcodebuild test -project Think.xcodeproj -scheme Think -testPlan Think -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' CODE_SIGNING_ALLOWED=NO
```

Expected: app unit tests, UI tests, and widget tests pass.

- [x] **Step 2: Commit implementation**

Run:

```bash
git add Think/Views docs/superpowers/plans/2026-07-05-premium-ui-ux.md
git commit -m "feat: redesign app experience"
```
