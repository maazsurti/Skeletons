# Changelog

## 1.4.0

- `skeletonized(only:keeping:ignoring:)` builds a skeleton from the real view: each leaf that stands
  in for fetched content is hidden and a block is constrained to it, so the placeholder takes the
  view's own Auto Layout instead of a second copy of the screen. `only` skeletonizes the named views
  and leaves the rest real, `keeping` leaves views real in place, and `ignoring` keeps their space
  and draws nothing.
- `SkeletonMode` states a view's own mode: `.automatic` for the rules, `.block` for one block over
  the view at its corner radius, `.static` to stay real, `.ignored` to keep the space and draw
  nothing. `UIView.skeletonMode(_:)` sets it; the innermost stated mode wins and an argument list
  beats a mode on the same view.
- `Skeletonized { view }` runs the same rules inside `SkeletonLayout` and the other elements,
  returning the prepared view rather than a nested container. `SkeletonRows` builds a fresh view per
  row.
- The walk: labels become their own line at the font's radius, aligned as the label is; a vertical
  stack of labels with no spacing is one block; image views and controls become blocks at their
  corner radius; a field keeps its chrome and shimmers one value line; chrome around more than one
  item is kept and recursed; a separator under 2 pt stays real; visual effect views and scroll views
  are walked through.
- Only a view the caller keeps static receives a touch, so a template's tap gestures never fire on
  sample data.
- The sweep marks the top-level rows and blocks, so a row and its contents cross as one component.

## 1.3.0

- The sweep takes a rest off the window between repeats, set by `SkeletonTheme.shimmerMinRest`:
  0.25 s by default, and clamped at zero. The band leaves the window, stays away for that rest and
  only then begins its next pass, instead of arriving the frame it left. A screen's cycle is one
  pass, the rest, and the stagger across its components, so a longer rest is added on top of the
  wave rather than taken out of the crossing.
- A rest of zero keeps the previous timing exactly: the pass fills the cycle and the repeat happens
  with nothing between the two ends.

## 1.2.8

- The highlight is a 45° stripe leaning the way the pass runs — a "/" from left to right, and the
  same lean mirrored from right to left — instead of a flat band. Its ends run past the block as it
  crosses, so a card, a photo and a line all read one continuous slash.
- The stripe's falloff is a soft bell of seven stops instead of a single 0.9 peak, so the band has no
  hard edge at either end.
- The pass carries the extra horizontal extent the lean adds: the stripe is one line across the
  component, covering the component's height, so the whole of it starts and finishes clear of the
  window and the repeat stays invisible.
- The stripe is a gradient layer of its own, tipped inside a container that does the sweep's
  translation, so the tilt and the animation never share a transform.
- A component's blocks draw the stripe as one line: a card's lines and photo share the slash rather
  than each stepping its own band down the card.

## 1.2.7

- Flush placeholder lines of different widths draw as one rectangle at the widest width they ask
  for, with all four outer corners rounded. A fused run is never stepped or L-shaped: a line with
  no width of its own makes the rectangle fill, a run of fractions takes the largest, and a mixed
  run takes its largest fraction.

## 1.2.6

- The README opens with the problem the package solves, the skeleton a screen shows while it loads,
  when to use it and a quick-start fragment, before the feature list.
- No code changes.

## 1.2.5

- The README leads with what the package does and what a screen gets from it — the features in user
  terms, requirements, installation and a quick start that builds a layout and swaps it with
  `SkeletonSwitcher` — before the reference sections.
- The preset list names the presets the package has: `.listRow`, `.cardRow`, `.priceColumn`,
  `.formField` and `.pickerRow`.

## 1.2.4

- The wave runs over the screen's components, not its blocks: a card, a row, a field or a section
  takes the next place in document order and every block inside it shares that place, so a card of
  five blocks sweeps as one surface instead of drawing a diagonal of its own. A piece the response
  does not fill takes no place, so the topmost block on screen starts the wave.
- The places are cumulative and never reduced modulo the pass: 0, 0.1, 0.2 … down the screen. The
  screen repeats after one pass plus the time the wave takes to reach its last component, so no two
  components share a phase and a long screen no longer restarts the wave at the top mid-pass.
- The band's travel is the window's, not each block's own edges: every block crosses the same
  distance at the same speed, whatever its width or origin, and a block carries its band when it
  scrolls instead of re-attaching the animation mid-pass. The band sits clear of the window at both
  ends of every pass, so the loop has no seam.
- `ShimmerTimeline` holds the one clock: a block's place in the wave is a function of that clock and
  its component, so re-attaching an animation lands exactly where the old one was.
- `shimmerDuration` is still one pass and `shimmerStagger` is still the delay between neighbouring
  components.

## 1.2.3

- The sweep loops without a seam: the band travels clear of the block on both sides, so the wrap
  happens off screen, and it crosses at a constant speed instead of easing into the edges.
- `shimmerDuration` defaults to 1.7 s and `shimmerStagger` to 0.10 s.

## 1.2.2

- A stated width is a preference: a placeholder keeps the width it was given while it fits and
  shrinks in a narrower container instead of breaking a constraint. Heights stay required.
- A row's height is its tallest element; a row no longer stretches a short copy column to a photo's
  height. Rows center by default.
- Flush placeholder lines — a vertical run at `spacing: 0` with no padding between them — draw as
  one block with rounded outer corners and no seam. Unequal widths draw as one stepped block.
- The sweep runs as a wave: `SkeletonTheme.shimmerStagger` sets the delay between one block and the
  next, in reading order, and the phase wraps inside a sweep.

## 1.2.0

- `SkeletonField` and `SkeletonPickerRow` draw a loading field at the loaded control's own chrome —
  surface, border, radius, height, padding, placeholder or label, leading icon and chevron — with
  only the value area shimmering.
- `SkeletonTheme` gains `fieldSurface`, `fieldBorder`, `fieldText`, `fieldTextFont`, `fieldHeight`,
  `fieldRadius` and `fieldPadding`.
- The `.formField` preset draws `SkeletonField`; `.pickerRow` is new.

## 1.1.2

- A layout accepts loops and conditionals: the content builder flattens groups, so `for` and `if`
  work inside any container.

## 1.1.1

- Containers take `padding`; rows take a `distribution`; cards take `spacing`; elements take
  `.aspect`; a preset can be used as an element.

## 1.1.0

- `SkeletonLayout` and its elements: declare a skeleton as a shape — lines by text style, blocks,
  photos, circles, cards, rows, columns, repeats and the list row / card row / price column / chip
  row / form field presets — instead of assembling `SkeletonView`s by hand.
- `SkeletonTheme` gains `spacing`, `cardRadius`, `shadow` and `lineHeight`, so a layout takes its
  defaults from the theme and overrides them per call.
- `SkeletonView.line(...)` takes a `radius`.
- Agent guidance lives in `AGENTS.md`; the README points at it.

## 1.0.0

- First release: shimmering placeholder blocks with one shared sweep, a Reduce Motion pulse, a
  single VoiceOver "Loading" element and a switcher that owns the 150 / 300 ms timing.
