# 003 — Animate calendar month navigation

- **Status**: DONE
- **Commit**: 3449690
- **Severity**: LOW
- **Category**: Missed opportunity / spatial consistency
- **Estimated scope**: 1 file, about 35 lines

## Problem

`Think/Views/StreakCalendarSheet.swift:97` reconstructs the entire calendar card when `displayedMonth` changes. `shiftMonth(by:)` assigns the new date without a spatial bridge, so previous/next month navigation teleports.

```swift
private func shiftMonth(by value: Int) {
    if let shifted = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
        displayedMonth = shifted
    }
}
```

## Target

Read `@Environment(\.accessibilityReduceMotion)` and store the most recent direction:

```swift
@State private var monthShift = 0
```

Use a direction-aware asymmetric transition. Previous month enters from `.leading` and exits to `.trailing`; next month enters from `.trailing` and exits to `.leading`. Combine movement with opacity. Under Reduce Motion, use `.opacity` only.

```swift
private var monthTransition: AnyTransition {
    guard !reduceMotion else { return .opacity }
    let insertion: Edge = monthShift < 0 ? .leading : .trailing
    let removal: Edge = monthShift < 0 ? .trailing : .leading
    return .asymmetric(
        insertion: .move(edge: insertion).combined(with: .opacity),
        removal: .move(edge: removal).combined(with: .opacity)
    )
}
```

Key the month content by `grid.monthStart`, clip it inside the existing rounded card, and animate mutation with `ThinkMotion.move` (`timingCurve(0.77, 0, 0.175, 1, duration: 0.22)`) or `ThinkMotion.reduced` (`easeOut`, 200 ms).

## Repo conventions to follow

- Preserve `MonthGrid` and the existing card surface.
- Preserve selection haptics and current-month forward-button disabling.
- Use shared motion constants from plan 001.

## Steps

1. Add the Reduce Motion environment value and `monthShift` state.
2. Extract the current inner month UI into a small `calendarMonthContent(_:)` view builder if needed to attach one stable `.id(grid.monthStart)`.
3. Add `monthTransition` exactly as specified and clip moving content to the card bounds.
4. In `shiftMonth(by:)`, set `monthShift = value`, then assign `displayedMonth` inside `withAnimation(reduceMotion ? ThinkMotion.reduced : ThinkMotion.move)`.

## Boundaries

- Depends on plan 001 adding `ThinkMotion`.
- Do NOT animate individual day cells or the calendar on initial sheet presentation.
- Do NOT change date arithmetic, localization, or accessibility labels.
- Do NOT introduce hardcoded pixel translation distances.
- If cited code has drifted from commit `3449690`, stop and report.

## Verification

- **Mechanical**: build the `Think` scheme for generic iOS Simulator with code signing disabled; expect `BUILD SUCCEEDED`.
- **Feel check**: previous moves rightward while replacement enters from left; next does the inverse. At 10% speed, old/new content follows symmetric paths and stays clipped inside the card.
- **Interruptibility**: tap month buttons repeatedly; transitions retarget without jumping to an unrelated month.
- **Reduce Motion**: month content crossfades for 200 ms without horizontal movement.
- **Done when**: date results remain identical and the spatial direction always matches the pressed chevron.
