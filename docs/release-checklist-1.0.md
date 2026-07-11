# App Store 1.0 Release Checklist

State as of 2026-07-11, from the full pre-launch review. Update checkboxes as items land.

## Submission model (settled)

- One archive of the `Think` scheme contains everything: the watch app (`Embed Watch Content`), the iOS widget/Live Activity extension, and the watch complication extension (`Embed Foundation Extensions`). The watch app declares `WKCompanionAppBundleIdentifier`, so it is a companion app and cannot ship separately.
- One App Store Connect record for `com.ivanterziev.Think`. The watch app only adds its own screenshot slots on the version page.
- The app is iPhone-only (`TARGETED_DEVICE_FAMILY = 1`, PR #8): no iPad screenshots or iPad layout review; iPad users get compatibility mode.

## Done

- [x] Privacy manifests (`PrivacyInfo.xcprivacy`) in all four targets.
- [x] `ITSAppUsesNonExemptEncryption = NO` — no export-compliance questionnaire per build.
- [x] `NSPhotoLibraryAddUsageDescription` set; photo access is add-only (`PHPhotoLibrary .addOnly`).
- [x] App icon with light, dark, and tinted variants.
- [x] App category: `public.app-category.lifestyle`.
- [x] Seven locales localized and validated (`ruby scripts/validate_localizations.rb bg de es fr it pt-BR`).
- [x] Pomodoro phase-end notifications localized (PR #8; previously hardcoded English).
- [x] iPhone-only device family (PR #8).
- [x] Legal pages hosted: <https://vankata03.github.io/think-legal/privacy-policy.html> and `support.html`.
- [x] Screenshot resize tooling: `scripts/resize_marketing.sh` (default 1242×2688; `-s WxH` for other slots).
- [x] CI builds and tests every PR (`.github/workflows/ci.yml`).

## Blocking decisions

- [ ] **Free vs. paywall.** StoreKit 2 paywall is unbuilt. Either ship 1.0 fully free (no code change; strip Pro mentions from metadata) or build the paywall first. PLAN.md monetization table currently promises Pro/Lifetime tiers.

## Before archiving

- [ ] Recut `release/1.0` from `develop` — the existing branch is stale at "Initial Commit".
- [ ] Merge PR #8 (`fix/ipad-family-and-notification-l10n`).
- [ ] Native-speaker sign-off on the four new notification strings (machine-drafted; see docs/localization-review.md, Post-review additions).
- [ ] Decide on the working-tree `Screenshots/Marketing/` deletion (currently uncommitted) and gitignore `.codex/`.
- [ ] Verify `MARKETING_VERSION = 1.0` and bump `CURRENT_PROJECT_VERSION` per upload.

## App Store Connect setup

- [ ] Create the app record (bundle ID `com.ivanterziev.Think`).
- [ ] Privacy Policy URL: `https://vankata03.github.io/think-legal/privacy-policy.html`.
- [ ] Support URL: `https://vankata03.github.io/think-legal/support.html`.
- [ ] Privacy Nutrition Label: **Data Not Collected** (matches the policy — no accounts, analytics, tracking, or network requests).
- [ ] iPhone screenshots: 6.9" slot (1290×2796 or 1320×2868) is primary in current ASC; 6.5" (1242×2688) also accepted. Generate with `scripts/resize_marketing.sh -s <WxH> <dir>`.
- [ ] Apple Watch screenshots: 410×502, from `Screenshots/WatchMarketing` via `scripts/resize_marketing.sh -s 410x502`.
- [ ] Localized metadata (name, subtitle, description, keywords) for all seven locales — all locales are release-ready per docs/localization-review.md.
- [ ] Age rating questionnaire, pricing (free at launch), availability.

## Known issues (accepted for 1.0 unless re-decided)

- **Focus-session credit edge case.** The Pomodoro timer is `@State` in `FocusView` and `onWorkSessionComplete` is wired in `.onAppear`. If a work phase completes while the app is terminated and the Focus tab is never opened, the session is not recorded; opening the tab a day later records it against the wrong day (can extend the streak incorrectly). Fix direction: own the timer at app level or persist a completion marker with its date.
- **Watch timer state is not persisted.** `WatchFocusView` creates `PomodoroTimer(systemSideEffectsEnabled: false)` with nil defaults; watchOS process termination silently drops a running session. Fix is a one-line `defaults:` parameter.
- **No release automation.** 1.0 ships manually through Xcode Organizer by decision. The staged pipeline (GitHub Actions gates → Xcode Cloud TestFlight → fastlane screenshots/metadata) is planned in `docs/superpowers/plans/2026-07-11-ci-pipeline-upgrade.md`.

## After approval

- [ ] Merge `release/1.0` → `prod`, tag `v1.0.0`.
- [ ] Start the CI pipeline upgrade plan (Phase 1 gates can land any time; Phase 2 after launch).
