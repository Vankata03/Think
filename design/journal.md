# Journal

Resolves [Journal: list, detail, editor and gate](https://github.com/Vankata03/Think/issues/78), part of the [Think UI redesign map](https://github.com/Vankata03/Think/issues/68). Decided with the owner on 2026-09-26 in three grilling rounds, one canvas round (filter control, row content, how an entry opens, editor shape; `prototype-journal/journal-canvas.html` on branch `prototype/journal`) and a SwiftUI prototype run on the Simulator in dark, at AX3 and in `de` (same branch, `Think/Views/JournalPrototypeView.swift`).

This brief inherits [design-system.md](design-system.md): tokens (section 2), type roles (3), spacing (4), symbols (7), states (8) and the chrome baseline (13). It states only what the Journal decides.

## 1. What the Journal is

The Journal tab holds everything the person wrote (`CONTEXT.md`: Journal): answers, notes, retros, weekly-review reflections, and the focus notes written before the Focus close flow was removed. It never holds saved lines; they are on Today's bookmark. The Journal owns one editor for every kind of entry, and one read-only view of a record. Today and Progress reuse both.

## 2. The list

`NavigationStack`, large title "Journal", one inset-grouped `List`. From the top:

1. **Toolbar.** One trailing item: the filter menu (section 3). No leading item.
2. **Search.** `.searchable` on the list, prompt "Search". On iOS 26 inside the tab it sits under the large title, not at the bottom; the prototype confirmed it does not collide with the New note button. Search matches the prompt, the text and every retro field. It does not match theme or mood names; those are filters. Search and filters also run over versions (section 6), so no writing is unfindable.
3. **Active filters line.** Only while a filter is on: one clear row, the filter names joined by " · " in `secondary` (for example "Answers · Last 7 days"), and a trailing "Clear" in `accentInk`. It replaces the old header strip of section picker and bordered menus.
4. **Status rows.** Only when they apply, above the timeline and never instead of it (section 8, Unavailable): the temporary-storage warning, then "Unsaved drafts (*n*)" pushing `JournalRecoveryView`, with the unreadable-drafts footnote. The storage warning always shows, filtered or not, because it changes whether new writing is kept. The drafts row hides while a filter or search is active.
5. **Timeline.** One `Section` per civil day, newest first, headed "Today", "Yesterday", then the full weekday and date ("Thursday 24 September") in the system header style. Rows follow section 4. The day in the header is the record's stored civil day, so the date never repeats inside a row and no ISO key is shown anywhere.
6. **Paging.** Bounded repository pages as today. "Load more" stays as the last row; the "*n* of *m* shown" footer goes.

**New note** is the floating bottom-trailing primary of design-system section 13.6: `.safeAreaBar(edge: .bottom, alignment: .trailing)`, one `.glassProminent` circle created as `Button("New note", systemImage: ThinkSymbol.add)`. It is present in every kind filter, including while locked (blank capture grants no read access). Retros are not started from the Journal: "Begin retro" lives on Today; an existing retro is edited from its detail.

**Row actions.** A trailing swipe offers Delete (`ThinkSymbol.delete`, red tint, not the destructive role so the row does not vanish before the confirmation). It asks with the same dialog as the detail (section 5).

## 3. Filter menu

The trailing toolbar item is a `Menu` labelled "Filter" with `line.3.horizontal.decrease` (the new `filter` symbol in design-system section 7). While any filter is on, the symbol becomes `line.3.horizontal.decrease.circle.fill`, monochrome like every bar item (design-system section 2.2); the fill and the active filters line carry the state.

Menu content, in order:

| Group | Presentation | Options |
| --- | --- | --- |
| Kind | Inline `Picker` | All, Answers, Notes, Retros, Weekly reviews, Focus notes. Focus notes is listed only when at least one exists. Each option carries its kind symbol (section 4). |
| Mood | `Picker` with `.menu` style, a submenu showing the current value | Any mood, No mood, then the five moods with their symbols. |
| Theme | Submenu | Any theme, then the eight themes as words, no symbols. Single select; matches the primary or the secondary theme. |
| Date | Submenu | Any time, Today, Last 7 days, Last 30 days. |

A segmented control was drawn and rejected: five or six kind labels truncate in `de` ("Antwo…", "Rückb…"). Search tokens were drawn and rejected as harder to find.

## 4. Row

The compact row, one per record.

| Line | Content | Role |
| --- | --- | --- |
| Badge | The kind symbol in `secondaryLabel` on a 28pt `fill` (quaternary) rounded square, leading and top-aligned. The badge is the only place the kind shows; its accessibility label is the kind name. | `caption` symbol |
| Title | The first sentence of the person's words, one line. A retro uses its first non-empty field. A weekly review uses "Week of *d Month*". | `heading` (`.headline`) |
| Second line | The time in `label`, two spaces, then the rest of the text in `secondaryLabel`, one line. | `secondary` |
| Tags | The mood symbol and name, then the primary theme, joined by " · ". Omitted when both are empty. The secondary theme shows only on the detail. | `caption` |

Kind symbols: answer `questionmark.bubble` (`question`), note `note.text` (new `note`), retro `moon.stars` (`retro`), weekly review `calendar.badge.checkmark` (`weeklyReview`), focus note `timer` (`focus`).

At accessibility sizes the badge stacks above the text, the title takes up to three lines, the time gets its own line and the rest takes up to two. The whole row is one accessibility element: kind, title, time, rest, mood and theme.

The row never shows journal content while locked, because the list is not drawn while locked (section 7).

## 5. Read detail

Tapping a row pushes the read-only record. Today's done answer and retro rows and Progress's saved weekly reflection push the same view. Inline title: the kind name. Trailing toolbar: "Edit" (text button), which presents the editor sheet on that record.

Content is one clear list row (design-system section 13.1), top to bottom:

- The civil day in full ("Saturday 26 September") in `caption`.
- Answer and focus note: the prompt in the `question` role (`.title3` serif). A focus note's prompt is its session intention, in `secondaryLabel`, because it cannot be edited. A weekly review: "Week of *d Month*" in the same role.
- The text in `body`, selectable. A retro instead shows its three prompts ("What went well?", "What can improve?", "Ideas & tomorrow") in `secondary` semibold, each followed by its answer in `body`, then "Intention for tomorrow" and its text. A weekly review adds "Next week" and its intention.
- "Written *time*", plus " · Edited *time*" when `updatedAt` differs, then mood, primary theme and secondary theme joined by " · ". All `caption`.

Then, as grouped rows:

- **Another version from this day**: only on a record that has versions (section 6). It pushes the other version's read detail; with more than one, it pushes a plain list of them, newest first.
- **Delete entry**: a destructive row. It asks "Delete this entry?" with the message "It is removed from this device and your iCloud." and one destructive "Delete entry". Retros read "Delete this retro?". After deletion the view pops and any unsaved edit for the record is removed, with the existing failure messages.

Removed from the detail: the Date and Day `LabeledContent` rows, the separate Mood and Edited rows, the "View this practice" link, the "Other answers for this day" section and its footer, and the `…` menu.

## 6. One record a day: versions

An answer and a retro are one per civil day. Two devices writing the same day offline both keep their record after sync; nothing is merged or deleted automatically (`CONTEXT.md`: Version).

- **The day's record is the latest edit.** `JournalIdentity.select` orders by `updatedAt ?? date` descending, then record ID, then the existing tiebreak; the first is the primary. The ordering is device-independent, so every device lands on the same primary. It replaces "earliest `date` first".
- The primary is what Today shows, what the Journal lists and what the weekly review reads. Other versions appear only behind the "Another version from this day" row on the primary's detail.
- Editing an older version gives it the newest `updatedAt`, so it becomes the primary. There is no "make this the answer" action; the last touch decides.
- A version can be read, edited or deleted like any record.
- The unfiltered timeline lists primaries only. When a search or a filter matches a version, the results show that version's own row, with "Other version" in `secondaryLabel` after the time on its second line; when both the primary and a version match, both rows show. Clearing the search or filter returns to primaries only.

## 7. Lock

When the journal lock is on and engaged, the tab shows the Locked state of design-system section 8: `ContentUnavailableView` with `ThinkSymbol.lock`, "Your journal is locked." and one `secondary` "Unlock". `JournalGate` is rewritten to this form, and every screen that uses it (list, read detail, editor recovery, weekly review) gets the new look.

- Face ID is requested when the tab appears, as today; "Unlock" is the retry.
- While locked: no search field, no filter menu, no status rows. New note stays.
- A pushed read detail that locks underneath shows the same state.

## 8. Editor

One editor for every kind, presented as a sheet at the `.large` detent: a new note from the floating button, an answer from Today's "Write answer", a retro from Today's "Begin retro", and Edit from any read detail. `RetroSheet` is deleted; the retro is a kind of this editor.

Chrome: inline title ("New note", or the kind name when editing), the system Cancel (`.cancellationAction`, `Button(role: .cancel)`) and Done (`.confirmationAction`, `Button(role: .confirm)`), which iOS 26 draws as ✕ and ✓. Done is disabled until there is something to save, as today. Drafts autosave exactly as `JournalDraftStore` does now; the "Drafts stay on this device until you save or discard them." footer goes.

Content is a `ScrollView`, not a `Form` (the second exception in design-system section 13.1, after Focus), with `.scrollDismissesKeyboard(.interactively)` so the text scrolls above the keyboard (`JRN-4`). From the top:

1. The civil day in `caption`. A new note adds the time ("Saturday 26 September · 21:04").
2. The prompt in the `question` role: the question for an answer, the intention for a focus note (read-only, `secondaryLabel`), "Week of *d Month*" for a weekly review. Notes and retros have none.
3. **Header chips**, on every kind except the weekly review, which carries neither mood nor theme: two bordered capsule menu buttons in a `ViewThatFits` (side by side, stacked when they do not fit). Nothing scrolls horizontally, so nothing clips (`JRN-3`).
   - **Mood**: the chosen mood's symbol and name, or `face.smiling` and "Mood" in `secondaryLabel`. The menu lists "No mood", then the five moods.
   - **Theme**: the chosen themes as words joined by " · ", or "Theme" in `secondaryLabel`. The menu is headed "Up to two" and lists the eight themes with a checkmark on the chosen ones. It stays open while picking (`.menuActionDismissBehavior(.disabled)`). The rules of the [Theme taxonomy decision](https://github.com/Vankata03/Think/issues/64) apply: tapping selects; a third selection replaces the secondary; tapping a chosen theme clears it; clearing the primary promotes the secondary.
4. The writing area. Answer, note, focus note and weekly review: one `TextField(axis: .vertical)` in `body`, placeholder "Start writing", focused on appear for a new record. A weekly review adds "Next week (optional)". A retro: its three prompts in `secondary` semibold, each over its own vertical text field, then "Intention for tomorrow".

**Theme pre-fill** (eligible devices, per the Theme decision): after typing pauses for about 1.5 seconds past roughly eight words, the model may fill the Theme chip. Until the person touches the chip, it reads "*Theme* · Suggested", with "Suggested" in `secondaryLabel`. There is no symbol: `sparkle` already means Meaningful practice (section 7). Once touched, the model never changes it. On save, the theme is stored as plain user data, and nothing marks it on the row or the detail.

**Focus notes** edit as plain notes: the intention is the read-only prompt, the body and the header chips are editable. The outcome and energy pickers and the recovered-session intention field go; the stored outcome and energy stay in the model, unread ([focus.md](focus.md) section 8).

This amends the Theme decision's presentation. It specified a horizontally scrolling chip row of all eight themes under the mood row, editable from the entry detail. The Journal replaces that with the Theme menu chip, and themes change only through Edit.

## 9. States

Cited from design-system section 8, no new states:

| Where | Class | Presentation |
| --- | --- | --- |
| Whole journal, nothing written | Empty | "Nothing written yet." with a secondary "Write a note" that opens the editor. The filter menu hides. |
| Search with no results | No-match | `ContentUnavailableView.search(text:)`. |
| Filters with no results | No-match | The active filters line, then one row "No entries match." and a tertiary "Clear filters". |
| Locked | Locked | Section 7. |
| Record not found | Unavailable | "Entry not found." with "Close". |
| Journal failed to load | Unavailable | "Could not load your journal." with "Try again". |

## 10. Today and Progress

- **Today** ([today.md](today.md) section 4, amended with this brief): "Write answer" and "Begin retro" open this editor; the done answer and retro rows push the read detail of section 5; with versions, Today shows the primary only. `JournalDayVariantsView` goes.
- **Progress** ([progress-settings.md](progress-settings.md)): the weekly review's saved reflection pushes the read detail of section 5.

## 11. Removed views and code

The build that ships this brief deletes what it replaces; nothing stays behind a flag:

- `Think/Views/JournalView.swift`, replaced whole: the section picker, the mood and date `filterBar`, the five filter-specific empty lines, the "*n* of *m* shown" footer and the hand-set row insets.
- In `Think/Views/JournalDetailView.swift`: `JournalEntryDetailView` and `JournalRetroDetailView` merge into the one read detail; `JournalEntryRow`, `JournalRetroRow`, `RetroFieldText` and `JournalMoodBadge` are replaced by the section 4 row; `JournalDayVariantsView` and the "Other answers" sections go. `JournalRecoveryView` and the draft helpers stay.
- `Think/Views/RetroSheet.swift` and every presentation of it (`TodayView`, `JournalView`).
- `Think/Views/MoodPicker.swift`, replaced by the Mood menu chip.
- In `Think/Views/JournalEditor.swift`: the `Form` layout, the focus outcome and energy pickers and the intention field, the civil-day key text and the drafts footer. Draft persistence and save logic stay.
- `Think/Views/JournalGate.swift` keeps its name and is rewritten to section 7.
- `JournalIdentity.select` ordering changes (section 6); `JournalIdentityTests` change with it.
- `Think/Views/JournalPrototypeView.swift` and `prototype-journal/` never merge; they stay on `prototype/journal`.

## 12. Absorbed bugs

From `research/ui-bug-inventory.md` (branch `research/ui-bug-inventory`):

| ID | Fix |
| --- | --- |
| `JRN-1` | No hand-built header strip; system list insets and one active-filters row. |
| `JRN-2` | The kind is a badge symbol, not text appended to the timestamp. |
| `JRN-3` | Mood and theme are menu chips that wrap; nothing scrolls horizontally. |
| `JRN-4` | The editor is a `ScrollView` that keeps the text above the keyboard and dismisses it interactively. |
| `JRN-5` | Section 13.2: no bottom-inset literals; the list and the detail inset under the tab bar by themselves. |
| `JRN-6` | The Date and Day rows are gone; the date is one caption line. |
| Observation "raw ISO dates" | Day section headers and the full date on the detail and editor; no key is displayed. |
| Observation "mood captured but never displayed" | Mood shows on the row and the detail. |
| Observation "empty states are a grey sentence in a pill" | Section 9. |
| Not captured: the lock gate | Section 7, shown on the prototype via its Locked toggle. |
| Not captured: the retro sheet | Replaced by the retro kind of the editor (section 8). |

## 13. Acceptance floor

Section 11 of the design system applies. Specific to the Journal:

- Dynamic Type through AX3. On the prototype the compact rows stacked as specified and the list scrolled clear of the tab bar and the New note button. The "Unsaved drafts" row broke as "Un-saved" because the system `Label` keeps its icon beside the text; at accessibility sizes that row drops the icon (`.labelStyle(.titleOnly)`), per design-system rule 3.2.
- `de` on the prototype: the tab labels, section headers, filter summary and chips fit at the default size. `bg` is unchecked and the build measures it, especially "Weekly reviews" and "Focus notes" in the filter menu and the chips at AX3.
- Every icon-only control has a title: New note, Filter, and the kind badge's label.
- Light and dark; the filter symbol is monochrome in both, and "Clear" is tappable text in `accentInk`, which reads in light.
- Reduce Motion: nothing custom animates. The Theme menu and the pre-fill change without animation.
- VoiceOver: a row reads as one element; the read detail's text is reachable and selectable; "Suggested" is read with the theme; nothing private is in the accessibility tree while locked.
- The prototype uses sample data and validates layout only. The build tests the real repository paging, filters against SwiftData predicates, versions after a real two-device conflict, lock transitions, draft recovery, the Theme pre-fill on an eligible device and all seven localisations on iOS 26.0.
