# Think

Think is a SwiftUI iOS app for daily motivation, journaling, thinking paths, focus sessions, quote sharing, widgets, and Pomodoro Live Activities.

The product direction is captured in [PLAN.md](PLAN.md).

## Project Structure

- `Think/` - iOS app source, models, state, and SwiftUI views.
- `ThinkShared/` - model and state code shared by iOS, widgets, tests, and Watch.
- `ThinkWatch/` - watchOS companion app source.
- `ThinkWatchWidgets/` - watch face complication (WidgetKit) extension.
- `ThinkWidgets/` - WidgetKit and ActivityKit extension.
- `ThinkTests/` - app unit tests using Swift Testing.
- `ThinkWidgetsTests/` - widget extension unit tests using Swift Testing.
- `ThinkUITests/` - UI tests using XCTest.
- `Think.xctestplan` - shared test plan for app, widget, and UI tests.
- `docs/` - localization review status, content audit, hosted legal page sources, and implementation plans (`docs/superpowers/plans/`).
- `scripts/` - localization tooling (`validate_localizations.rb`, catalog sync/bootstrap) and App Store screenshot resizing (`resize_marketing.sh`).
- `Screenshots/` - seeded marketing screenshot sources for iPhone and Apple Watch.

## Requirements

- macOS with Xcode installed.
- iOS Simulator runtime compatible with the project target.

The app currently targets modern SwiftUI, WidgetKit, ActivityKit, and Swift Testing APIs.

## Build

Open `Think.xcodeproj` in Xcode and run the `Think` scheme.

Command line build:

```sh
xcodebuild build \
  -project Think.xcodeproj \
  -scheme Think \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Watch app build:

```sh
xcodebuild build \
  -project Think.xcodeproj \
  -scheme ThinkWatchApp \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'
```

## Test

Run the shared test plan from Xcode:

1. Select the `Think` scheme.
2. Select the `Think` test plan.
3. Press `Cmd+U`.

Command line test run:

```sh
xcodebuild test \
  -project Think.xcodeproj \
  -scheme Think \
  -testPlan Think \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Coverage is enabled in the shared test plan. In Xcode, open the Report navigator after a test run and select `Coverage` to inspect line coverage by target and file.

## Localization

The app ships seven locales (`en`, `bg`, `de`, `es`, `fr`, `it`, `pt-BR`) via native String Catalogs. Review status and policy live in [docs/localization-review.md](docs/localization-review.md). Before shipping, validate every catalog:

```sh
ruby scripts/validate_localizations.rb bg de es fr it pt-BR
```

## App Store

Release preparation is tracked in [docs/release-checklist-1.0.md](docs/release-checklist-1.0.md). One archive of the `Think` scheme contains the watch app and all widget extensions; there is a single App Store Connect record. Marketing screenshots resize to exact App Store slot sizes with:

```sh
scripts/resize_marketing.sh Screenshots/MarketingSeeded            # 1242x2688 (6.5")
scripts/resize_marketing.sh -s 410x502 Screenshots/WatchMarketing  # Apple Watch
```

Legal pages (privacy policy, support) are hosted at <https://thinkapp.tech/privacy.html> and <https://thinkapp.tech/support.html> (site repo: `Vankata03/think-site`); their markdown sources live in `docs/legal/`.

## Repository Notes

- Commit shared Xcode schemes and test plans.
- Do not commit `xcuserdata`, `DerivedData`, `.xcresult` bundles, provisioning files, certificates, or local environment files.
- Keep product decisions and roadmap changes in `PLAN.md`.

## Branching Model

This repository uses a small solo-developer release flow:

- `prod` - App Store production branch. This should match the latest shipped or approved build. Release tags live here, for example `v1.0.0`.
- `develop` - active integration branch. Feature work merges here after build and test checks pass.
- `release/<version>` - release stabilization branch, for example `release/1.0`. Use this for final fixes, version bumps, screenshots, signing, and App Store preparation.
- `feature/<short-name>` - normal feature work branched from `develop`.
- `fix/<short-name>` - non-emergency bug fixes branched from `develop`.
- `hotfix/<short-name>` - urgent production fixes branched from `prod`.

Normal flow:

```text
feature/foo -> develop -> release/1.0 -> prod -> tag v1.0.0
```

Hotfix flow:

```text
prod -> hotfix/crash-on-launch -> prod -> tag v1.0.1 -> develop
```

Branch protection should require build and test checks before merging into `develop`, `release/*`, or `prod`. `prod` should not receive direct pushes.
