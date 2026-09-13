# 012 — Audit integration

Status: IMPLEMENTED and committed locally; external/runtime qualification gates remain (2026-09-14).

## Implemented foundations

- Fail-closed journal authentication, authenticated disable/export, background privacy shield.
- Explicit repository saves/rollback, stable record identity, civil-day context, protected atomic drafts, conflict variants retained.
- Reset boundary across progress/timer/Watch events, private draft/session deletion and Health queue cancellation.
- Meaningful practice activities, independent repeatable path runs, stable focus session IDs and partial effort.
- Private session reflection, weekly review, discovery preferences and practice provenance screens.
- Versioned editorial content and immutable historical schedule; new rotation begins October 1, 2026 local civil day. Clear thinking has seven steps.
- On-demand export, journal page retention bounds and notification reconciliation/cache; performance claims require measurements below.

## Remaining integration and verification

- [x] Connect Today, Journal and retrospective UI to repository/draft/gate APIs; save failures retain writing and captured civil-day context. Independent review findings were corrected.
- [x] Complete new text localization across all six additional languages: 1,500 units, complete sentences, printf checks and sample review; new translations remain `needs_review`.
- [x] Run full app/widget/UI suites and supported simulator visual checks. VoiceOver speech and Reduce Motion runtime remain explicit qualification gates.
- [x] Record synthetic 1k/10k journal measurements and isolated notification preparation measurements, distinguishing them from device performance.
- [x] Independent Opus 5 adversarial review; ten findings corrected. Fifteen focused persistence tests and the real focus-note edit/no-ghost UI regression pass. Full integration rerun passed.
- [x] Reconcile this plan with final evidence and exact pending gates.

## Evidence

Integrated `journal-integration-2`: 252 app tests and 15 widget tests passed. UI failures exposed a draft-failure fixture cleanup bug, an automatic-authentication test assumption, and SwiftUI identifier propagation. Corrected tests passed in focused reruns (`lock-ui-fresh-runner`, `lock-ui-accessibility-fix`). This intermediate batch was superseded by the passing final suite below. Small iPhone SE light-mode navigation captured twelve screens successfully (`visual-se-light`); subsequent visual checks covered dark mode, maximum text and actual German rendering. Local detailed matrix/handoffs are in ignored `docs/reviews/`; this tracked plan preserves delivery boundaries.

## Query measurement (2026-09-12)

Synthetic on-disk SQLite stores, isolated simulator test, four samples with alternating operation order. Warm/cold samples are combined; these are repository operation timings, not navigation/FPS, physical-device or memory measurements.

| Rows | Legacy fetch-all day lookup | Repository day lookup | Legacy fetch-all first page | Bounded first page |
|---|---:|---:|---:|---:|
| 1,000 | 14.952 ms | 1.348 ms | 14.962 ms | 1.100 ms |
| 10,000 | 146.244 ms | 1.390 ms | 144.988 ms | 2.077 ms |

The initial chunk-scanning first page measured 514.940 ms at 10k rows; measurement motivated an unfiltered fast path using fetchCount plus a limited fetch. Search/filtered pages still scan chunks to preserve localized matching semantics and total counts; no filtered-search speedup claimed. Seven measurement/repository tests passed in `journal-measurement-3.*`. Notification reconciliation is regression-tested for avoided rendering/addition work. Isolated `notification-isolated` passed: four unique synthetic quote requests averaged 12.686 ms uncached and 0.808 ms cached for attachment request preparation. This includes request preparation, not OS scheduling latency or device performance. The earlier concurrent full-suite timing is discarded as contaminated.

## Explicit deferrals and external gates

Square/4:5 sharing formats and advanced import/restore/soft deletion are deferred to avoid expanding the persistence/release boundary. Distraction counts and speculative favorite lookup optimization are deferred. No claimed device speedup, battery improvement, or production CloudKit qualification. Production schema deployment, two-device offline conflicts/account states, paired Watch and HealthKit verification require external/device checks. No push, merge, production deployment or release submission authorized.

## Workflow

Implementation used one worker at a time with bounded context after the user requested lower usage. Native Codex was explicitly authorized after Claude limits; later journal, review and translation packages used actual Claude Code Opus 5, medium effort. Integration and serial builds remained centrally owned. A separately authorized SecondBrain checkpoint was committed as `c39a0ec`; it describes the pre-commit Think snapshot.

## Localization acceptance (2026-09-13)

The first generated batch of 1,470 translation units was rejected after sentence-level inspection found mixed English and target-language fragments. Only that batch was removed; existing translations remain. Six complete replacement batches plus final warning/action labels were subsequently integrated: 1,500 additional translation units, with coverage/placeholder checks and sentence-level samples. They remain `needs_review`; human approval is not claimed.

## Adversarial corrections and visual findings (2026-09-13)

Same-ID recovered saves now update writing without duplicate rows or changing historical context. Focus recovery retains intention/outcome/energy and the existing closing-note identity; untouched session visits do not create drafts. Clearing a saved closing note removes it. Weekly intention edits persist, weekly reviews do not count themselves as notes/moods, and captured timezones survive recovery. One unreadable draft no longer hides healthy drafts; warnings preserve unreadable files. Cleared drafts are removed and empty retros rejected.

Simulator inspection found and corrected a truncated journal filter, narrow retrospective buttons, stacked-letter Focus controls and compressed journal metadata at maximum text size. Light iPhone SE, dark iPhone 17 Pro, and maximum accessibility text were exercised with retained screenshots. The first German test-plan override still launched English and is explicitly not German evidence; a dedicated launch-argument test replaces it. `focus-reflection-ui-fixed` passes after correcting the test's cursor-position assumption. `final-integration-2` subsequently passed all 259 app, 15 widget and 40 UI tests.

Reduce Motion code paths are inspected; the simulator Settings switch remained off after click/drag attempts, so runtime confirmation is pending. Simulator accessibility trees and navigation were inspected, but spoken VoiceOver traversal is unverified; the simulator Settings Vision section exposed no VoiceOver option. These require accessible runtime/device follow-up, not a release-complete claim.

## Final integration evidence (2026-09-14)

`final-integration-2.xcresult` completed September 13: **259 app tests (37 suites), 15 widget tests (4 suites), 40 UI tests, zero failures**. Xcode 27 beta, iOS 26.5 iPhone 17 Pro simulator, signing disabled. Actual German text confirmed in retained screenshots after explicit app launch-language arguments. Maximum accessibility text on iPhone SE passed after layout fixes. This is simulator/build coverage, not physical-device or production evidence.

A final Profile-only polish wraps long setting labels and disables its custom switch spring when Reduce Motion is requested. The focused German iPhone SE rerun passed in `german-final.*`. Inspection then found a missing manually extracted Delete all data label; all six additional translations were added and `german-final-label.*` passed; retained screenshot confirms Alle Daten löschen. Full-suite evidence predates only this small UI/catalog polish. Catalog formatting was restored to existing conventions after semantic validation.

Remaining gates: human translation review; actual VoiceOver traversal and Reduce Motion behaviour; app-switcher/data-protection timing on a physical device; CloudKit production schema plus two-device offline conflict/account/sign-out checks; paired Watch and HealthKit behaviour; Release/device profiling. No remote analytics added. Stable IDs, historical content versions and legacy path migration have local regression coverage; production migration/sync is not certified.

Branch `codex/think-audit-improvements`: implementation committed locally on 2026-09-14 in cohesive batches:

- `37beeb6` — versioned daily practices, expanded paths and content regressions.
- `a356473` — notification reconciliation/cache and measured regression coverage.
- `493ab69` — connected privacy/journal/practice flow, localization and app/UI/widget regressions.

Delivery documentation follows in a separate commit. No push, merge, deployment or release submission performed. Build artifacts and detailed review reports remain ignored; this tracked plan records the evidence boundary. Optional formats and advanced recovery remain explicit deferrals above.
