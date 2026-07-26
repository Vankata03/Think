# 005 — Present and share every achievement

- **Status**: DONE
- **Commit**: 3449690
- **Severity**: MEDIUM
- **Category**: Missed opportunity / feedback / accessibility
- **Estimated scope**: 8–10 files, about 350 lines including tests and localized strings

## Problem

Achievement state changes silently. `ThinkShared/State/ProgressStore.swift:317` can answer whether an achievement is earned, but exposes no ordered catalog snapshot for detecting newly earned achievements:

```swift
func hasEarned(_ achievement: ProgressAchievement) -> Bool {
    switch achievement {
    case .streak(let milestone):
        hasEarned(milestone)
    case .path:
        completedPathCount >= achievement.target
    case .focus:
        totalFocusSessions >= achievement.target
    }
}
```

`Think/Views/StreakAchievementsSheet.swift:50` makes only earned streak milestones tappable. Earned path and focus achievements fall through to a static badge, so they cannot be shared from the Achievements menu:

```swift
if isEarned, case .streak(let milestone) = achievement {
    Button {
        haptics.play(.selection)
        selectedMilestone = milestone
    } label: {
        badge(for: achievement, isEarned: true)
    }
} else {
    badge(for: achievement, isEarned: isEarned)
}
```

`Think/ThinkApp.swift:27` observes only the seven-day milestone and schedules the StoreKit review prompt after a fixed two seconds. There is no visible unlock feedback, and adding one without coordination would let the review prompt cover it.

## Target

### Unlock presentation

Add an app-level achievement unlock modifier that compares ordered earned-achievement snapshots with `onChange`. It must:

- ignore achievements already earned when the app launches;
- queue multiple achievements in `ProgressAchievement.all` order;
- show one compact card at a time;
- play the existing success haptic once per presented card;
- auto-dismiss after 4 seconds when VoiceOver is off;
- remain until explicitly dismissed when VoiceOver is on;
- request the seven-day App Store review only after its unlock card has dismissed;
- stay disabled during UI tests.

Normal transition: opacity plus `scale(0.97 → 1)` using existing `ThinkMotion.enter`, exactly `Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.22)`. Reduced Motion: opacity only with existing `ThinkMotion.reduced`, exactly `Animation.easeOut(duration: 0.2)`.

The card contains the earned achievement icon, localized achievement label, “Achievement unlocked,” and an explicit close button. No confetti, bounce, particle effects, or full-screen interruption.

### Sharing

Make every earned achievement badge a button with a visible share affordance and accessibility hint. Selecting it presents:

- existing `StreakShareSheet(month: .now, milestone:)` for streak achievements;
- new `AchievementShareSheet(achievement:)` for path/focus achievements.

The new sheet renders a fixed 1080×1920 `AchievementCardView` using existing `CardStyle` options and the established `ImageRenderer`, `ShareLink`, save-to-Photos permission, denied-state recovery, and haptic patterns from `StreakShareSheet`.

The achievement card must use existing localized category strings and display:

- large target number;
- category (`Streak`, `Paths`, or `Focus sessions`);
- `Earned`;
- the existing THINK wordmark treatment.

Add complete `en`, `bg`, `de`, `es`, `fr`, `it`, and `pt-BR` translations for the new “Achievement unlocked” string. Reuse existing strings for buttons, categories, and sheet title where possible.

## Repo conventions to follow

- New Swift files under `Think/Views` join the iOS target through the synchronized root group; do not edit `project.pbxproj` unless the build proves otherwise.
- Fixed share-card design size is `QuoteCardView.designSize` (`1080×1920`).
- `StreakShareSheet.swift` is the implementation exemplar for card preview, style selection, rendering cache, ShareLink, Photos authorization, Open Settings recovery, and haptics.
- Shared motion values already live in `Think/Views/ViewStyle.swift` as `ThinkMotion`.
- Achievement ordering is streak `[7, 21, 100]`, path `[1]`, focus `[1, 10, 50, 100]`.

## Steps

1. In `ThinkShared/State/ProgressStore.swift`, add `ProgressAchievement.all` by concatenating the three existing catalogs and add `ProgressStore.earnedAchievements: Set<ProgressAchievement>` derived from that catalog and `hasEarned`.
2. Add a UI presentation extension for `ProgressAchievement` under `Think/Views` that provides localized category, label, icon, and concise share message without moving UI/localization concerns into `ThinkShared`.
3. Add `AchievementCardView.swift`, fixed at `QuoteCardView.designSize`, using target, category, `Earned`, icon, style colors, and THINK wordmark.
4. Add `AchievementShareSheet.swift`, following `StreakShareSheet` behavior for preview, style picker, cached ImageRenderer result, ShareLink, Save/Open Settings, and haptics. Accept only `.path` and `.focus`; use an assertion/fallback if passed a streak achievement.
5. Change `StreakAchievementsSheet` state from `selectedMilestone` to `selectedAchievement`. Make every earned cell a Button; locked cells stay static. Add a visible `square.and.arrow.up` affordance to earned badges. Switch sheet destination by achievement type, preserving the existing streak sheet.
6. Add `AchievementUnlockModifier` and compact `AchievementUnlockCard`. Implement a pure `AchievementUnlockPolicy.newlyEarned(previous:current:)` that returns catalog-ordered new achievements for unit testing.
7. Replace `SevenDayReviewPromptModifier` in `ThinkApp` with the achievement unlock modifier. Keep `SevenDayReviewPromptPolicy` and its storage key, but invoke it only after the seven-day card dismisses. Do not allow the review prompt and unlock card to overlap.
8. Add focused tests covering the ordered catalog, `earnedAchievements`, newly-earned diff ordering, no replay when sets are equal, and existing review-prompt policy.
9. Add all locales for “Achievement unlocked” to `Think/Localizable.xcstrings`. Run the repo’s localization validator if available; otherwise validate the catalog as JSON and report the script absence.

## Boundaries

- Do NOT modify or discard unrelated changes in the dirty main checkout; work only in `/Users/vankata/Documents/Codex/2026-07-17/pull-latest-development-changes-then-i`.
- Do NOT change achievement thresholds, persistence semantics, streak history migration, or sync payloads.
- Do NOT replay historical unlock cards on launch or migration.
- Do NOT add confetti, sound, bounce, new dependencies, or a full-screen celebration.
- Do NOT replace or regress existing streak/calendar sharing.
- Do NOT present the StoreKit review prompt before the seven-day unlock card finishes.
- If cited code has drifted materially from commit `3449690`, stop and report rather than improvising.

## Verification

- **Mechanical**: `git diff --check` passes.
- **Build**: `xcodebuild build -project Think.xcodeproj -scheme Think -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` ends with `BUILD SUCCEEDED`.
- **Tests**: run focused `ThinkTests` for achievement catalog/state/unlock policy; all pass.
- **Localization**: catalog parses as JSON and contains the new key in all seven locales; run the localization validator if present.
- **Feel check**: earn one focus, path, and streak achievement. Each card enters once in 220 ms from scale `0.97` plus opacity, never scale zero; queued achievements appear serially; existing achievements do not replay on relaunch.
- **Reduce Motion**: unlock card uses a 200 ms opacity-only transition.
- **VoiceOver**: card does not auto-dismiss; close control is reachable and labeled; announcement includes the achievement label.
- **Sharing**: every earned gallery badge opens a share sheet. Streak uses existing card. Path/focus render non-empty 1080×1920 images and both Share and Save work; locked badges remain non-interactive.
- **Review prompt**: seven-day review request occurs only after the unlock card dismisses and never during UI tests.
- **Done when**: all achievement types have visible unlock feedback and are shareable from the menu without regressions to current streak sharing.
