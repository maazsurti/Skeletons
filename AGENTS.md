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
- **A row's height is its tallest element.** A row keeps every child at the height that child
  asserts, so a short copy column beside a tall photo needs nothing special; the photo sets the
  row and the column sits centered in it.
- **Fixed slots.** Give every placeholder cell its own size and let a spacer take the row's spare
  width; a block that stretches to fill tells the reader nothing.
- **Fields keep their chrome.** A text field or picker keeps its real surface, border, radius,
  height, padding, label, accessory and chevron, and only the region the value occupies shimmers.
  Draw it with `SkeletonField` or `SkeletonPickerRow`, never as one block.
- **A loading field shows no placeholder.** The value line stands in for the text. Pass the
  placeholder only to have the line take that copy's width; never draw it as copy over the line.
- **A known accessory stays real.** A country picker or an icon the app already has is the real view
  at its own size, with nothing shimmering on it; only the value area after it shimmers. Pass it as
  `leading: SkeletonReal(view)`. An accessory whose own content is fetched takes a skeleton element
  in the same place instead.

## Skeletonize the real view first

Every skeleton is the screen's own real view, filled with sample data and skeletonized: call
`skeletonized()`, or `Skeletonized { … }` inside an element tree. Reach for a custom skeleton only
when the real view cannot express the shape — no real view exists to fill with sample data, or the
rules still read a shape wrong after `skeletonMode`, `only`, `keeping` and `ignoring`. Convenience or
habit is not a reason.

Build the view as the loaded screen builds it, then skeletonize it, so every block takes the geometry
the real Auto Layout gives it. Keep the screen from growing a second copy of its layout.

```swift
let card = OrderCardView(order: .sample)
let skeletonView = card.skeletonized(keeping: [card.heading, card.actionButton])
```

`skeletonized()` takes the view into the skeleton, reparents it and alters it. Build a throwaway
template and pass that; never pass the live view.

- Labels and buttons are fetched content as far as the walk knows: without a list they become blocks.
  Keep the screen's own copy — titles, headings, field labels, chips, action buttons — with
  `keeping:` or `.static`.
- Never keep a value the response fills. A kept total shows sample money.
- Restrict the walk with `only:` when one section reloads, `keeping:` for the screen's own copy and
  controls, and `ignoring:` for a piece that keeps its space and shows nothing.
- State a mode on a single view with `skeletonMode(_:)` — `.block` for a shape the rules read wrong,
  `.static` to stay real, `.ignored` to draw nothing. The innermost stated mode wins.
- `Skeletonized { … }` puts the automatic walk inside an element tree.

## Compose a custom skeleton

This is the fallback, for a skeleton the real view cannot express: a state with no view in the tree,
or a shape the rules still read wrong. A custom skeleton is a shape, not a pile of blocks. Declare it
with `SkeletonLayout` and its elements; the theme supplies spacing, radii and line heights, and a
call only names what differs.

```swift
SkeletonLayout(spacing: 14) {
    SkeletonLine(.title)
    SkeletonCard(padding: 14, background: .surface, border: .border) {
        SkeletonRow(spacing: 14) {
            SkeletonPhoto(width: 84, height: 64, radius: 12)
            SkeletonColumn(spacing: 2, padding: 4) {
                SkeletonLine(.headline, widthFraction: 0.6)
                SkeletonLine(.body, widthFraction: 0.9)
                SkeletonPreset.priceColumn.element
            }
        }
    }
    SkeletonRows(count: 5, spacing: 12, padding: 4, .listRow)
}
```

Every container takes `padding` (`CGFloat` or `UIEdgeInsets`), `spacing` and `alignment`; every
element takes `.width`, `.height`, `.widthFraction`, `.padding` and `.hugging`, and the shapes take
`.radius`. A stated width is a preference and gives way in a narrow container; a stated height
holds. Lines with no spacing and no padding between them fuse into one rectangle at the widest
width they ask for, so pass `spacing` when they should read as separate bars. Use `.listRow`,
`.cardRow`, `.priceColumn`, `.formField` and `.pickerRow` for the rows and fields the app repeats;
add a preset only when a screen uses it. Blocks placed by hand come last, after the builder: reach
for a raw `SkeletonView` only where neither the real view's layout nor an element declares the shape.

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

- `Sources/Skeletons/` — `SkeletonView` (blocks), `Skeletonized` (the automatic walk over a real
  view), `SkeletonField` (fields and pickers, their chrome and
  their value line), `SkeletonContainerView` (VoiceOver's single "Loading" element), `SkeletonSwitcher`
  and `SkeletonScheduler` (150 / 300 ms and the 200 ms dissolve), `SkeletonTheme`, `ShimmerTimeline`.
- `Tests/SkeletonsTests/` — `xcodebuild test -scheme Skeletons -destination 'platform=iOS Simulator,id=<udid>'`
  keeps the shimmer, the switcher and the layout honest.
- Keep screen layout out of the package: a block never constrains itself beyond the size its factory
  was given, and the switcher changes opacity only.
- README-only changes need no release. A behaviour change needs a new tag, and the app's dependency
  bumped with it in the same task.
