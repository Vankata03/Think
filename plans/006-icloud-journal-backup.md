# 006 — Back the journal up to the user's iCloud

- **Status**: CODE LANDED — ship blocked until the release checklist below is complete
- **Severity**: HIGH
- **Category**: Data loss risk
- **Estimated scope**: 6–9 files, about 300 lines including tests and localized strings
- **Depends on**: —

## Problem

Every journal artifact lives in a single on-device SwiftData store. `Think/ThinkApp.swift:172` builds it with no CloudKit configuration:

```swift
.modelContainer(for: [JournalEntry.self, DailyRetro.self], inMemory: isUITesting)
```

A lost, wiped, or replaced phone erases every note, daily answer, and evening retrospective. Nothing in the app warns the user, and `Think/State/JournalExport.swift` (manual text export) is the only recovery path — it requires the user to have exported in advance.

The privacy posture ("no backend, no account") is a product pillar, so a Think-operated server is out. The user's own iCloud private database keeps that posture intact: data stays in the user's account, encrypted in transit and at rest, with no Think-side infrastructure or credentials.

## Target

### Container

Move container construction out of the `.modelContainer(for:)` convenience and into an explicit `ModelConfiguration` so the CloudKit database can be chosen per run:

- normal runs: `cloudKitDatabase: .private("iCloud.com.ivanterziev.Think")`;
- UI tests (`-ui-testing`): in-memory, `cloudKitDatabase: .none` — the test store must never touch a real account;
- unit tests (any process with `XCTestConfigurationFilePath` set) and previews: `.none`. Unit tests are hosted inside the app, so without this check every `xcodebuild test` run starts CloudKit mirroring against a simulator with no iCloud account; observed effect is a mirroring-delegate retry loop that floods the log and hangs the test host.

Build the container once in `ThinkApp.init` alongside the other stores and inject it with `.modelContainer(_:)`. If container creation with CloudKit fails (no iCloud account, entitlement missing, quota), fall back to the same local store the app uses today and surface the state rather than crashing — a failed sync must never block journaling.

### Model changes required by CloudKit

SwiftData's CloudKit mirroring rejects models that CloudKit cannot represent. Both models need an audit pass:

- every attribute must be optional or carry a default value — `JournalEntry.date`, `prompt`, `text` and all three `DailyRetro` string fields currently have no defaults (`Think/Models/JournalEntry.swift:13`, `Think/Models/DailyRetro.swift:14`);
- no `@Attribute(.unique)` (none today — keep it that way);
- any future relationship must be optional and have an inverse.

Give the strings `= ""` defaults and `date` a `= Date()` default. The initializers keep their current signatures, so no call site changes. This is a lightweight migration: adding defaults to existing non-optional attributes does not require a `VersionedSchema` migration plan, but the change must be verified against a store written by 1.1.1 before shipping (see Verification).

### Entitlements and capabilities

- `Think/Think.entitlements`: add `com.apple.developer.icloud-services` = `["CloudKit"]`, `com.apple.developer.icloud-container-identifiers` = `["iCloud.com.ivanterziev.Think"]`, and `aps-environment` (background push is how CloudKit notifies the app of remote changes).
- Enable the Remote notifications background mode for the iOS target.
- Create the `iCloud.com.ivanterziev.Think` container in the developer portal; the CloudKit schema is generated from the models on first run in the development environment and must be **deployed to production before the release build is submitted** — an undeployed schema makes sync silently fail for App Store users.
- The widget, watch, and watch-widget targets do not read journal data and must not get the CloudKit entitlement.

### User-facing surface

Add one Profile row under the journal group (`Think/Views/ProfileView.swift`), not a toggle:

- title: "iCloud backup";
- state line: "On — your journal syncs with your iCloud" / "Off — turn on iCloud Drive for Think in Settings" / "Signed out of iCloud";
- a short explainer: entries stay in the user's own iCloud; Think has no server and no account.

State comes from `CKContainer.accountStatus()` plus whether the container was built with CloudKit. No in-app on/off switch: SwiftData decides mirroring at container-construction time, and a mid-run toggle would mean tearing down and rebuilding the container under a live `@Query`. The system iCloud settings are the switch; the row explains that.

### Privacy manifest and store metadata

- `Think/PrivacyInfo.xcprivacy`: journal content stored in the user's own iCloud is not data "collected" by the developer, so no new collected-data type is required — confirm against the current manifest and leave it unchanged if so.
- App Store privacy answers stay as they are for the same reason. Note the decision in the PR body so the reasoning survives.

## Verification

Done (2026-07-26): unit and UI suites green; CloudKit Development schema generated (`CD_JournalEntry`, `CD_DailyRetro`); records from a device build appear in the private database, zone `com.apple.coredata.cloudkit.zone`, with `CD_date`, `CD_kind`, `CD_prompt`, `CD_text` populated. Entries written by 1.1.1 before the upgrade are present, so the defaulted-attribute change migrated the existing store without loss.

Release checklist — every item blocks shipping this feature, because each one
covers a failure that only appears outside the development environment:

- [ ] Deploy the CloudKit schema to production. A production build against a
      development-only schema cannot mirror at all.
- [ ] Two-device round trip on one iCloud account: create a note, an answer,
      and a retro on device A; confirm all three reach device B; delete on B;
      confirm removal on A.
- [ ] No-account run: launch signed out, confirm journaling still works and the
      Profile row reports the signed-out state rather than claiming a backup.

Console note: browsing records in CloudKit Console needs a Queryable index on `recordName` for each record type (Schema → Indexes). SwiftData does not create one; the app never needs it, since mirroring syncs by zone changes rather than by querying record names.

- Unit test: a `ModelConfiguration` factory (extracted so it is testable) returns `.none` for the UI-testing and test paths and the private database otherwise.
- Unit test: `JournalEntry` and `DailyRetro` initialize with no arguments where defaults now exist, and decode from a store seeded with 1.1.1-shaped rows.
- Manual, two devices signed into one iCloud account: create a note, an answer, and a retro on device A; confirm all three appear on device B; delete on B, confirm removal on A.
- Manual, no iCloud account: app launches, journaling works, the Profile row reads "Signed out of iCloud".
- Manual migration check: install 1.1.1 from TestFlight, write entries, upgrade to the branch build, confirm existing entries survive and then upload.
- UI tests must not regress — verify the `-ui-testing` path still uses an in-memory `.none` store.

## Out of scope

- Journal search and full history browsing.
- Any Pro gating of backup.
- Syncing progress/streak state (that lives in `UserDefaults` via the App Group and follows a different design).
