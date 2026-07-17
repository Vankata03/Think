# 004 — Animate evening-retrospective appearance

- **Status**: DONE
- **Commit**: 3449690
- **Severity**: LOW
- **Category**: Missed opportunity / preventing a jarring change
- **Estimated scope**: 1 file, about 10 lines

## Problem

`Think/Views/TodayView.swift:55` inserts the evening retrospective when the minute timer crosses 20:00. The card appears immediately and pushes the training log down without a bridge.

```swift
if showsRetroCard {
    retroCard
}
```

## Target

Reuse the Reduce Motion environment value and shared `ThinkMotion` vocabulary from plan 001. Apply `ThinkMotion.stateTransition(reduceMotion:)` to `retroCard` and a value-scoped `ThinkMotion.stateAnimation(reduceMotion:)` keyed to `showsRetroCard`.

Normal motion: opacity plus `scale(0.97 → 1)` with `timingCurve(0.23, 1, 0.32, 1, duration: 0.22)`. Reduced Motion: opacity only with `easeOut(duration: 0.2)`.

## Repo conventions to follow

- Use the same transition as daily-answer completion; both are state cards on `TodayView`.
- Keep the one-minute timer and foreground refresh unchanged.

## Steps

1. Apply the shared state transition to `retroCard`.
2. Add value-scoped animation keyed only to `showsRetroCard` on the containing stack.
3. Confirm the animation does not replay when presenting/dismissing `RetroSheet`.

## Boundaries

- Depends on plan 001.
- Do NOT change the 20:00 eligibility rule, timer cadence, retrospective persistence, or sheet behavior.
- Do NOT stagger child content.
- If cited code has drifted from commit `3449690`, stop and report.

## Verification

- **Mechanical**: build the `Think` scheme for generic iOS Simulator with code signing disabled; expect `BUILD SUCCEEDED`.
- **Feel check**: simulate crossing 20:00 while Today is visible. Card settles in 220 ms; training log reflows once with no bounce.
- **Reduce Motion**: card fades for 200 ms without scaling.
- **Done when**: the card appears once at the same eligibility boundary and does not animate during unrelated minute updates.
