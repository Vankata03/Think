# 010 — Tag entries with a mood

- **Status**: DONE — implemented on `feature/icloud-journal-backup` alongside 006
- **Severity**: LOW
- **Category**: Missed opportunity
- **Estimated scope**: 5–7 files, about 200 lines including tests and localized strings
- **Depends on**: 006 (model changes should land in the same CloudKit-compatible shape)

## Problem

Journal entries carry text and nothing else (`Think/Models/JournalEntry.swift`), and evening retrospectives carry three text fields (`Think/Models/DailyRetro.swift`). There is no structured signal in any of it, so the app can never say anything about how days actually went — only that they were written about.

A single-tap mood is the cheapest structured field that makes later trend work possible, and it lowers the cost of journaling on days when writing feels like too much.

## Target

### Model

- `JournalEntry` gains `var mood: String?` (nil = untagged).
- `DailyRetro` gains `var mood: String?`.
- Both must be optional for CloudKit mirroring (see 006) — do not use a defaulted non-optional.
- New `Think/Models/Mood.swift`: `enum Mood: String, CaseIterable` with five values — `low`, `flat`, `steady`, `good`, `sharp` — each with a localized label and an SF Symbol. Store the raw string on the models so an unknown future value degrades to "untagged" instead of failing to decode.

Five values, not a numeric scale: the labels stay in the app's disciplined, non-clinical register, and a fixed small set is what a later trend line needs.

### Surfaces

- `NewNoteSheet` (`Think/Views/JournalView.swift:143`) and `RetroSheet` (`Think/Views/RetroSheet.swift`): a horizontal chip row above the text field. Tapping selects; tapping the selected chip clears it. Saving with no selection is normal and unremarked.
- The daily-question answer flow in `Think/Views/TodayView.swift` gets the same row.
- `entryRow` (`Think/Views/JournalView.swift:101`) and `retroRow` (`:117`) show the mood symbol next to the date when present.
- `Think/State/JournalExport.swift` includes the mood label in the exported text.

No streaks, no scores, no "you seem low" messaging. The tag is a record, not a judgement.

## Verification

- Unit tests: entries written without a mood decode with `mood == nil`; an unrecognized stored raw value maps to nil rather than throwing; export renders the label for tagged entries and omits the line for untagged ones.
- Unit test: chip toggle clears on re-tap.
- Manual: write a note with a mood, confirm it renders in the list and survives relaunch; with 006 in place, confirm it syncs to a second device.
- The five labels are present in all six non-English locales in `Think/Localizable.xcstrings`.

## Out of scope

- Mood trends, charts, or correlation with focus sessions — worth doing, but only after enough tagged entries exist to make a chart honest.
- Apple's State of Mind (`HealthKit`) read/write integration.
