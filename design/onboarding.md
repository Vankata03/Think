# Onboarding

Resolves [Onboarding aligned to the new IA](https://github.com/Vankata03/Think/issues/80), part of the [Think UI redesign map](https://github.com/Vankata03/Think/issues/68). Decided with the owner on 2026-09-26 in two grilling rounds, two canvas rounds (four structurally different flows, then a revised fifth; `prototype-onboarding/index.html` on branch `prototype/onboarding`, `?variant=E` is the chosen one) and a SwiftUI prototype run on an iPhone 17e Simulator with iOS 26.5 in dark, light and at AX3 (same branch, `Think/Views/OnboardingPrototypeView.swift`, screenshots in `prototype-onboarding/screens/`).

This brief inherits [design-system.md](design-system.md): tokens (section 2), type roles (3), spacing (4), symbols (7), the day arc (14) and the chrome baseline (13). It states only what onboarding decides.

## 1. What onboarding is

Onboarding runs once, on the first launch of a new installation, and ends on Today. It makes one promise, asks for the one permission a first day needs, and lets the person choose how Think looks. It does not teach the ritual in words: Today's next-act panel walks the person through the first question, move and retro one act at a time, so the lesson is the screen they land on.

- **No path page.** The old third page ("Start with Deep focus") goes. Paths are found through the Paths tab.
- **No re-run for existing users.** `Onboarding.completedKey` (`hasCompletedOnboarding`) keeps its meaning. A person upgrading into the redesign never sees onboarding, and no "What's new" screen replaces it. Their notification permission, reminders and appearance stay as they are; Settings is where they change them.
- **No state views.** Onboarding has nothing to be empty (design system section 8).

## 2. Structure

A paged flow of three steps, four on devices eligible for on-device AI. Each step is its own `NavigationStack` page. Moving between steps is forward only, through the primary; there is no back button and no swipe between pages.

| Step | Content | Container |
| --- | --- | --- |
| 1. Promise | The day arc, then the promise and one supporting sentence (section 3). | `ScrollView`, content centred vertically |
| 2. Reminders | Large title "Reminders". One `Form` section headed "Notifications" with three switches (section 4). | `Form` |
| 3. Make it yours | Large title "Make it yours". An "Appearance" section with three tiles, then an "Optional" section with two switches (section 5). | `Form` |
| 4. On-device AI | Only where the gate in [Go or no-go on on-device AI in Think](https://github.com/Vankata03/Think/issues/61) holds: iPhone, iOS 27, the model available and the app locale supported. Content is owned by [Onboarding step, Profile toggle and privacy wording for on-device AI](https://github.com/Vankata03/Think/issues/67). | That ticket's call |

Chrome on every step:

- **Skip** is a text button in the trailing toolbar slot, monochrome (design system section 2.2: bars carry no yellow here). It is on every step except the last. Section 6 says what it does.
- **Bottom safe-area bar** (`.safeAreaBar(edge: .bottom)`) holds the page dots and the primary. The primary is one full-width `.glassProminent` button tinted `accent` with `accentOnFill` ink: "Continue" on every step but the last, "Begin practice" on the last. The last step is "Make it yours" on most devices and the on-device AI step on eligible ones.
- **Page dots**: one 7pt circle per step, `label` for the current step, `tertiaryLabel` for the rest, `ThinkSpacing.s` apart. One accessibility element, "Step *n* of *m*". At accessibility sizes the dots are hidden and the primary carries "Step *n* of *m*" as its accessibility hint, so the step count is never lost.
- No navigation title on step 1; large titles on steps 2 and 3.

## 3. Step 1: Promise

- **Day arc.** `DayArcView` (design system section 14) with the hour fixed at 07:00 and no act done: the elapsed stroke and the sun run from 06:00 to 07:00, just short of the question marker at 08:00, which is next (`accent`, caption in `accentInk`), the move and retro markers are later (dashed). The centre shows no weekday, count or time; the arc here is a picture of a day, not a clock. It is one accessibility element: "Your day: a question in the morning, a move by afternoon, a retro in the evening." At accessibility sizes the arc is dropped entirely rather than turned into the linear bar, because "0 of 3" teaches nothing before the first day.
- **Promise**: "One line, one question, one move a day." in the `lineLarge` role (`.title`, serif). The owner confirmed `.title` over `.largeTitle` on device, so onboarding adds no type role.
- **Supporting line**: "A few honest minutes. What you write stays on your device, and syncs through your own iCloud when available." in `body`, `secondaryLabel`.
- The block is centred vertically in the space above the bottom bar and scrolls when the type is large. This retires the dead space of `ONB-4`.

## 4. Step 2: Reminders

One `Form` section, header "Notifications", three switch rows. Each row has its monochrome symbol from design system section 7.

| Row | Symbol | Default | Trailing value |
| --- | --- | --- | --- |
| Daily line | `dailyLine` (`text.quote`) | on | "08:00" in `secondaryLabel`, monospaced digits, shown while on |
| Evening retro | `retro` (`moon.stars`) | on | "20:00", same treatment |
| Session end alerts | `focus` (`timer`) | on | none; a `secondary` line under the title: "When a focus or break interval ends" |

- Times are shown, not edited, here. Changing a time is a Settings job; the footer says so: "Change times and switches later in Settings, behind the gear on Progress." With every switch off the footer reads "Turn any of these on in Settings, behind the gear on Progress."
- Times follow the device clock format (08:00 or 8:00 AM).
- **The permission ask.** Nothing is asked while the person flips switches. "Continue" with at least one switch on calls `UNUserNotificationCenter.requestAuthorization` once.
  - Allowed: the switches that are on are saved and scheduled (`DailyQuoteNotifier.enabledKey`, `RetroReminder.enabledKey`, the Session end alerts setting from [progress-settings.md](progress-settings.md) section 3).
  - Not allowed: all three are saved off, silently. Settings shows its existing denied explanation with "Open Settings" when the person looks there.
  - "Continue" with every switch off asks nothing and saves all three off.
- **Retro reminder default.** `RetroReminder.defaultMinutes` changes from 21:00 to 20:00, so the reminder, the retro marker on the day arc and the hour the retro act opens on Today ([today.md](today.md) section 2) agree. The daily line stays at 08:00, which is the question marker's hour. The reminder time never moves the arc markers; they are fixed.
- This step is where Session end alerts get their permission. The Focus timer no longer asks at Start ([focus.md](focus.md) section 7).
- At accessibility sizes a switch drops under its label (the rule already in [progress-settings.md](progress-settings.md) section 3), and the time moves under the title. Without that, "Evening retro" broke mid-word beside the switch at AX3 in the prototype.
- The switches use the system green; no accent tint on switches or row symbols.

## 5. Step 3: Make it yours

### 5.1 Appearance tiles

The one place in the app where appearance is chosen with pictures instead of rows. Settings keeps its inline `Picker` (design system section 13.7; [progress-settings.md](progress-settings.md) section 3).

- One section, header "Appearance", holding a single row with three tiles side by side: **Dark**, **Auto**, **Light**, in that order, with the existing `Appearance.label` strings. Dark is selected for a new installation (design system section 1.2).
- Each tile is a thumbnail of Today in miniature (the arc, two text bars and the next-act panel with its yellow button), then the label in `secondary`, then a selection mark: `checkmark.circle.fill` in `accent` when selected, `circle` in `tertiaryLabel` when not. The selected thumbnail also carries a 2.5pt `accent` outline offset 4pt. The Auto thumbnail is split down the middle, dark on the left and light on the right, so it explains itself without a caption.
- The thumbnails are drawn with shapes in both schemes' fixed colours, not rendered from a live view, so they read the same whatever the current appearance.
- Choosing a tile writes `Appearance.storageKey` at once and the whole app repaints, so the screen is its own preview.
- Each tile is one button with the label as its accessibility label and the `.isSelected` trait on the chosen one.
- At accessibility sizes the tiles stack into three rows: thumbnail at 44×80pt, label, selection mark.

### 5.2 Optional

One section, header "Optional", two switch rows, both off by default. Same row pattern and accessibility-size rule as section 4.

| Row | Symbol | Secondary line | Turning it on |
| --- | --- | --- | --- |
| Log focus to Health | `health` (`heart`, new in design system section 7) | "Completed sessions become Mindful Minutes" | Shows the Health authorization sheet immediately, through the same `MindfulMinutesStore` path Settings uses. A denial or error leaves the switch off. |
| Lock journal | `lock` (`lock`) | "Face ID before your writing opens", with the device's method (Face ID, Touch ID or passcode) from `JournalLock.availability` | Enables the lock through `JournalLock.setEnabled(true)`, as Settings does. Nothing is asked now; the first authentication happens the next time the journal opens. |

- Footer: "Both stay in Settings." The prototype's footer also said each switch asks its own permission; that is true only of Health, so the sentence is dropped.
- Each row is shown only where it can work: Health where `HKHealthStore.isHealthDataAvailable()` is true, Lock journal where `JournalLock.availability.canEnable` is true. Settings keeps its unavailable explanations; onboarding simply omits the row. When neither row can be shown, the whole section is omitted.
- iCloud is not offered: mirroring follows the Apple Account and has no switch ([progress-settings.md](progress-settings.md) section 3). The supporting line in step 1 is the only mention, and it says "when available" because mirroring needs an iCloud account.

## 6. Skip and finish

- **Skip** ends onboarding from any step but the last. It never asks a permission. Whatever an earlier Continue already saved stays saved; anything on the current or a later step keeps its default, which means Skip on step 1 or 2 leaves all three notification settings off, appearance Dark and both optional switches off. Skip on step 3 exists only when the on-device AI step follows it, and keeps what step 3 already applied. Skip then sets `hasCompletedOnboarding` and lands on Today.
- **Begin practice** on the last step saves what the steps chose, sets `hasCompletedOnboarding` and lands on Today with the question as the next act.
- Onboarding sets no streak, path or practice state. The first meaningful practice happens on Today.
- Motion between steps: the page content crossfades and slides with `ThinkMotion.stateAnimation`; with Reduce Motion it crossfades only. `haptics.play(.selection)` on Continue and `.success` on finish stay as they are.

## 7. Strings

New or changed strings for `Localizable.xcstrings`, to be translated into all seven locales and length-checked in `bg` and `de`:

- "One line, one question, one move a day."
- "A few honest minutes. What you write stays on your device, and syncs through your own iCloud when available."
- "Your day: a question in the morning, a move by afternoon, a retro in the evening." (accessibility label)
- "Reminders", "Notifications", "Daily line", "Evening retro", "Session end alerts", "When a focus or break interval ends"
- "Change times and switches later in Settings, behind the gear on Progress." / "Turn any of these on in Settings, behind the gear on Progress."
- "Make it yours", "Appearance", "Optional", "Log focus to Health", "Completed sessions become Mindful Minutes", "Lock journal", "Face ID before your writing opens" (and its Touch ID and passcode forms), "Both stay in Settings."
- "Skip", "Continue", "Begin practice", "Step %lld of %lld"

Retired with the old view: "A gym for your mind", "Bookend your day", "You can change this anytime in Profile.", "Start with %@", the four practice rows and their details.

## 8. Removed views and code

The build that ships this brief deletes what it replaces; nothing stays behind a flag:

- `Think/Views/OnboardingView.swift` is replaced whole: `practicePage`, `notificationPage`, `pathPage`, the capsule page indicator, the hand-built rounded cards with separator strokes, the 88pt quote glyph and the 44pt page symbols, and every `.padding(.horizontal, 24)`. The `Onboarding` enum and its `completedKey` stay.
- `Color.prominentButtonForeground(for:)` loses its last onboarding caller (the design system already removes it).
- `Think/Views/OnboardingPrototypeView.swift` and `prototype-onboarding/` never merge; they stay on `prototype/onboarding`.

## 9. Absorbed bugs

From `research/ui-bug-inventory.md` (branch `research/ui-bug-inventory`):

| ID | Fix |
| --- | --- |
| `ONB-1` | The page indicator moves into the bottom bar above the primary; Skip is a toolbar item. They no longer share a row, so there is no baseline to miss. |
| `ONB-2` | Feature rows are gone. Every remaining symbol sits in a `Form` row at its text style, so optical sizes match. |
| `ONB-3` | Separators are the `Form`'s own, inset to the label and running to the trailing edge. |
| `ONB-4` | Step 1 is centred vertically; steps 2 and 3 are `Form`s that start under the large title. Skip is present on every step but the last, where "Begin practice" is the only way out and a Skip beside it would do the same thing. |

## 10. Acceptance floor

Design system section 11 applies. Specific to onboarding:

- Dynamic Type through AX3: the arc is dropped, the promise and supporting line scroll above the bottom bar, switches drop under their labels, appearance tiles stack, page dots hide and the primary carries the step count. Checked on the prototype at AX3; production strings still need the check in `bg` and `de`.
- Both appearances, and the appearance tiles repaint the live screen in both directions.
- The notification prompt appears once at most, only from Continue on step 2 with a switch on; never from Skip, never from the Focus timer.
- VoiceOver: Skip, the primary, each switch and each tile are reachable and labelled; the arc is one element; the step count is announced.
- Reduce Motion: step changes crossfade.
- Step count: an eligible device shows four steps with "Begin practice" on the AI step; an ineligible one shows three with "Begin practice" on "Make it yours".
