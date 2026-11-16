# Skeletons — agent notes

Placeholder blocks for UIKit screens while their content loads: one shared shimmer band, a Reduce
Motion pulse, and a switcher that owns the timing. The package draws the blocks; each host screen
places them in its own cards and cells.

Read **What to skeletonise** in `README.md` before adding or changing a skeleton in a host app.
It is the rule set, and it applies to every screen:

- only fetched content becomes blocks — titles, section headings, field labels, filters, buttons and
  chrome stay the real thing;
- a block stands in for the shape the response fills, not for each label inside a fetched card;
- the placeholder keeps the real container, padding, radius, row height and spacing;
- first paint only, plus a selection that changes the data, which puts just that section back into
  its skeleton while the rest of the screen stays real and interactive;
- actions use the app's loading overlay, never blocks.

## Working in this repo

- `Sources/Skeletons/` — `SkeletonView` (blocks), `SkeletonContainerView` (VoiceOver's single
  "Loading" element), `SkeletonSwitcher` and `SkeletonScheduler` (150 / 300 ms and the 200 ms
  dissolve), `SkeletonTheme`, `ShimmerTimeline`.
- `Tests/SkeletonsTests/` — `swift test` (macOS host) keeps the shimmer and switcher honest.
- Keep screen layout out of the package: a block never constrains itself beyond the size its
  factory was given, and the switcher changes opacity only.
- README-only changes need no release. A behaviour change needs a new tag, and the app's dependency
  bumped with it in the same task.
