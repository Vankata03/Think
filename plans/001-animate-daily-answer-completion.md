# 001 — Animate daily-answer completion

- **Status**: DONE
- **Commit**: 3449690
- **Severity**: MEDIUM
- **Category**: Missed opportunity / accessibility
- **Estimated scope**: 2 files, about 30 lines

## Problem

`Think/Views/TodayView.swift:246` replaces the answer editor with the completed state immediately after SwiftData publishes the inserted entry. The card pulses, but its meaningful content teleports.

```swift
// Think/Views/TodayView.swift:246 — current
if let entry = todaysEntry {
    answeredState(entry)
} else {
    answerEditor
}
```

`Think/Views/TodayView.swift:258` uses a spring only for the outer pulse and has no Reduce Motion branch:

```swift
.scaleEffect(savedPulse ? 1.015 : 1)
.animation(.spring(response: 0.28, dampingFraction: 0.8), value: savedPulse)
```

## Target

Add shared motion vocabulary in `Think/Views/ViewStyle.swift`:

```swift
enum ThinkMotion {
    static let enter = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.22)
    static let move = Animation.timingCurve(0.77, 0, 0.175, 1, duration: 0.22)
    static let reduced = Animation.easeOut(duration: 0.2)

    static func stateAnimation(reduceMotion: Bool) -> Animation {
        reduceMotion ? reduced : enter
    }

    static func stateTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.97).combined(with: .opacity)
    }
}
```

Read `@Environment(\.accessibilityReduceMotion)` in `TodayView`. Apply `ThinkMotion.stateTransition(reduceMotion:)` to both conditional branches and `ThinkMotion.stateAnimation(reduceMotion:)` keyed to `todaysEntry != nil`. Disable the existing pulse scale under Reduce Motion while retaining its opacity/content feedback.

## Repo conventions to follow

- Shared view styling already lives in `Think/Views/ViewStyle.swift`.
- `TodayView` already uses value-scoped animation at `Think/Views/TodayView.swift:259`.
- Preserve semantic haptics and all accessibility identifiers.

## Steps

1. Add `ThinkMotion` exactly as specified to `Think/Views/ViewStyle.swift`.
2. Add `@Environment(\.accessibilityReduceMotion) private var reduceMotion` to `TodayView`.
3. Apply the shared state transition to `answeredState(entry)` and `answerEditor`.
4. Add a value-scoped animation for `todaysEntry != nil`.
5. Change the existing pulse to `scaleEffect(reduceMotion ? 1 : (savedPulse ? 1.015 : 1))`; preserve its existing spring for non-reduced motion.

## Boundaries

- Do NOT alter persistence, haptics, strings, accessibility identifiers, or the answer-save sequence.
- Do NOT add dependencies.
- Do NOT animate typing or countdown-like content.
- If cited code has drifted from commit `3449690`, stop and report.

## Verification

- **Mechanical**: `xcodebuild build -project Think.xcodeproj -scheme Think -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`; expect `BUILD SUCCEEDED`.
- **Feel check**: save one daily answer. Editor should settle into the answered state in 220 ms without bounce or a blank frame. At 10% animation speed, entry begins at scale `0.97`, never zero.
- **Reduce Motion**: enable Reduce Motion, repeat. Content should fade for 200 ms with no scaling or pulse movement.
- **Done when**: both states bridge cleanly, save remains one tap, and VoiceOver identifiers remain unchanged.
