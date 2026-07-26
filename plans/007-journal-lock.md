# 007 — Lock the journal behind Face ID or the device passcode

- **Status**: TODO
- **Severity**: MEDIUM
- **Category**: Privacy / missed opportunity
- **Estimated scope**: 4–6 files, about 180 lines including tests and localized strings
- **Depends on**: — (pairs naturally with 006)

## Problem

The journal is the most personal surface in the app and it is reachable in two taps from Profile with no authentication (`Think/Views/ProfileView.swift` journal entry point into `Think/Views/JournalView.swift:38`). Anyone holding an unlocked phone can read every note, daily answer, and evening retrospective, and can export them all through `Think/Views/JournalExportSheet.swift`.

Privacy is the journal's stated selling point. Right now that claim rests entirely on "the data never leaves the device", which is invisible to the user. A lock makes it tangible.

## Target

### Behavior

Opt-in setting, default off. When on:

- opening the Journal presents a lock screen instead of entries;
- authentication uses `LAContext.evaluatePolicy(.deviceOwnerAuthentication)` — biometry with automatic passcode fallback, so a device without Face ID or with biometry locked out still works;
- success unlocks for the lifetime of the foreground session;
- returning from background relocks after a grace period of 60 seconds (avoids re-authenticating for a share sheet or photo picker round trip);
- cancel or failure leaves the lock screen with a "Unlock" retry button and no entry content rendered;
- the retro composer and note composer launched from elsewhere (`Think/Views/RetroSheet.swift`, the daily-question flow in `Think/Views/TodayView.swift`) stay unlocked — writing is not gated, only reading history;
- journal export (`Think/State/JournalExport.swift` surface) requires a fresh successful authentication every time, regardless of the session unlock.

If no passcode is set on the device (`LAContext.canEvaluatePolicy` fails with `.passcodeNotSet`), the setting cannot be enabled; the Profile row explains why and stays disabled.

### Structure

- New `Think/State/JournalLock.swift`: `@Observable` `JournalLock` with `isEnabled` (`@AppStorage`-backed key `journalLockEnabled`), `isUnlocked`, `authenticate() async -> Bool`, `lock()`, and the background grace-period logic driven by `scenePhase`. Authentication goes through a small `JournalAuthenticator` protocol so tests can inject success/failure/unavailable without touching `LAContext`.
- `Think/Views/JournalView.swift`: wrap the list in a lock gate; the gate renders an SF Symbol, a one-line explainer, and an Unlock button, and holds no entry text.
- `Think/Views/ProfileView.swift`: toggle row "Lock journal" with a Face ID / Touch ID / passcode-aware subtitle from `LAContext.biometryType`.
- `Think/Info.plist` (target build settings): `NSFaceIDUsageDescription` — "Think uses Face ID to keep your journal private." Ship it localized in all seven locales via `Think/InfoPlist.xcstrings`.
- UI tests run with the lock disabled by default; add an explicit launch argument only if a lock-path UI test is worth the flake risk (recommendation: cover the gate logic in unit tests instead).

## Verification

- Unit tests over `JournalLock` with a stub authenticator: enabled + success unlocks; enabled + failure stays locked; disabled never gates; a 30-second background trip keeps the unlock; a 90-second one relocks; export always requires a fresh call.
- Manual: enable the lock, background and reopen past the grace period, confirm the gate returns and no entry text is visible in the app switcher snapshot.
- Manual on a device with no passcode: toggle is disabled with an explanation.
- Existing journal UI tests still pass unchanged.

## Out of scope

- Per-entry locking.
- A Think-specific passcode separate from the device passcode.
- Hiding journal content from the app-switcher snapshot for the *unlocked* session (evaluate separately; a privacy-screen overlay is a different change).
