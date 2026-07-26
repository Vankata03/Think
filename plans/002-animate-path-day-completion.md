# 002 — Animate path-day completion

- **Status**: DONE
- **Commit**: 3449690
- **Severity**: MEDIUM
- **Category**: Missed opportunity / state indication
- **Estimated scope**: 1 file, about 20 lines

## Problem

`Think/Views/PathDetailView.swift:33` swaps the current lesson section immediately after `completePathStep()` mutates progress. The progress count, current lesson, and “All days” icons all change in one unbridged frame.

```swift
if let step = currentStep {
    Section("Day \(step.id) — \(step.title)") {
        // lesson and completion button
    }
} else {
    Section {
        Label("Path completed. Begin again anytime.", systemImage: "checkmark.seal.fill")
    }
}
```

```swift
Button {
    guard progress.canCompletePathStepToday else { return }
    progress.completePathStep()
    haptics.play(.success)
}
```

## Target

Use the shared `ThinkMotion` vocabulary from plan 001. Read `@Environment(\.accessibilityReduceMotion)` and wrap only `progress.completePathStep()` in:

```swift
withAnimation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion)) {
    progress.completePathStep()
}
```

Apply `ThinkMotion.stateTransition(reduceMotion:)` to current/completed sections. For each “All days” icon, use `.contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))` so the completed day changes symbol as state feedback rather than decoration.

## Repo conventions to follow

- Continue using `haptics.play(.success)` after successful completion.
- Use the shared motion constants from `Think/Views/ViewStyle.swift`; do not define local curves.
- Preserve native `List` behavior and existing button styling.

## Steps

1. Add the Reduce Motion environment value to `PathDetailView`.
2. Wrap only the progress mutation in the shared 220 ms/200 ms animation.
3. Add state transitions to the current-step and path-completed sections.
4. Add the conditional symbol content transition to the “All days” icons.

## Boundaries

- Depends on plan 001 adding `ThinkMotion`.
- Do NOT change path completion eligibility or persistence.
- Do NOT animate the whole list on navigation or scrolling.
- Do NOT add confetti, bounce, stagger, or new haptics.
- If cited code has drifted from commit `3449690`, stop and report.

## Verification

- **Mechanical**: build the `Think` scheme for generic iOS Simulator with code signing disabled; expect `BUILD SUCCEEDED`.
- **Feel check**: complete one eligible path day. The current section should bridge to the next state in 220 ms; completed icon should replace once. Rapidly revisit the view; no replay on navigation.
- **Reduce Motion**: completion should use a 200 ms fade with no scale or symbol movement.
- **Done when**: completion remains immediate, animation never blocks interaction, and the final path-complete state behaves identically.
