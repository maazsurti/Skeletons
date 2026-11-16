# Changelog

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
