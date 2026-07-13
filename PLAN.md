# Think — product plan

Motivational app for young ambitious people. Not a quote-wallpaper app: every daily line pairs with an action. Pitch: "Stoic gym for your mind."

## Core loop (under 2 minutes)
1. Open app, see daily line.
2. Answer question of the day (1–3 sentence journal entry).
3. Do today's path step (10 min max) or a focus session.
4. Streak grows.

## Features
- **Daily line** — curated, themed rotation. Public-domain sources (Marcus Aurelius, Seneca, Epictetus, proverbs) + original lines. No modern-author quotes (licensing).
- **Question of the day** — private journal answer, stored on device only (privacy is a selling point, no backend cost).
- **Paths** — 21-day tracks: Deep focus, Discipline, Clear thinking, Learning machine (later: Money mindset, Social courage). Each day: ≤200-word lesson + one concrete task. Duolingo structure, Stoic content.
- **Pomodoro (Focus tab)** — 25/5 and 50/10 presets free; custom durations, stats history, ambient sounds = Pro later. Quote shown under the timer. Sessions feed streak and path tasks. Live Activity + Dynamic Island are implemented, including recovery of an existing activity after relaunch.
- **Streak** — gentle, no guilt. Missed day → "Begin again," not shame.
- **Share cards / wallpapers** — same render engine. Quote + template → Instagram story or wallpaper resolution. Weekly wallpaper drop: 2 free, rest Pro. Generator (any quote + style + color) beats static gallery.
- **Feedback** — Profile section: "Share an idea" / "Report a problem" (prefilled mail, app + iOS version in footer) and "Rate Think" (StoreKit review prompt). In-app feedback form once the server exists.
- **Daily line notification** — opt-in, user-chosen time (Profile > Settings). Sliding 8-day window of scheduled local notifications, refreshed on app-active.
- **Later**: phone-synced Watch focus timer, additional paths, StoreKit paywall, and Pro content gating.

## Design principles
- Calm, not hype. Serif for quotes, sans for UI, lots of whitespace. Reference tier: Stoic, Waking Up — not quote-spam apps.
- Brand: black + yellow. Icon is a yellow serif quote mark on near-black; app accent color is the same yellow. Light/dark/tinted icon variants shipped.
- Dark mode day one, plus in-app appearance setting (auto/light/dark).
- 4 tabs: Today, Paths, Focus, Profile (journal lives under Profile/Today).
- No account required; account only when sync ships.

## Monetization — subscription (freemium)
| Tier | Gets | Price |
|------|------|-------|
| Free | Daily line, question, 1 path, streak, basic pomodoro | $0 |
| Pro | All paths, full journal history, widgets, themes, wallpapers, quote categories, custom timer | $4.99/mo or $29.99/yr |
| Lifetime | Everything forever | $79.99 |

- Push annual, 7-day free trial. Lifetime for subscription-haters (~15% of buyers).
- Comparables: Stoic ~$40/yr, Motivation ~$60/yr, Fabulous ~$80/yr.
- Free tier must be genuinely good — bad free tier = bad reviews.

## Distribution
- ASO: "daily motivation", "stoic", "discipline app", "mindset". Screenshots show the quote card.
- Share cards = organic engine (app name in corner).
- TikTok/Shorts/Reels quote videos; build in public on X.

## Tech
- SwiftUI on iOS 26, Swift 6 strict concurrency with MainActor default isolation, `@Observable` state, and `ContinuousClock` timer.
- SwiftData (journal), UserDefaults (streak/progress), StoreKit 2 for subscriptions. No server for MVP.
- Content models (`Quote`, `PathStep`, `ThinkingPath`) are `Codable` — remote content later is a versioned JSON endpoint (static file on a CDN is enough at first; app caches last fetch, bundled content is the offline fallback). No accounts needed for content delivery.
- WidgetKit and ActivityKit are part of the current app surface.

## Build order / progress
- [x] Think 1.1 App Intents foundation: Siri/Shortcuts actions for focus, daily line, and streak; manual-start donation; Control Center focus control
- [x] Concept, design mockups, monetization plan (2026-07-04)
- [x] MVP: Today tab (line + question + journal save), streak, Deep focus path, basic pomodoro, Profile
- [x] Share cards / wallpaper renderer (QuoteCardView + ImageRenderer, 4 styles, share + save to Photos)
- [ ] StoreKit 2 paywall
- [x] Live Activity + Dynamic Island for pomodoro (ThinkWidgets extension target)
- [x] Home-screen / lock-screen quote widgets (DailyQuoteWidget: systemSmall/Medium + accessoryInline/Rectangular, 7-day timeline, flips at midnight)
- [x] Premium UI pass and semantic haptics (PR #2, 2026-07-05)
- [x] GitHub Actions build/test CI and shared Xcode test plan
- [x] Apple Watch companion v1: Today glance and watch-local focus timer
- [x] Think 1.1 custom focus durations (5–120 minutes work, 1–30 minutes break) with iPhone/Watch sync
- [x] First-launch onboarding (practice intro, notification opt-in, first path)
- [x] Zero-state polish (no-guilt streak copy, path "Not started")
- [x] Watch face streak complication (accessory families via watch widget extension)
- [x] Think 1.1 focus stats: rolling completed-session history, weekly chart, and totals (history begins empty; aggregate counters are not backfilled)
- [x] Release content audit: 100 deliberately paired line → question → action practices; attributed lines carry exact public-domain edition provenance, house lines remain unattributed on cards
- [ ] App Store 1.0 release prep: signing, screenshots, metadata, final branch/tag flow — in progress. Done so far: iPhone-only device family + localized timer notifications (PR #8), legal pages live at https://thinkapp.tech/privacy.html and https://thinkapp.tech/support.html. Open: free-vs-paywall decision, recut `release/1.0`, App Store Connect setup.
- [ ] CI/release pipeline upgrade (post-1.0): PR gates now, Xcode Cloud TestFlight lane after launch, fastlane screenshots/metadata before first update. Detailed implementation notes are maintained outside this repository.
