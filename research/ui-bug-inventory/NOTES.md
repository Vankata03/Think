## Today (default, en, light)
- Scroll-under: quote card text passes under the inline nav bar with no material/blur, glyphs cut mid-height. today-scrolled-def-en-light.png
- Ghost text bleeds through the leading circular Journal button (custom chrome, not a toolbar item). today-scrolled-def-en-light.png
- Custom circular header buttons sit above the large title instead of toolbar items; inline title collides with them on scroll.
- "Nothing logged yet today." row: low-contrast olive text on light ground, chevron with no affordance.
- Question-of-the-day CTA sits under the Liquid Glass tab bar at rest (unscrolled). today-def-en-light.png

## Practice detail (default, en, light)
- Flat text stack, no sections or cards; quote, Question, Today's move, feedback all one column. practice-detail-def-en-light.png
- "Try this again" primary button hugs its label and sits left-aligned, while Today uses full-width pills: inconsistent action styling.
- Feedback chips ("I tried the action", "Less like this in suggestions") are content-width pills of unequal length, ragged right edge.
- No trailing margin/section separation before the tab bar; long content would scroll under the glass bar.

## Paths list (default, en, light)
- Three different leading insets on one screen: large title ~17pt, cards ~21pt, "In development" row ~28pt. paths-def-en-light.png
- ~150pt of empty space between status bar and the large title (empty toolbar reserve).
- "In development" row is bare text + chevron, no row background or separator; reads as decoration, not a control.
- Card header glyphs (crosshair, bulb) and trailing status glyphs (arrow, lock) differ in weight and optical size; arrow is gray, lock is gray, accent only on the leading glyph.
- Gap between card icon and title is larger than the gap between title and subtitle: uneven vertical rhythm.

## Path detail — Deep focus (default, en, light)
- Progress wording contradicts the list card: detail says "1 of 21 days", Paths card says "Day 2 of 21". pathdetail-def-en-light.png
- Custom circular back button instead of the native navigation-bar back item; inline title centred against it.
- Two competing CTAs stacked: content-width tinted pill "Focus for 10 min" over full-width filled "Mark day complete" — different widths, radii and weights, unclear hierarchy.
- "A smaller version" is a text link with a chevron inside the card, styled like neither a button nor a list row.
- "All days" / "Practice runs" are accent-coloured text rows with black chevrons, no separators or row background; colour pairing inconsistent with the rest of the screen.
- Progress bar sits hard against the screen edges, wider inset than the card below it.
- OVERLAP: expanding "All days" draws Day 3 directly behind the floating glass tab bar (unreadable) and Day 4 below it; the day list has no bottom safe-area inset. pathdetail-alldays-def-en-light.png
- Day rows are accent-coloured text with circle/check glyphs, no separators, inset ~21pt while the collapsed header sits at the same inset as the card — rows read as free-floating text.
- 21 day rows render as identical accent-coloured text lines with no separators, no chevrons and no locked/available state; the list is indistinguishable from static text. pathdetail-alldays-scrolled-def-en-light.png
- Content scrolls under the navigation bar with only a hairline, leaving ghosted glyphs behind the bar.

## Focus (default, en, light)
- "Session duration" card is clipped by the floating tab bar at rest; its title is half-hidden. focus-def-en-light.png
- Custom circular header buttons (bulb, stats) again instead of toolbar items; inline title centred between them.
- Mixed alignment on one screen: left-aligned title block, centred timer, centred all-caps "FOCUS CUE" + centred serif quote, left-aligned text field.
- "0 today" pill sits on the title's trailing edge with no baseline relationship to either title or subtitle.
- Custom white rounded text field rather than a system field; placeholder has a decorative accent glyph with no label.
- Palette drift: Session duration card uses a system green dot for "Break" next to the accent dot for "Focus". focus-scrolled-def-en-light.png
- Session duration row ends in a bare up/down chevron glyph with no visible label or hit-area boundary.
- Ghost glyphs bleed through the navigation bar when the timer screen scrolls.

## Profile (default, en, light)
- Three names for one screen: tab "Profile", nav title "Profile", large title "Your practice". profile-def-en-light.png
- Two row idioms mixed: icon + title + subtitle + chevron cards (Journal, Saved lines) vs accent-text cards with no chevron (Find a practice, Weekly review, Settings).
- Section header "PROGRESS" is all-caps; iOS 26 grouped lists use title case.
- Cards inside cards: bordered stat tiles nested in the progress card; tile number and label are left-aligned to the number, not to the icon.
- Vertical gaps between cards are uneven (Journal to Saved lines is tighter than Saved lines to Find a practice).
- "Path days completed 1" shows a bare progress bar with no total or unit.

## Settings (default, en, light)
- Hand-rolled card list imitating a Form: row separators start at ~38pt while row text starts at ~61pt, so separators cut under the icons. settings-def-en-light.png
- Footnote insets disagree: the "Lock journal" footnote is centred/indented to ~67pt, the "Show intention" footnote starts at ~45pt.
- All-caps section headers ("SETTINGS", "PRIVACY"); iOS 26 uses title case.
- iCloud card stacks three type sizes (title, status, body) with the icon optically centred against the whole block instead of the title.
- Icon vocabulary mixes outline and filled symbols in the same column (bell, moon, clipboard, lock outline vs filled Lock Screen rectangle).
- Privacy card and the destructive "Delete all data" row sit behind the floating tab bar.
- Row affordances inconsistent: "Export journal" has a chevron, "Delete all data" none, and the Feedback rows that leave the app (Rate Think, Help & Support, Privacy Policy) carry no chevron or external-link glyph. settings-scrolled-def-en-light.png
- Destructive row uses raw system red against the brand palette.
- Settings ends with no About/version row; the build version appears nowhere in the UI.

## Journal — empty state (default, en, light)
- Empty state is a white pill with one line of grey text; no symbol, title or action button (no ContentUnavailableView). journal-empty-def-en-light.png
- Insets disagree within the header: "Entries" and the filter chips start at ~36-37pt, the empty-state card at ~17pt.
- "All" sort control is accent text plus a bare up/down chevron with no label or bounded hit area.
- Filter chips ("Any mood", "Any time") are tinted pills with leading glyphs; the same idiom is used for feedback actions on practice detail, so chip = filter and chip = action both exist.
- Custom circular "+" and back buttons instead of navigation-bar items.

## Journal editor — New note (default, en, light)
- CLIPPING: the mood chip row is horizontally scrollable but the fourth chip is cut flush at the card edge with no fade or partial-peek affordance. journal-editor-def-en-light.png
- Date renders as ISO "2026-09-16" instead of a localized date string.
- Mood chips are neutral grey while filter chips on the Journal list are accent-tinted: same shape, two meanings, two colours.
- Helper text "Drafts stay on this device..." is wrapped in its own card; elsewhere the same kind of text is a bare footnote.
- Disabled "Save" reads only as grey text in a glass pill; no other disabled affordance.
- With the keyboard up the editor card is cut flush by the keyboard: its bottom corners are square and no scroll or keyboard toolbar (no Done) is offered. journal-editor-typing-def-en-light.png

## Journal list — one entry (default, en, light)
- Metadata line runs "Sep 16, 2026 at 2:45 PM  Note": the entry-kind tag is separated only by a double space, with no badge, dot or colour. journal-list-def-en-light.png
- "1 of 1 shown" footer sits at a third inset (~33pt) against the card (~17pt) and the chips (~37pt).
- Entry card shows three lines of body with no truncation indicator and no mood shown even though mood is a first-class field in the editor.

## Journal detail (default, en, light)
- Metadata card shows the same timestamp twice in two formats: "Date  September 16, 2026 at 2:45 PM" and "Day  2026-09-16" (raw ISO). journal-detail-def-en-light.png
- Mood is captured in the editor but never displayed in the detail view.
- Body sits in a bare card with no title, byline or entry-kind marker; the kind only appears as the nav title.
- Trailing "..." menu is a custom circular button, not a navigation-bar menu item.

## AX3 pass (accessibility-extra-large, en, light)
### Journal detail
- Body text runs under the floating tab bar; the final line ("out.") is hidden behind it. journal-detail-ax3-en-light.png
- "Date"/"Day" rows stack label over value at AX3 but keep the row separator, so the card reads as four rows of unequal weight.
### Practice detail
- Body text passes straight under the floating tab bar; "it takes two minutes, then do it." is half overlapped and half hidden. practice-detail-ax3-en-light.png
- Inline title "Saved practice" loses centring and butts against the custom circular back button; the trailing heart/share pill grows and crowds the title.
### Today
- "Mark the move done" button is overlapped by the tab bar; its label renders through the glass. today-ax3-en-light.png
- Quote-card action glyphs (info, heart, share) stay at default size while all text scales, so the action row looks undersized and drifts right.
### Path detail
- "Focus for 10 min" wraps to two lines inside a content-hugging pill, producing a lopsided capsule next to the full-width primary button. pathdetail-ax3-en-light.png
- Day rows wrap to two lines with the status circle top-aligned to the first line only; "Day 2 - One thing" is overlapped by the tab bar.
### Focus
- The timer ring is not drawn at AX3; only the "25:00" label and caption remain, so the dial disappears. focus-ax3-en-light.png
- Header stack breaks: "0 today" drops to its own line and the title/subtitle scroll under the navigation bar as ghosts.
- Start / reset / skip controls are pushed below the fold behind the tab bar; the primary action is not reachable without scrolling.
### Profile
- Stat tiles stack at AX3 but the icon stays optically centred on the tile while the number sits above a wrapped label, so icon and number no longer share a baseline. profile-ax3-en-light.png
- "Saved lines" card is overlapped by the tab bar.
- "PROGRESS" header at AX3 is nearly as large as the card titles, flattening the hierarchy.
### Settings
- The Appearance segmented control does not scale with Dynamic Type: Auto/Light/Dark stay at default size while every label around them grows. settings-ax3-en-light.png
- iCloud card: the icon is vertically centred against a nine-line text block, ending up beside the middle of the body copy and far from the title it belongs to.
- "Daily line notification" row is overlapped by the tab bar.
### Profile (continued)
- "Saved lines" card at AX3: the title overhangs the icon column while the icon stays centred against the wrapped subtitle. profile-ax3-en-light.png

## Dark appearance (default, en)
### Settings
- Accent shifts from olive in light to saturated yellow in dark; the two do not read as the same brand colour. settings-def-en-dark.png
- Background is pure black behind near-black cards, so card edges are only visible by a faint hairline.
- Off toggles are black-on-dark-grey and read as disabled rather than off.
- The destructive "Delete all data" row still sits under the tab bar.
### Today
- Secondary pill "Mark the move done" becomes muddy dark olive with yellow text; contrast against the card is weak. today-def-en-dark.png
- "1 logged today" is dim olive on black, the lowest-contrast text on the screen.
- Quote-card glyph tints disagree: info and heart render grey, share renders accent, in both appearances.

## Bulgarian (default, light)
### Today
- Layout holds; the long primary label "Отбележи хода като изпълнен" fits one line, and the Question card CTA is still clipped by the tab bar as in en. today-def-bg-light.png
### Settings
- Three rows wrap to two lines in bg; wrapped rows keep the toggle vertically centred but the leading icon top-aligned, so icon/label/toggle sit on three different axes. settings-def-bg-light.png
- Privacy card is again cut by the tab bar, with "Изтрий всички данни" drawn below it.
### Profile
- Long bg labels fit, but the stat tiles ("Текуща серия", "Сесии за фокус") nearly touch their tile edges with no room left for de.

## German (default, light)
### Focus
- "Deep Work" stays untranslated as both the title and the timer caption while everything around it is German. focus-def-de-light.png
- Same tab-bar clipping of the "Sitzungsdauer" card as in en.
### Settings
- Same three wrapped rows as bg; icons top-align while toggles centre. settings-def-de-light.png
- Privacy card cut by the tab bar with "Alle Daten löschen" drawn below it.
### Settings at AX3 (de)
- "iCloud-Synchronisierung" hyphen-breaks across three lines and the status line "Nicht bei iCloud angemeldet" runs into the body text with no spacing, so status and description read as one paragraph. settings-ax3-de-light.png
- Section header "EINSTELLUNGEN" is clipped by the tab bar.

## Streak sheet (default, en, light)
- Sheet is presented at full height with the content top-weighted; roughly the bottom third is empty and there is no grabber or medium detent. streak-sheet-def-en-light.png
- Header "1 / streak" puts a large number next to a lowercase caption with no shared baseline, at a 21pt inset while the calendar card sits at 17pt.
- Weekday initials are single letters (S M T W T F S) in grey, with duplicate letters and no locale-aware two-letter option.
- Only action is a tinted "Share your streak" pill, so the sheet's primary action looks secondary.

## Focus stats (default, en, light)
- With no data the chart renders as ~380pt of empty dashed gridlines and date labels, with no empty state. focusstats-def-en-light.png
- Section headers here are grey title case ("This week", "Session history") while Profile and Settings use all-caps: two header styles in one app.
- A navigation row ("Weekly review" with chevron) sits inside the same card as the stat rows and the chart, mixing data and navigation.
- Session-history footnote is cut by the tab bar.

## Weekly review (default, en, light)
- Both text inputs are bare placeholders on the card with no field background, border or separator; the first input's empty area is an unexplained ~120pt gap. weeklyreview-def-en-light.png
- "Save weekly review" is a content-width grey pill left-aligned inside the card, unlike the full-width primary buttons elsewhere.
- Navigation rows ("This week", "Mood this week") are mixed into stat cards.
- Header "Your reflection" is grey title case, a third header style alongside the all-caps and plain styles used elsewhere.

## Find a practice / discovery (default, en, light)
- Suggestion rows are serif quotes of one to three lines with grey chevrons; row heights vary widely, so the list has no vertical rhythm. practicediscovery-def-en-light.png
- Rows carry no theme or length metadata even though the screen filters by theme and length.
- Row separators are inset to the text on the left but run to the card edge on the right.
- The list draws behind and below the tab bar; the last rows are unreadable.

## Achievements sheet (default, en, light)
- The medium detent cuts the third tile mid-row and a floating "Scroll for more" chip is drawn on top of it. achievements-def-en-light.png
- Each tile repeats its section name ("7 / Streak / Locked" under a "Streak" header).
- Every medal uses the same grey art, so tiers are indistinguishable; locked state is conveyed only by the word "Locked".

## Saved lines — empty (default, en, light)
- Same single-pill empty state as Journal: one grey sentence, no symbol, title or action, and no hint of how to save a line. savedlines-empty-def-en-light.png

## Onboarding (default, en, light)
### Page 1
- Progress is a custom pill-plus-dots indicator top-left with a plain grey "Skip" top-right; neither is a toolbar item and the two do not share a baseline. onboarding1-def-en-light.png
- Feature rows: symbols differ in optical size and are top-aligned to the title while rows with two-line subtitles create uneven vertical gaps.
### Page 2
- Card row separator is inset to the label on the left but stops at the toggle on the right, so it aligns with neither card edge. onboarding2-def-en-light.png
- Footnote says the switches can be changed "in Profile", but they live one level deeper, in Profile > Settings.
### Page 3
- "Skip" disappears on the last page while the indicator stays, so the header changes shape between pages. onboarding3-def-en-light.png
- Roughly 280pt of empty space sits between the content card and the bottom button; the three pages have very different content heights with no shared layout anchor.

## Focus — running session (default, en, light)
- The progress ring shows only a small lozenge marker at the top; no arc fills as the session runs, so elapsed progress is unreadable. focus-running-def-en-light.png
- The "FOCUS CUE" block disappears once the session starts, shifting every control below it upward.
- The notification permission alert is requested at first session start, interrupting the timer that was just started.
