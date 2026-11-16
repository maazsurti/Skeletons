# Skeletons — agent notes

Placeholder blocks for UIKit screens while their content loads. The package draws the blocks; each
host screen places them in its own cards and cells. These are the rules for adding or changing a
skeleton in a host app. Follow them; they are what a reader sees.

## What to skeletonise

- **Only what is fetched.** A block stands in for content that arrives from the server. Screen
  titles, section headings, field labels, search fields, filter chips, buttons, toolbars and chrome
  are the app's own copy: build them as the real labels and controls, never as blocks.
- **Shapes, not lines.** Inside a fetched component, stand in for the shape the response fills — a
  list row, an option row, a card, a photo, an amount — not for each label inside it. One block row
  per option row is right; five block lines for a card's title, subtitle and description is wrong. A
  heading over a fetched list stays real text.
- **Match the real geometry.** Same container, background, border, padding, corner radius, row
  height and spacing, and a block as tall as the real line's box, so nothing moves when the content
  lands.
- **Fixed slots.** Give every placeholder cell its own size and let a spacer take the row's spare
  width; a block that stretches to fill tells the reader nothing.

## When a skeleton appears

- **First paint only.** A screen that can draw itself from local state or defaults renders them and
  updates in place: no skeleton, and a slow or failed fetch never gates what the reader already has.
- **A selection that changes the data is the exception.** The section being reloaded returns to its
  skeleton; the rest of the page — headings, filters, static copy, the control the reader just used
  — stays real, in place and interactive. No cross-dissolve of the whole page, no scroll jump, no
  flash of empty space. The last selection wins: cancel the load it supersedes, and never surface a
  cancelled load as an error.
- **Never fabricate waiting.** Pull-to-refresh and a reload on re-appear keep the content already
  shown. Actions — placing an order, saving, deleting — use the app's loading overlay, not blocks.
- **Timing is not yours to pick.** `SkeletonSwitcher` owns it: nothing under 150 ms, at least 300 ms
  once shown, a 0.2 s cross-dissolve, and a retry puts the skeleton up again.

## Accessibility and motion

- `SkeletonContainerView` stays the screen's single "Loading" element, with the blocks hidden from
  VoiceOver.
- Reduce Motion replaces the sweep with the pulse; the layout mirrors in RTL with nothing shifting.

## Don't / do

**Don't.** A loading wallet paints "Your wallet", the "Wallet packages" heading and the balance
card's "View all transactions" as grey lines, draws five lines per package for its name, price,
bonus, total and button, and stretches the button block across the row.

**Do.** Draw the title, the heading and the card's own copy as the real labels and the real button
they already are, and grey only what the response fills: one row block per package at the row's
size, its tile, its two amount lines and its fixed-width button, with a spacer taking the slack.
When the reader picks another date, the times for it go back to blocks and nothing else on the sheet
moves.

## Working in this repo

- `Sources/Skeletons/` — `SkeletonView` (blocks), `SkeletonContainerView` (VoiceOver's single
  "Loading" element), `SkeletonSwitcher` and `SkeletonScheduler` (150 / 300 ms and the 200 ms
  dissolve), `SkeletonTheme`, `ShimmerTimeline`.
- `Tests/SkeletonsTests/` — `swift test` (macOS host) keeps the shimmer and switcher honest.
- Keep screen layout out of the package: a block never constrains itself beyond the size its factory
  was given, and the switcher changes opacity only.
- README-only changes need no release. A behaviour change needs a new tag, and the app's dependency
  bumped with it in the same task.
