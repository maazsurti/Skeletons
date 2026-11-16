# Skeletons

Placeholder blocks for UIKit screens while their content loads: one shared shimmer band across
every block on screen, a Reduce Motion pulse, and a switcher that keeps the exchange from flashing.

The package draws the blocks only. Each screen places them in its own cards and cells.

## Install

```swift
.package(url: "https://github.com/maazsurti/Skeletons.git", from: "1.0.0")
```

## Products

- **`Skeletons`** — UIKit.

## Set up

Set the theme once at launch, beside the rest of your app's theming:

```swift
import Skeletons

SkeletonTheme.current = SkeletonTheme(
    base: .skeletonBase,
    highlight: .skeletonHighlight,
    cornerRadius: 8,
    shimmerDuration: 1.2,
    loadingText: String(localized: "Loading"),
    isRightToLeft: { Locale.current.language.characterDirection == .rightToLeft }
)
```

Every value has a system default, so `SkeletonTheme()` works as-is. The default colours are
dynamic and follow light and dark mode.

## What to skeletonise

Grey out only what the fetch delivers. A block promises server content; everything the app already
knows stays real and visible.

- **Only what is fetched.** Screen titles, section headings, field labels, search fields, filter
  chips, buttons, toolbars and chrome are the app's own copy — render them as the labels and
  controls they will be at rest, never as blocks.
- **Shapes, not lines.** Inside a fetched component, stand in for the shape the response fills — a
  list row, an option row, a card, a photo, an amount — not for each label inside it. One block row
  per option row is right; five block lines for a card's title, subtitle and description is wrong.
  A heading over a fetched list stays real text.
- **Match the real geometry.** Same container, background, border, padding, corner radius, row
  height and spacing, and a block as tall as the real line's box, so nothing moves when the content
  lands.
- **First paint, plus a selection.** A screen that can draw itself from local state or defaults
  renders them and updates in place; it gets no skeleton, and a slow or failed fetch never gates
  what the reader already has. A selection that changes what is fetched is the one refetch that
  does show blocks again: the section being reloaded returns to its skeleton, while the rest of the
  page — headings, filters, static copy, the control the reader just used — stays real, in place
  and interactive. Pull-to-refresh and a reload on re-appear keep the content they already have.
- **No skeleton for actions.** Placing an order, saving or deleting shows the app's loading
  overlay, not blocks.
- **Fixed slots.** Give every placeholder cell its own size and let a spacer take the row's spare
  width; a block that stretches to fill tells the reader nothing.
- **One announcement, one motion.** `SkeletonContainerView` stays the screen's single "Loading"
  element, with the blocks hidden from VoiceOver; the sweep becomes the Reduce Motion pulse; the
  layout mirrors in RTL without anything shifting.
- **Timing is not yours to pick.** The switcher already owns it: nothing appears under 150 ms, a
  shown skeleton stays 300 ms, the swap cross-dissolves over 200 ms, and a retry puts the skeleton
  up again. A section reload keeps the same timings and swaps only its own container.

### Before and after

**Don't.** A loading wallet paints "Your wallet", the "Wallet packages" heading and the balance
card's "View all transactions" as grey lines, draws five lines per package for its name, price,
bonus, total and button, and stretches the button block across the row.

**Do.** Draw the title, the heading and the card's own copy as the real labels and the real button
they already are, and grey only what the response fills: one row block per package at the row's
size, its tile, its two amount lines and its fixed-width button, with a spacer taking the slack.
When the reader picks another date, the times for it go back to blocks and nothing else on the
sheet moves.

## Compose a skeleton

Blocks carry no layout of their own. Build the screen's real layout with placeholders in place of
its content:

```swift
let title = SkeletonView.line(height: 16, widthFraction: 0.6)
let avatar = SkeletonView.circle(diameter: 40)
let body = SkeletonView.block(height: 72, cornerRadius: 12)

let layout = UIStackView(arrangedSubviews: [avatar, title, body])
layout.axis = .vertical
layout.spacing = 12

let skeleton = SkeletonContainerView(content: layout)
```

- `SkeletonView.line(height:width:widthFraction:)` — one line of text. Without a width it takes the
  width its container gives it; `widthFraction` is a share of the superview's width.
- `SkeletonView.circle(diameter:)` — avatars, icons, thumbnails.
- `SkeletonView.block(height:cornerRadius:)` — anything else; give it constraints from your layout.
- `SkeletonView(cornerRadius:)` — the plain block, for a corner radius the factories do not cover.

`SkeletonContainerView` gives VoiceOver one "Loading" element in place of the individual blocks and
takes its label from `loadingText`, so the text can be localised. It also carries
`isShimmering` for every block inside it.

## Swap it for the content

`SkeletonSwitcher` owns the timings, not the layout: put the skeleton and the content in the same
place, one over the other, and tell the switcher what happened.

```swift
private lazy var switcher = SkeletonSwitcher(
    skeleton: skeletonView,
    content: contentView,
    scheduler: MainQueueSkeletonScheduler()
)

func load() {
    switcher.startLoading()
    service.fetch { [weak self] result in
        self?.apply(result)
        self?.switcher.showContent()
    }
}
```

- The skeleton appears only if the load is still running after 150 ms.
- Once it appears it stays for at least 300 ms.
- Skeleton and content cross-dissolve over 200 ms.
- `startLoading()` again puts the skeleton back up with the same timings, so a retry behaves like
  the first load.

Pass a `SkeletonSwitcher.Timing` to change the three durations. Both views need a superview; the
switcher changes only their opacity, and it reads `isSkeletonVisible` for anything else that has to
know which one is on screen.

## Behaviour

- **One band, one clock.** Every block positions its highlight in window coordinates and starts its
  sweep on a shared `CACurrentMediaTime()`-aligned timeline, so the blocks read as a single band
  crossing the screen rather than each one sweeping on its own.
- **Right to left.** When `isRightToLeft` returns true the sweep enters from the trailing edge.
- **Reduce Motion.** The sweep is replaced by a gentle opacity pulse (0.55 ↔ 1) and the switcher
  swaps the views without a dissolve. Both react to the setting while the app runs.
- **Nothing runs while hidden.** A block off-window or hidden stops its animation, and
  `isShimmering = false` stops it outright.

## Requirements

iOS 17+, Swift 6 tools (Swift 5 language mode).
