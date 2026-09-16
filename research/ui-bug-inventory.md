# UI bug inventory — Think iOS

Ticket: [Task: UI bug inventory of every iOS screen](https://github.com/Vankata03/Think/issues/70)
Map: [Wayfinder map: Think UI redesign](https://github.com/Vankata03/Think/issues/68)

## Method

- Build: `Think` scheme, Debug, from `develop` at `462eb70`, run on the iPhone 17 simulator (iOS 26, 402x874pt).
- Configurations exercised: default Dynamic Type and AX3 (`accessibility-extra-large`); `en`, `bg`, `de`; light and dark. Locales were switched by relaunching with `-AppleLanguages`/`-AppleLocale`; text size and appearance with `xcrun simctl ui`.
- Every screen was walked at default / en / light first. AX3 and the other locales were then run over the screens that carry the most text or the most layout logic (Today, practice detail, path detail, Focus, Profile, Settings, Journal), because those are where wrapping and overlap surface; dark was sampled on Today and Settings, which between them cover every colour role in the app.
- Screenshots live next to this file in `research/ui-bug-inventory/`, named `<screen>-<size>-<locale>-<appearance>.png`. `NOTES.md` in that folder holds the raw per-screen capture notes.
- Measurements quoted in points are read off the screenshots (image pixels x 402/920).

## Coverage

Captured: onboarding (3 pages), Today (rest and scrolled), practice detail, Paths list, path detail (collapsed, All days expanded, scrolled), Focus (idle, running, scrolled), Focus stats, Weekly review, Profile, Settings (two screens' worth of scroll), Journal (empty, editor, editor with keyboard, list, detail), Saved lines (empty), Find a practice, Streak sheet, Achievements sheet.

Not captured, and why: the Journal lock gate (needs Face ID enrolment plus the Lock journal toggle), the evening retrospective sheet (fires on a schedule), the focus session-complete and session-detail screens (need a completed 25-minute session), achievement unlock and share sheets (need a milestone and the system share sheet), and the Watch app and widgets (out of this ticket's scope; widgets have their own ticket). These are the gaps a screen brief for Journal, Focus or Today should close by hand.

## Bugs by class

Classes are the three the ticket names: **spacing**, **clipping/overlap**, **alignment**. `size` is `default` or `AX3`.

| ID | Screen | Size | Locale | Appearance | Class | Description | Screenshot |
|----|--------|------|--------|------------|-------|-------------|------------|
| TOD-1 | Today | default | en | light | clipping | The Question-of-the-day CTA sits under the floating glass tab bar at rest, before any scrolling. | `today-def-en-light.png` |
| TOD-2 | Today | default | en | light | clipping | Card text scrolls under the inline navigation bar with no material behind it; glyphs are cut mid-height and ghost through the leading circular button. | `today-scrolled-def-en-light.png` |
| TOD-3 | Today | AX3 | en | light | clipping | "Mark the move done" is overlapped by the tab bar; its label reads through the glass. | `today-ax3-en-light.png` |
| TOD-4 | Today | AX3 | en | light | alignment | Quote-card action glyphs (info, heart, share) do not scale with Dynamic Type, so the action row is undersized relative to the text it belongs to. | `today-ax3-en-light.png` |
| PRA-1 | Practice detail | default | en | light | alignment | "Try this again" hugs its label and is left-aligned, while the same action class on Today is a full-width pill. | `practice-detail-def-en-light.png` |
| PRA-2 | Practice detail | default | en | light | spacing | Feedback chips are content-width pills of unequal length with a ragged right edge and no grid. | `practice-detail-def-en-light.png` |
| PRA-3 | Practice detail | AX3 | en | light | clipping | Body text runs under the tab bar; the last line of "Today's move" is half overlapped and half hidden. | `practice-detail-ax3-en-light.png` |
| PRA-4 | Practice detail | AX3 | en | light | alignment | The inline title loses centring and butts against the custom circular back button while the trailing heart/share pill grows into it. | `practice-detail-ax3-en-light.png` |
| PTH-1 | Paths list | default | en | light | alignment | Three leading insets on one screen: large title ~17pt, cards ~21pt, "In development" row ~28pt. | `paths-def-en-light.png` |
| PTH-2 | Paths list | default | en | light | spacing | ~150pt of empty space between the status bar and the large title, from an empty toolbar reserve. | `paths-def-en-light.png` |
| PTH-3 | Paths list | default | en | light | spacing | Inside each card the icon-to-title gap is larger than the title-to-subtitle gap, so the block reads as two detached pieces. | `paths-def-en-light.png` |
| PDT-1 | Path detail | default | en | light | clipping | Expanding "All days" draws Day 3 directly behind the tab bar and Day 4 below it: the day list has no bottom safe-area inset. | `pathdetail-alldays-def-en-light.png` |
| PDT-2 | Path detail | default | en | light | alignment | Two stacked CTAs with different widths, radii and weights ("Focus for 10 min" content-width tinted, "Mark day complete" full-width filled). | `pathdetail-def-en-light.png` |
| PDT-3 | Path detail | default | en | light | alignment | The progress bar runs to a wider inset than the card beneath it. | `pathdetail-def-en-light.png` |
| PDT-4 | Path detail | default | en | light | clipping | Content scrolls under the navigation bar leaving ghosted glyphs behind the bar. | `pathdetail-alldays-scrolled-def-en-light.png` |
| PDT-5 | Path detail | AX3 | en | light | alignment | "Focus for 10 min" wraps to two lines inside a content-hugging pill, producing a lopsided capsule; day rows wrap with the status circle aligned only to the first line. | `pathdetail-ax3-en-light.png` |
| PDT-6 | Path detail | AX3 | en | light | clipping | "Day 2 — One thing" is overlapped by the tab bar. | `pathdetail-ax3-en-light.png` |
| FOC-1 | Focus | default | en | light | clipping | The "Session duration" card is clipped by the tab bar at rest; its title is half hidden. | `focus-def-en-light.png` |
| FOC-2 | Focus | default | en | light | alignment | Four alignments on one screen: left-aligned title block, centred timer, centred all-caps cue label and serif quote, left-aligned text field. | `focus-def-en-light.png` |
| FOC-3 | Focus | default | en | light | alignment | The "0 today" pill sits on the title's trailing edge with no baseline relationship to the title or the subtitle. | `focus-def-en-light.png` |
| FOC-4 | Focus | AX3 | en | light | clipping | The timer ring is not drawn at AX3; only the time label and caption remain. | `focus-ax3-en-light.png` |
| FOC-5 | Focus | AX3 | en | light | clipping | Start / reset / skip are pushed below the fold behind the tab bar, so the primary action needs a scroll to reach. | `focus-ax3-en-light.png` |
| FOC-6 | Focus | AX3 | en | light | clipping | The title and subtitle scroll under the navigation bar as ghosts and "0 today" drops onto its own line. | `focus-ax3-en-light.png` |
| FOC-7 | Focus (running) | default | en | light | alignment | The progress ring shows only a small marker lozenge at the top; no arc fills, so progress is unreadable. | `focus-running-def-en-light.png` |
| FOC-8 | Focus (running) | default | en | light | spacing | The cue block disappears when the session starts, shifting every control below it upward. | `focus-running-def-en-light.png` |
| FST-1 | Focus stats | default | en | light | spacing | With no data the chart is ~380pt of empty dashed gridlines and date labels, with no empty state. | `focusstats-def-en-light.png` |
| FST-2 | Focus stats | default | en | light | clipping | The session-history footnote is cut by the tab bar. | `focusstats-def-en-light.png` |
| PRO-1 | Profile | default | en | light | spacing | Gaps between cards are uneven: Journal-to-Saved-lines is tighter than Saved-lines-to-Find-a-practice. | `profile-def-en-light.png` |
| PRO-2 | Profile | default | en | light | alignment | Stat tiles are cards nested inside a card, and the tile number aligns to the label rather than to the icon. | `profile-def-en-light.png` |
| PRO-3 | Profile | AX3 | en | light | alignment | Stat tiles stack, but the icon stays optically centred while the number sits above a wrapped label, breaking the shared baseline. | `profile-ax3-en-light.png` |
| PRO-4 | Profile | AX3 | en | light | clipping | The "Saved lines" card is overlapped by the tab bar; its title also overhangs the icon column. | `profile-ax3-en-light.png` |
| SET-1 | Settings | default | en | light | alignment | Row separators start at ~38pt while row labels start at ~61pt, so separators cut under the icons. | `settings-def-en-light.png` |
| SET-2 | Settings | default | en | light | alignment | Footnote insets disagree: the "Lock journal" footnote is indented to ~67pt, the "Show intention" footnote starts at ~45pt. | `settings-def-en-light.png` |
| SET-3 | Settings | default | en | light | alignment | In the iCloud card the icon is optically centred against the whole text block instead of the title it labels. | `settings-def-en-light.png` |
| SET-4 | Settings | default | en | light | clipping | The Privacy card, including the destructive "Delete all data" row, sits behind the tab bar. | `settings-def-en-light.png` |
| SET-5 | Settings | default | bg | light | alignment | Wrapped two-line rows put the icon on the first line, the label across two and the toggle centred: three different vertical axes. | `settings-def-bg-light.png` |
| SET-6 | Settings | default | de | light | clipping | Same Privacy-card clipping in de, with "Alle Daten löschen" drawn below the tab bar. | `settings-def-de-light.png` |
| SET-7 | Settings | AX3 | en | light | clipping | The Appearance segmented control does not scale with Dynamic Type; its labels stay at default size. | `settings-ax3-en-light.png` |
| SET-8 | Settings | AX3 | de | light | spacing | The iCloud status line runs into the body text with no spacing, so status and description read as one paragraph; the title hyphen-breaks over three lines. | `settings-ax3-de-light.png` |
| SET-9 | Settings | AX3 | en | light | clipping | The first toggle row is overlapped by the tab bar. | `settings-ax3-en-light.png` |
| JRN-1 | Journal list | default | en | light | alignment | Header insets disagree: "Entries" and the filter chips at ~36-37pt, the content card at ~17pt, the "1 of 1 shown" footer at ~33pt. | `journal-empty-def-en-light.png`, `journal-list-def-en-light.png` |
| JRN-2 | Journal list | default | en | light | alignment | The entry-kind tag is appended to the timestamp with a double space and no badge, dot or colour. | `journal-list-def-en-light.png` |
| JRN-3 | Journal editor | default | en | light | clipping | The mood chip row scrolls horizontally but the fourth chip is cut flush at the card edge with no fade or peek. | `journal-editor-def-en-light.png` |
| JRN-4 | Journal editor | default | en | light | clipping | With the keyboard up the editor card is cut flush by the keyboard, square-cornered, with no keyboard toolbar or scroll. | `journal-editor-typing-def-en-light.png` |
| JRN-5 | Journal detail | AX3 | en | light | clipping | Body text runs under the tab bar; the final line is hidden behind it. | `journal-detail-ax3-en-light.png` |
| JRN-6 | Journal detail | AX3 | en | light | alignment | "Date"/"Day" rows stack label over value but keep the row separator, so one row reads as two. | `journal-detail-ax3-en-light.png` |
| DIS-1 | Find a practice | default | en | light | spacing | Suggestion rows run one to three lines with no minimum height, so the list has no vertical rhythm. | `practicediscovery-def-en-light.png` |
| DIS-2 | Find a practice | default | en | light | alignment | Separators are inset to the text on the left but run to the card edge on the right. | `practicediscovery-def-en-light.png` |
| DIS-3 | Find a practice | default | en | light | clipping | The list draws behind and below the tab bar; the last rows are unreadable. | `practicediscovery-def-en-light.png` |
| WKR-1 | Weekly review | default | en | light | spacing | The first reflection input leaves a ~120pt empty area with no field chrome to explain it. | `weeklyreview-def-en-light.png` |
| WKR-2 | Weekly review | default | en | light | alignment | "Save weekly review" is a content-width pill left-aligned inside the card, unlike the app's full-width primary buttons. | `weeklyreview-def-en-light.png` |
| STK-1 | Streak sheet | default | en | light | spacing | The sheet is full height with top-weighted content; the bottom third is empty and there is no medium detent. | `streak-sheet-def-en-light.png` |
| STK-2 | Streak sheet | default | en | light | alignment | The large streak number and its lowercase caption share no baseline, and the header sits at 21pt while the calendar card sits at 17pt. | `streak-sheet-def-en-light.png` |
| ACH-1 | Achievements sheet | default | en | light | clipping | The detent cuts the third tile mid-row and a floating "Scroll for more" chip is drawn on top of it. | `achievements-def-en-light.png` |
| ONB-1 | Onboarding p1 | default | en | light | alignment | The page indicator (top-left) and "Skip" (top-right) share no baseline and are not toolbar items. | `onboarding1-def-en-light.png` |
| ONB-2 | Onboarding p1 | default | en | light | spacing | Feature-row symbols differ in optical size and rows with two-line subtitles create uneven vertical gaps. | `onboarding1-def-en-light.png` |
| ONB-3 | Onboarding p2 | default | en | light | alignment | The card separator is inset to the label on the left and stops at the toggle on the right, matching neither edge. | `onboarding2-def-en-light.png` |
| ONB-4 | Onboarding p3 | default | en | light | spacing | ~280pt of dead space between content and the bottom button; the three pages share no layout anchor, and "Skip" vanishes on the last page. | `onboarding3-def-en-light.png` |

## Cross-cutting patterns

1. **The floating tab bar has no content inset anywhere.** TOD-1, TOD-3, PDT-1, PDT-6, FOC-1, FOC-5, FST-2, PRO-4, SET-4, SET-6, SET-9, JRN-5 and DIS-3 are the same defect on thirteen screens. One fix — a safe-area inset (or a real `List`/`ScrollView` that respects the bar) applied at the container level — closes all of them.
2. **Custom circular chrome instead of toolbar items.** Every screen draws its own circular back / add / menu / streak buttons above or beside the title. This is what produces the ghost text behind the bar (TOD-2, PDT-4, FOC-6) and the AX3 title collision (PRA-4). It also contradicts the standing preference for native iOS 26 chrome.
3. **Insets are decided per view.** 17pt, 21pt, 28pt, 33pt, 36pt, 38pt and 61pt all appear as leading insets. PTH-1, JRN-1, SET-1, SET-2 and STK-2 are instances of one missing spacing token.
4. **Buttons have no shared spec.** Full-width filled, full-width tinted, content-width tinted, content-width grey-disabled and bare text-plus-chevron all act as primary actions (PRA-1, PDT-2, WKR-2, ONB-4).
5. **Nothing but text scales at AX3.** Glyphs (TOD-4), the segmented control (SET-7) and the timer ring (FOC-4) keep fixed metrics, so layouts break rather than reflow.

## Other observations for the screen briefs

Not spacing, clipping or alignment, but recorded because a brief will have to decide them:

- Three names for one screen: tab "Profile", nav title "Profile", large title "Your practice".
- Section headers come in three styles: all-caps grey (Profile, Settings), title-case grey (Focus stats, Weekly review), and none at all (Today, Paths).
- Row affordances are inconsistent: chevron, no chevron, and accent-text-only rows all navigate; external links (Rate Think, Help & Support, Privacy Policy) carry no marker.
- Empty states are a single grey sentence in a white pill (Journal, Saved lines) with no symbol, title or action.
- Palette drift: a system green dot for "Break" on Focus, raw system red for destructive rows, grey info/heart glyphs beside an accent share glyph, and an accent that shifts from olive (light) to saturated yellow (dark) without reading as one colour.
- Dark mode puts near-black cards on a pure black ground, leaving card edges visible only by a hairline; off toggles read as disabled.
- Progress language disagrees between screens: the Paths card says "Day 2 of 21", path detail says "1 of 21 days".
- Journal shows raw ISO dates ("2026-09-16") in the editor and again as a second "Day" row in the detail view, next to a localized "Date" row; mood is captured but never displayed.
- German leaves "Deep Work" untranslated as both the Focus title and the timer caption.
- Settings has no About or version row; the build version appears nowhere in the UI.
- The notification permission alert is requested at first focus-session start, interrupting the session the user just started.
- Not verified in this pass: accessibility labels on the icon-only controls (the simulator's accessibility inspection was unavailable during the sweep). Each brief's acceptance floor still has to check them by hand or by UI test.
