# Changelog

## 1.5.0

Skeletons can now share one shimmer line across a whole screen, and lean it at any angle.

**New**

- `SkeletonTheme.shimmerAlignment: .window` lines the shimmer up across every skeleton on a screen as one continuous stripe. The default, `.component`, keeps each card shimmering on its own.
- `SkeletonTheme.shimmerAngle` sets the stripe's lean in degrees, from `0` (upright) to `80` either way. Right-to-left layouts mirror it.

```swift
SkeletonTheme.current = SkeletonTheme(
    shimmerAlignment: .window,
    shimmerAngle: 45
)
```

**Improved**

- The default stripe is gentler: it now leans 20° instead of 45°, which reads as a highlight rather than a slash across each card. Pass `shimmerAngle: 45` to keep the steeper look.
- With `.window` alignment, `restartSweep()` restarts the shared shimmer only when no other skeleton on screen is shimmering.

**Upgrading**

No code changes needed. Add `shimmerAlignment: .window` to line the bands up across a screen, and `shimmerAngle: 45` to keep the previous 45° stripe.

## 1.4.2

A screen that reveals its skeleton late can start the shimmer when it settles.

**New**

- `SkeletonContainerView.restartSweep()` starts the shimmer again from the leading edge.

```swift
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    skeletonView.restartSweep()
}
```

**Upgrading**

No code changes needed.

## 1.4.1

Every skeleton now starts its own shimmer when it comes on screen.

**Improved**

- Each `SkeletonContainerView` starts its shimmer at its first card as it appears.
- Cards below follow in order instead of joining a shimmer already in progress.
- A card holds its shimmer stripe off screen until its turn.
- A relayout, a scroll or a trait change resumes the shimmer stripe where it was.
- A container that comes back on screen starts its shimmer again from the leading edge.
- Blocks placed by hand shimmer in the same order on one screen.

**Upgrading**

No code changes needed.

## 1.4.0

A skeleton can now be built from the real screen instead of declared by hand.

**New**

- `skeletonized()` turns a real view filled with sample data into a skeleton that uses the view's own layout.
- `only:` picks the views to skeletonize.
- `keeping:` leaves the named views real.
- `ignoring:` keeps a view's space and draws nothing.
- `SkeletonMode` sets what happens to one view. The modes are `.automatic`, `.block`, `.static` and `.ignored`.
- `Skeletonized { view }` brings the same rules into `SkeletonLayout`.

```swift
let card = OrderCardView(order: .sample)
let skeletonView = card.skeletonized(
    only: [card.sections],
    keeping: [card.heading, card.actionButton],
    ignoring: [card.badge]
)
```

**Improved**

- A field keeps its background and border, and only the value shimmers.
- Only a view you keep static takes a touch.

**Upgrading**

No code changes needed. `SkeletonLayout` and hand-placed blocks work as before.

## 1.3.0

The shimmer can pause off screen between sweeps.

**New**

- `SkeletonTheme.shimmerMinRest` sets how long the shimmer stays off screen before it repeats.
- The default is 0.25 s.

```swift
SkeletonTheme.current.shimmerMinRest = 0.4
```

**Improved**

- A screen with many cards keeps both its spread and its pause.
- A rest of zero keeps the previous timing.

**Upgrading**

No code changes needed.

## 1.2.8

The highlight is now a leaning shimmer stripe instead of a flat one.

**Improved**

- The shimmer stripe leans 45° in the direction of the sweep.
- A card's lines and its photo share one shimmer stripe.
- The shimmer stripe's edges fade softly.

**Upgrading**

No code changes needed.

## 1.2.7

Placeholder lines that touch draw as one rectangle at the widest width.

**Fixed**

- A run of touching lines with different widths draws as one rectangle at the widest width.
- All four outer corners of that rectangle are rounded.

**Upgrading**

No code changes needed.

## 1.2.6

The README explains the problem the package solves before it lists features.

**Improved**

- The README opens with the problem, when to use the package and a quick-start fragment.

**Upgrading**

No code changes needed.

## 1.2.5

The README now leads with what the package does and how a screen uses it.

**Improved**

- The README opens with the features, requirements, installation and a quick start.
- The preset list names `.listRow`, `.cardRow`, `.priceColumn`, `.formField` and `.pickerRow`.

**Upgrading**

No code changes needed.

## 1.2.4

A card or section now shimmers as one surface, and long screens stay in step.

**Improved**

- Blocks inside a card, row or section shimmer together instead of each taking its own shimmer.
- The topmost block on screen starts the screen's shimmer.
- A real heading or banner takes no part in the shimmer.
- The shimmer no longer restarts at the top on a long screen.
- Every block shimmers at the same speed, whatever its width.
- A block that scrolls keeps its shimmer in step.

**Upgrading**

No code changes needed.

## 1.2.3

The shimmer loops without a seam.

**Improved**

- One shimmer follows the last with no visible join.
- The shimmer stripe crosses at a constant speed instead of easing into the edges.
- `shimmerDuration` now defaults to 1.7 s.
- `shimmerStagger` now defaults to 0.10 s.

**Upgrading**

No code changes needed. A theme that sets either value by hand keeps it.

## 1.2.2

The shimmer moves across the screen instead of flashing everywhere at once.

**New**

- `SkeletonTheme.shimmerStagger` sets the delay between neighbouring blocks.

```swift
SkeletonTheme.current.shimmerStagger = 0.10
```

**Improved**

- A stated width now gives way in a narrower container instead of breaking a constraint.
- Heights stay required.
- A row's height is its tallest element.
- A short copy column sits beside a tall photo.
- Rows center by default.
- Placeholder lines with no spacing between them draw as one block with rounded outer corners.

**Upgrading**

No code changes needed.

## 1.2.1

Loading fields can keep a real accessory at their leading edge.

**New**

- `SkeletonField` and `SkeletonPickerRow` take `leading:`.
- A leading accessory keeps its own width and the field's full height.
- Without `valueWidthFraction`, the value line takes the width of the placeholder copy you pass.

```swift
SkeletonField(leading: SkeletonReal(countryButton), showsChevron: true)
```

**Improved**

- A loading field clips its content at its corner radius, as the real field does.
- A loading field no longer draws its placeholder as text over the value line.

**Upgrading**

No code changes needed. Pass an existing accessory as `leading: SkeletonReal(view)` to keep it.

## 1.2.0

Loading placeholders can now draw real form fields.

**New**

- `SkeletonField` draws a text field at the loaded field's background and border, with only the value shimmering.
- `SkeletonPickerRow` draws a field whose value is chosen elsewhere.
- The label and chevron of a picker row stay real, and only the value shimmers.
- `SkeletonTheme` gains `fieldSurface`, `fieldBorder`, `fieldText`, `fieldTextFont`, `fieldHeight`, `fieldRadius` and `fieldPadding`.
- The `.formField` preset draws `SkeletonField`.
- `.pickerRow` is a new preset.

```swift
SkeletonLayout {
    SkeletonField()
    SkeletonPickerRow(label: "Area")
}
```

**Upgrading**

No code changes needed.

## 1.1.3

A stack inside a placeholder card keeps its height.

**Fixed**

- A stack inside a `SkeletonCard` keeps its height in a tight column.

**Upgrading**

No code changes needed.

## 1.1.2

Layouts accept `for` loops and `if` statements.

**New**

- A loop or a conditional that yields several elements works inside any container.

**Upgrading**

No code changes needed.

## 1.1.1

Layouts take more geometry per call, and presets work anywhere an element does.

**Breaking changes**

- The `.chipRow` preset is removed.

**New**

- Containers take `padding`.
- Rows take a `distribution`.
- Cards take `spacing`.
- Every element takes `.aspect`.
- A preset can be placed inside any container.

**Upgrading**

Replace `.chipRow` with a `SkeletonRow` of `SkeletonBlock` items at the chip height and radius.

## 1.1.0

A skeleton can now be written as a layout instead of assembled block by block.

**New**

- `SkeletonLayout` declares a skeleton as a shape.
- The elements are `SkeletonLine`, `SkeletonBlock`, `SkeletonPhoto`, `SkeletonCircle`, `SkeletonCard`, `SkeletonRow`, `SkeletonColumn` and `SkeletonRows`.
- Presets draw the rows a screen repeats.
- The presets are `.listRow`, `.cardRow`, `.priceColumn`, `.chipRow` and `.formField`.
- `SkeletonTheme` gains `spacing`, `cardRadius`, `shadow` and `lineHeight`.
- `SkeletonView.line(...)` takes a `radius`.

```swift
let skeletonView = SkeletonLayout {
    SkeletonLine(.title)
    SkeletonRows(count: 5, spacing: 12, .listRow)
}.makeView()
```

**Upgrading**

No code changes needed.

## 1.0.0

First release: grey placeholder blocks that stand in for a screen's content while it loads.

**New**

- `SkeletonView` draws placeholder lines, blocks and circles in the theme's colours.
- One shimmer crosses every block on screen at once.
- `SkeletonContainerView` wraps a skeleton and gives VoiceOver one "Loading" element.
- `SkeletonSwitcher` shows the skeleton only if loading takes longer than 150 ms.
- Once shown, the skeleton stays up for at least 300 ms, then cross-dissolves into the content.
- Reduce Motion replaces the shimmer with a gentle opacity pulse.

**Upgrading**

No code changes needed.
