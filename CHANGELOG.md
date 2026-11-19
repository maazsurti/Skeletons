# Changelog

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
