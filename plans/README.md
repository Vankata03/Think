# Plans

## Animation plans

| # | Plan | Severity | Status | Depends on |
|---|---|---|---|---|
| 001 | Animate daily-answer completion | MEDIUM | DONE | — |
| 002 | Animate path-day completion | MEDIUM | DONE | 001 |
| 003 | Animate calendar month navigation | LOW | DONE | 001 |
| 004 | Animate evening-retrospective appearance | LOW | DONE | 001 |
| 005 | Present and share every achievement | MEDIUM | DONE | 001 |

Recommended execution order: 001 → 002 → 004 → 003 → 005. Plan 001 establishes shared motion tokens and Reduce Motion helpers. Plans 002–005 reuse them without adding local timing vocabulary.

## 1.2 — journal safety and focus depth

Feature wave after the 1.1 platform release. No paywall or Pro gating in this batch; monetization stays a separate, later decision.

| # | Plan | Severity | Status | Depends on |
|---|---|---|---|---|
| 006 | Back the journal up to the user's iCloud | HIGH | CODE LANDED | — |
| 007 | Lock the journal behind Face ID or the device passcode | MEDIUM | DONE | — |
| 008 | Give each focus session an intention and a closing note | MEDIUM | DONE | — |
| 009 | Let people keep the lines that land | MEDIUM | DONE | — |
| 010 | Tag entries with a mood | LOW | DONE | 006 |
| 011 | Let the evening retrospective reminder through Focus modes | LOW | DONE | — |

Recommended execution order: 006 → 010 → 007 → 008 → 009 → 011.

006 is code-complete but not shippable: its release checklist (production
schema deployment, the two-device round trip, and the no-account run) is still
open, and mirroring cannot work in production until at least the first of those
lands.

006 first because it is the only item that removes a data-loss risk, and because it constrains the SwiftData model shape (every attribute optional or defaulted) that 010 must follow — landing 010 before 006 means writing the model twice. 007 completes the privacy story 006 opens. 008 and 009 are independent of both and can run in either order. 011 is a two-file change that can ride along with any of them.
