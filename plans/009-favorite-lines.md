# 009 — Let people keep the lines that land

- **Status**: DONE
- **Severity**: MEDIUM
- **Category**: Missed opportunity / retention
- **Estimated scope**: 6–8 files, about 260 lines including tests and localized strings
- **Depends on**: —

## Problem

A daily line is visible for one day and then unreachable. `Think/Views/TodayView.swift:184` renders the quote with exactly one action — share (`Think/Views/TodayView.swift:212` → `ShareCardSheet`). There is no way to keep a line, and no way to go back to one. `grep -rn "favorite"` across the Swift sources returns nothing.

The content is the reason people open the app, and the share-card generator (`Think/Views/ShareCardSheet.swift:9`) already turns any `Quote` into a card. Saved lines feed that generator for free and give the app a reason to be opened outside the daily window.

## Target

### Storage

Favorites are identity references, not copies — `Quote.id` is already stable (`ThinkShared/Models/ContentLibrary.swift:25`: `localizationKey ?? text`), and storing IDs keeps favorites localized when the user changes language.

New `ThinkShared/State/FavoritesStore.swift`: `@Observable`, App Group `UserDefaults`-backed (`SharedDefaults.appGroup()`, same pattern as `ProgressStore`), holding an ordered array of `FavoriteRecord { quoteID: String, savedAt: Date }`.

- `isFavorite(_ quote: Quote) -> Bool`
- `toggle(_ quote: Quote)`
- `favorites: [Quote]` — resolved against `ContentLibrary.quotes`, dropping IDs that no longer exist (content can be removed in a later release; a dangling ID must not crash or render blank)
- injected into the environment from `Think/ThinkApp.swift`, next to `progress` and `timer`, and constructed with the UI-test-isolated defaults suite on the `-ui-testing` path

### Surfaces

- Today: a heart/bookmark button next to the existing share button on the quote card, with the selection haptic (`haptics.play(.selection)`) and the existing `ThinkMotion` tokens for the fill transition — no bounce or particles.
- New `Think/Views/FavoritesView.swift`: list of saved lines, newest first, each row tappable into `ShareCardSheet(quote:)` and swipe-to-remove. Empty state: "Lines you keep will appear here."
- Entry point: a Profile row under the content group, plus a toolbar/menu entry from Today if it fits without crowding the card.
- Share card sheet: an "add to favorites" affordance so a line can be kept from the moment it is shared.

### Localization

All new strings go in `Think/Localizable.xcstrings` with all six non-English locales filled (English is the source language and carries no entry).

## Verification

- Unit tests: toggle adds then removes; persistence survives a store rebuild against the same defaults; unknown IDs are filtered out of `favorites`; ordering is newest-first.
- Unit test: favorites resolve to the current locale's text after a locale change (same ID, different rendered string).
- UI test: favorite today's line, open Favorites, confirm one row; unfavorite, confirm the empty state.
- Manual: favorite a line, open the share sheet from Favorites, confirm the card renders the same quote.

## Out of scope

- The full line archive (browse every past daily line) — separate plan, separate gating discussion.
- Collections or folders.
- Any free/Pro boundary.
