# Think

Think is a SwiftUI iOS app for daily motivation, journaling, thinking paths, focus sessions, quote sharing, widgets, and Pomodoro Live Activities.

The product direction is captured in [PLAN.md](PLAN.md).

## Project Structure

- `Think/` - iOS app source, models, state, and SwiftUI views.
- `ThinkWidgets/` - WidgetKit and ActivityKit extension.
- `ThinkTests/` - app unit tests using Swift Testing.
- `ThinkWidgetsTests/` - widget extension unit tests using Swift Testing.
- `ThinkUITests/` - UI tests using XCTest.
- `Think.xctestplan` - shared test plan for app, widget, and UI tests.

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
