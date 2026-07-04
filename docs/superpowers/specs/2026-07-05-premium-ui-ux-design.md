# Think Premium UI/UX Redesign

## Goal

Make Think feel like a calm training tool for attention: premium, disciplined, intimate, and useful on the first screen. The app should stop feeling like default SwiftUI lists/cards and start feeling like a focused daily practice.

Primary direction: combine **Daily Ritual** for Today with **Focus Chamber** for the timer. Paths and Profile should support that identity without becoming visually loud.

## Principles

- Keep black and yellow as the brand signal, but add depth with restrained off-black surfaces, warm text, fine dividers, and measured glow.
- Make the app feel like a tool, not a landing page. No decorative hero clutter, no generic gradient blobs, no motivational poster energy.
- Every screen should answer: "What is my next useful action?"
- Animation should be quiet and purposeful: progress, completion, entry transitions, timer movement. No bouncing or playful effects.
- Preserve accessibility: readable contrast, stable hit targets, Dynamic Type-friendly layouts, labels for icon buttons.

## Shared Visual System

- Add a small local design layer for colors, spacing, surfaces, and reusable components.
- Use deep black app backgrounds with elevated charcoal surfaces.
- Use brand yellow only for progress, selected states, primary actions, and small attention markers.
- Cards should have 16-20 px radius where they represent a contained practice surface; tab and button shapes can remain pill-like where Liquid Glass fits.
- Typography:
  - Serif only for quotes and reflective text.
  - Rounded/monospaced digits for timer and stats.
  - Tight, functional sans-serif for controls and labels.

## Today

Today becomes the main daily ritual screen.

- Replace the plain quote card with a "Today's rep" practice card.
- Show date, streak, and a compact progress rail near the top.
- Quote card gets a brand accent line, stronger hierarchy, and a warmer reading surface.
- Question card becomes the active task, with a clear "Save answer" action and answered state.
- Stats become a "training log" row with focus sessions and current path progress.
- Add subtle content entrance animation on first appearance and completion feedback when an answer is saved.

## Focus

Focus becomes the app's signature moment.

- Keep the circular timer, but give it more visual weight and a calmer surrounding layout.
- Add a low-intensity ring glow only while running.
- Move supporting quote into a smaller "focus cue" treatment.
- Make Start/Pause the clear primary action.
- Keep reset and skip as icon-only secondary actions with clear accessibility labels.
- Add timer state animation:
  - ring progresses smoothly,
  - primary button changes state cleanly,
  - phase transition feels deliberate, not flashy.

## Paths

Paths should feel like a training atlas, not a settings list.

- Replace the default list feel with custom rows inside a full-width section.
- Deep Focus shows visible day progress and the next step.
- Locked paths show "Soon" with muted treatment, but still look like part of the product roadmap.
- Use a subtle vertical progress motif or card grouping to make paths feel sequential.

## Profile

Profile becomes a quiet control center.

- Replace default list sections with custom progress and settings panels.
- Current streak, focus sessions, and path days should read as a compact dashboard.
- Journal remains prominent.
- Settings and feedback stay dense and utilitarian.
- Fix bottom overlap risk around the feedback section by ensuring scroll content clears the tab bar.

## Animation and UX Rules

- Use SwiftUI animations tied to state changes, not perpetual motion.
- Prefer opacity, scale under 1.03, trim/ring progress, and numeric transitions.
- Avoid background animation on every screen; the app should feel calm.
- Haptics can be added later, but not in this first pass unless already easy and testable.

## Implementation Scope

In scope for first implementation pass:

- Shared design tokens/components.
- Today redesign.
- Focus redesign and timer animation polish.
- Paths redesign.
- Profile redesign enough to remove the default-list feel and bottom overlap.
- Update UI tests only where accessibility labels or structure change.

Out of scope for this pass:

- New content paths.
- Paywall or Pro gating.
- Custom illustrations or generated assets.
- Full onboarding.
- Subscription/store UI.

## Testing

- Existing Swift Testing unit tests should keep passing.
- Existing UI tests should be updated to target stable accessibility labels.
- Run the shared `Think` test plan locally before pushing.
- GitHub `build-test` must pass on the feature branch before merge.
