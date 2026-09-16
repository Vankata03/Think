# Visual language for a calm reflection app

Research for [Black surfaces: where near-black and extra yellow earn a place](https://github.com/Vankata03/Think/issues/84) on the [Think UI redesign map](https://github.com/Vankata03/Think/issues/68), 2026-09-16. Prompted by the owner rejecting the black-and-yellow direction (the saturated yellow, stacked grouped cards, near-black cards on black) and naming Stoic, Waking Up, Apple Journal and Apple Books as references.

Sources are primary where marked (Apple HIG pages, App Store listings and their official screenshots). Contrast ratios are computed by me with the WCAG 2 formula from the hex values stated; system colour values are the documented UIKit defaults and the HIG says not to hard-code them.

## Recommendations

1. **Plain background, not grouped.** Content sits on `systemBackground`; sections are plain rows with separators and section headers, not stacked inset boxes. Grouped is for settings-type screens (HIG `color.md` tells apps to use the grouped set "when you have a grouped table view; otherwise, use the system set"). Stoic, Journal and Books all keep the reading surface plain and reserve cards for discrete items (entries, books, tools).
2. **One lifted surface per screen at most.** In dark, depth comes from Apple's base/elevated pair (`#000000` base, `#1C1C1E` elevated; `secondarySystemBackground` `#1C1C1E`/`#2C2C2E`) plus hairline separators, never from a custom near-black on black.
3. **Retire the saturated yellow inside the app.** `#FFD433` stays in the app icon. In the UI the identity colour becomes a gold that reads as ink in light and as a warm highlight in dark: light ink `#7A6208` (5.9:1 on white), dark ink `#D4AF37` (10.0:1 on black, 8.1:1 on `#1C1C1E`). Fills use the same values with black ink on top (10.0:1). Three palettes below; the cool alternative is a sage.
4. **Type carries the identity.** New York (`Font.Design.serif`) for every quoted line and lesson, SF for everything else. Books does this; Stoic uses one grotesk and no accent at all and still reads as branded, which shows how little colour a calm app needs.
5. **No decoration.** No yellow rules, capsules, or section symbols in colour. Stoic's home screen has no accent colour anywhere; Journal's only colour is the purple `+`; Waking Up spends its one accent (teal) on the "Day 4 of 28" progress line. One accent, one job.

## 1. Apple Journal and Apple Books

- Journal, App Store listing (https://apps.apple.com/us/app/journal/id6447391597), official screenshot "iPhone_0_Hero": large title "All Entries" on a near-white plain background, entries as white cards with continuous corners and no border, date headers "Today"/"Yesterday" as plain bold text, toolbar items as glass circles (back) and a glass capsule (search, more), a single purple floating `+`. No other colour. Type: SF only. *(primary: Apple's own screenshot)*
- Books, App Store listing (https://apps.apple.com/us/app/apple-books/id364709193), official screenshots "Wrapper1/2": the player takes its background tint from the cover art; controls are white on a warm grey; type is SF for chrome, serif appears only inside book content and covers. Reading surface plain. *(primary)*
- HIG `color.md › System colors`: "use the grouped background colors … when you have a grouped table view; otherwise, use the system set" and "Primary for the overall view, Secondary for grouping content … Tertiary for grouping … within secondary elements". (https://developer.apple.com/design/human-interface-guidelines/color)

## 2. Stoic and Waking Up

- Stoic (https://apps.apple.com/us/app/stoic-journal-mental-health/id1312926037), screenshots 2 and 3: off-white `≈#F2F2F2` background, black grotesk type, white tool cards with large radius and no border, lowercase greeting "good morning." as the only display moment, quote of the day as white text over a photograph. No accent colour; the palette is black, white, grey and the photo. Editors' Choice text on the page calls it "an elegantly designed journaling app". *(primary)*
- Waking Up (https://apps.apple.com/us/app/waking-up-guided-meditation/id1307736395), screenshot 1: deep navy gradient background (not black), one lifted card in a lighter translucent navy with a hairline edge, "Day 4 of 28" in a teal accent, everything else white and grey. Rows separated by hairlines, no boxes inside the card. *(primary)*
- Both apps: one display type moment per screen, everything else body size; progress shown as a short line of text, not a ring.

## 3. iOS 26 HIG facts that bind the redesign

- Dark elevation: "the system uses two sets of background colors — called base and elevated — to enhance the perception of depth … Prefer the system background colors … Using a custom background color can make it harder for people to perceive these system-provided visual distinctions." HIG `dark-mode.md › Platform considerations › iOS, iPadOS`. (https://developer.apple.com/design/human-interface-guidelines/dark-mode)
- Contrast: "make sure the contrast ratio between colors is no lower than 4.5:1. For custom foreground and background colors, strive for a contrast ratio of 7:1, especially in small text." Same page, `Dark Mode colors`.
- Colour meaning: "Avoid using the same color to mean different things … if you use your brand color to indicate that a borderless button is interactive, using the same or similar color to stylize noninteractive text is confusing." HIG `color.md › Best practices`. This rules out yellow section symbols and yellow decorative rules while yellow also marks the primary action.
- Branding: "Ensure branding always defers to content … Aim to incorporate branding in refined, unobtrusive ways". HIG `branding.md › Best practices`. (https://developer.apple.com/design/human-interface-guidelines/branding)
- Serif: "New York (NY) is a serif typeface family designed to work well by itself and alongside the SF fonts"; use `Font.Design.serif`, do not embed. HIG `typography.md`. (https://developer.apple.com/design/human-interface-guidelines/typography)
- Lists: "Prefer displaying text in a list or table … the grouped style uses headers, footers, and additional space to separate groups of data". HIG `lists-and-tables.md › Best practices`, `Style`. Plain style is the default when grouping is not the point.
- Liquid Glass stays on the control layer (tab bar, toolbar items as glass circles and capsules, as Journal's screenshot shows); content never gets glass. Already in `design/design-system.md` section 1.

## 4. Accent candidates (computed contrast)

System dark backgrounds used: base `#000000`, elevated / `secondarySystemBackground` `#1C1C1E`. Light: `#FFFFFF`.

| Palette | Light ink on white | Light fill, black ink | Dark ink on black | Dark ink on `#1C1C1E` | Notes |
| --- | --- | --- | --- | --- | --- |
| **Gold** (recommended) | `#7A6208` 5.9:1 | `#D4AF37` 10.0:1 | `#D4AF37` 10.0:1 | 8.1:1 | Same hue family as the icon, desaturated; ink in light, highlight in dark. |
| Deep ochre | `#5C4A00` 8.6:1 | `#C9A227` 8.7:1 | `#E0B94A` 11.2:1 | `#D9B44A` 8.6:1 | Meets 7:1 in light for small text; darker and more brown. |
| Current (for comparison) | `#6E5C05` 6.6:1 | `#F2C41C` 12.7:1 | `#FFD433` 14.7:1 | — | Fill is 1.7:1 as text on white; loud in dark. |
| **Sage** (cool alternative) | `#4F6B5E` 5.8:1 | `#9FBDA8` 10.3:1 | `#9FBDA8` 10.3:1 | 8.4:1 | Calm, breaks with the icon; would need an icon change to stay coherent. |
| Slate | `#3F5C6B` 7.1:1 | `#8FB3C4` 9.4:1 | `#8FB3C4` 9.4:1 | — | Waking Up territory; reads as another app. |

Ratios computed with the WCAG 2.x relative-luminance formula. Thresholds from HIG `dark-mode.md`: 4.5:1 minimum, 7:1 target for custom colours.

## 5. Depth in dark without black-on-black

- Base `#000000` for the screen, elevated `#1C1C1E` only for a surface that is genuinely lifted (a sheet, the one hero surface if any), `#2C2C2E` for something inside it. HIG `dark-mode.md` (above).
- Hairline `separator` between rows instead of boxes; Waking Up's card does this inside one lifted surface.
- Materials belong to the control layer; HIG `materials.md` and the design system's section 1 already restrict glass to bars.

## Open questions

- Does the app icon change to match a muted gold, or does the icon keep `#FFD433` while the UI uses `#D4AF37`? Apple's own apps let the icon be more saturated than the UI (Journal's icon vs its single purple button).
- Does the hero keep any surface at all in light, or is it the bare page (Books, Stoic quote) with the serif line alone?
- Whether one lowercase display moment (Stoic's "good morning.") fits Think's voice, or the line itself is the only display moment.
