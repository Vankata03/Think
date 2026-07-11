# CI Pipeline Upgrade Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend CI from "build + test on PR" to a staged release pipeline: quality gates on every PR (Phase 1, pre-1.0), automated TestFlight delivery on release tags (Phase 2, post-1.0 launch), and automated localized screenshots + App Store metadata (Phase 3, before the first big update).

**Architecture:** Keep GitHub Actions (`.github/workflows/ci.yml`) as the fast PR gate. Add Xcode Cloud as the release lane — it owns signing and TestFlight distribution, so no certificates or API keys ever land in GitHub secrets. Add fastlane later only for the two things Xcode Cloud does not solve: per-locale screenshot generation (`snapshot`) and App Store metadata as reviewable files in the repo (`deliver`).

**Tech Stack:** GitHub Actions (macos-26), actions/cache, Xcode Cloud with `ci_scripts/`, fastlane (`snapshot`, `deliver`), App Store Connect API key (Phase 3 only), existing `scripts/validate_localizations.rb`.

**Why this split:** GitHub Actions signing is the classic pain point (keychain import, profile management, 10x minute multiplier on private macOS runners). Xcode Cloud signs automatically and has a free 25 compute-hours/month tier — plenty at solo release cadence. The repo ships 7 locales, so screenshot and metadata upkeep is the biggest recurring release cost; that is what fastlane is for.

---

## Phase 1 — PR quality gates (do now, pre-1.0)

### Task 1.1: Localization validation gate

**Files:**
- Modify: `.github/workflows/ci.yml`

**Steps:**
- [ ] Add a step after checkout, before "Build for testing":
  ```yaml
  - name: Validate localizations
    run: ruby scripts/validate_localizations.rb bg de es fr it pt-BR
  ```
- [ ] Verify it fails the job when a catalog entry is missing (test by temporarily deleting one translation locally: `ruby scripts/validate_localizations.rb bg` must exit non-zero).

**Acceptance:** A PR that adds a `String(localized:)` call without all six translations fails CI. This closes the gap that let the Pomodoro notification strings ship in English-only.

### Task 1.2: Test-result artifact on failure

**Files:**
- Modify: `.github/workflows/ci.yml`

**Steps:**
- [ ] Add after the Test step:
  ```yaml
  - name: Upload test results
    if: failure()
    uses: actions/upload-artifact@v6
    with:
      name: test-results
      path: TestResults/Think.xcresult
      retention-days: 14
  ```
- [ ] Confirm the xcresult bundle opens in Xcode from a downloaded artifact (UI-test failure screenshots live inside it).

**Acceptance:** A failed CI run offers the `.xcresult` for download next to the raw logs.

### Task 1.3: DerivedData cache (optional, skip if flaky)

**Files:**
- Modify: `.github/workflows/ci.yml`

**Steps:**
- [ ] Add before "Build for testing":
  ```yaml
  - name: Cache DerivedData
    uses: actions/cache@v4
    with:
      path: DerivedData
      key: deriveddata-${{ runner.os }}-${{ hashFiles('Think.xcodeproj/project.pbxproj') }}
      restore-keys: deriveddata-${{ runner.os }}-
  ```
- [ ] Compare timings across two runs. If incremental builds misbehave (stale module cache, phantom failures), delete the step — correctness beats minutes.

**Acceptance:** Second run with warm cache measurably faster, no new flakiness across at least three green runs.

---

## Phase 2 — Xcode Cloud release lane (after 1.0 ships manually)

Ship 1.0 by hand through Xcode Organizer first — one release does not justify blocking launch on pipeline work. Then:

### Task 2.1: Enable Xcode Cloud

**Steps:**
- [ ] Xcode → Product → Xcode Cloud → Create Workflow, select the `Think` scheme (watch app and extensions embed automatically; no separate workflows per target).
- [ ] Grant Xcode Cloud access to the GitHub repo when prompted.

### Task 2.2: Release workflow

**Steps:**
- [ ] Workflow "Release to TestFlight": start condition = tag matching `v*` (fallback: branch `release/**`).
- [ ] Action: Archive, platform iOS, scheme `Think`, deployment preparation "TestFlight (Internal Testing Only)" to start.
- [ ] Post-action: TestFlight internal group distribution.
- [ ] Signing: leave on automatic — this is the whole point of Xcode Cloud.

### Task 2.3: Guard rails inside Xcode Cloud

**Files:**
- Create: `ci_scripts/ci_post_clone.sh`

**Steps:**
- [ ] Run the localization validator inside the release lane too:
  ```sh
  #!/bin/sh
  set -e
  cd "$CI_PRIMARY_REPOSITORY_PATH"
  ruby scripts/validate_localizations.rb bg de es fr it pt-BR
  ```
- [ ] Make executable (`chmod +x`); Xcode Cloud picks up `ci_scripts/` by convention.

### Task 2.4: Build-number automation

**Steps:**
- [ ] Use Xcode Cloud's `CI_BUILD_NUMBER` as the build number so every archive is unique — set via `ci_scripts/ci_pre_xcodebuild.sh`:
  ```sh
  #!/bin/sh
  set -e
  cd "$CI_PRIMARY_REPOSITORY_PATH"
  agvtool new-version -all "$CI_BUILD_NUMBER"
  ```
- [ ] `MARKETING_VERSION` stays manual in the pbxproj (bump when cutting `release/<version>`); tag `vX.Y.Z` must match it — add a check to the post-clone script comparing tag to `MARKETING_VERSION` and failing on mismatch.

**Acceptance (Phase 2):** `git tag v1.0.1 && git push --tags` produces a TestFlight build with no Mac interaction. Signing certificates never touch GitHub.

---

## Phase 3 — fastlane screenshots + metadata (before first feature update)

### Task 3.1: fastlane snapshot

**Files:**
- Create: `fastlane/Snapfile`, `fastlane/SnapshotHelper.swift`
- Modify: `ThinkUITests/` (add a screenshot-driving UI test)

**Steps:**
- [ ] `fastlane snapshot init`; add `SnapshotHelper.swift` to the UI test target.
- [ ] Write one UI test that walks Today → Paths → Focus (running) → Share card → Profile calling `snapshot("01-today")` etc. — the accessibility identifiers from PR #7 already make screens addressable, and the `-ui-testing` launch argument gives deterministic seeded state.
- [ ] Snapfile: `languages` = the 7 locales, `devices` = one 6.9" and one 6.5" iPhone; output to `fastlane/screenshots/` (already gitignored).
- [ ] Post-process marketing framing if wanted; raw App Store slots can also use `scripts/resize_marketing.sh` on the output.

**Acceptance:** One command regenerates every locale × device screenshot set from seeded UI state.

### Task 3.2: fastlane deliver (metadata as code)

**Files:**
- Create: `fastlane/Deliverfile`, `fastlane/metadata/<locale>/…` (description, keywords, release notes per locale)

**Steps:**
- [ ] `fastlane deliver init` against the live App Store listing to pull current metadata into the repo.
- [ ] Store an App Store Connect API key (`.p8`) locally / in CI secrets — needed only for this lane, not for signing.
- [ ] Release-notes flow: editing `fastlane/metadata/*/release_notes.txt` becomes part of the release PR, reviewable like code.

**Acceptance:** `fastlane deliver --skip-binary-upload` pushes metadata + screenshots for all 7 locales without touching the App Store Connect web UI.

---

## Explicitly not doing

- **GitHub Actions archive/signing lane (Route B):** redundant once Xcode Cloud owns releases; revisit only if Xcode Cloud's free tier stops sufficing.
- **Nightly builds:** no consumer for them at solo cadence.
- **fastlane pilot:** Xcode Cloud already delivers to TestFlight.
