# Skeletons

Placeholder blocks for UIKit screens while their content loads: one shared shimmer band across
every block on screen, a Reduce Motion pulse, and a switcher that keeps the exchange from flashing.

The package draws the blocks only. Each screen places them in its own cards and cells.

Agents adding skeletons to a screen: follow `AGENTS.md`.

## Install

```swift
.package(url: "https://github.com/maazsurti/Skeletons.git", from: "1.2.0")
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
dynamic and follow light and dark mode. A loading field's chrome takes `fieldSurface`,
`fieldBorder`, `fieldText`, `fieldTextFont`, `fieldHeight`, `fieldRadius` and `fieldPadding` from
the same theme; set them to the app's own field metrics so the field lands where the real one does.

## Compose a skeleton

Declare the shape you are waiting for; the layout takes its spacing, radii and line heights from
the theme:

```swift
let skeleton = SkeletonLayout {
    SkeletonLine(.title)
    SkeletonCard(padding: 14, background: .surface, border: .border) {
        SkeletonRow(spacing: 14) {
            SkeletonPhoto(width: 84, height: 64, radius: 12)
            SkeletonColumn(spacing: 2) {
                SkeletonLine(.headline, widthFraction: 0.6)
                SkeletonLine(.body, widthFraction: 0.9)
            }
        }
    }
    SkeletonRows(count: 5, spacing: 12, padding: 4, .listRow)
}
```

The elements are covered under [Elements](#elements). Blocks carry no layout of their own, so the
same screen can also place them by hand:

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

## Elements

- `SkeletonLayout` — the root: a vertical arrangement, one `SkeletonContainerView` and one VoiceOver
  "Loading". Takes `spacing`, `padding` and `alignment`.
- `SkeletonColumn` / `SkeletonRow` — vertical and horizontal stacks, with `spacing`, `padding` and
  `alignment`; columns lead by default, rows fill.
- `SkeletonLine(style, width:widthFraction:)` — a text line; `SkeletonTextStyle` is `.title`,
  `.headline`, `.body`, `.caption` or `.custom(size)`, and the height comes from
  `SkeletonTheme.lineHeight`.
- `SkeletonBlock(height:width:radius:)`, `SkeletonPhoto(width:height:aspect:radius:)`,
  `SkeletonCircle(diameter:)` — everything else a response fills.
- `SkeletonCard(padding:radius:background:border:shadow:)` — the real card's chrome around its content.
- `SkeletonField(placeholder:icon:showsChevron:valueWidthFraction:height:radius:padding:)` — a text
  field at the loaded field's chrome, its placeholder reading over a shimmering value line.
- `SkeletonPickerRow(label:icon:showsChevron:valueWidthFraction:height:radius:padding:)` — a field
  whose value is chosen elsewhere: the label and chevron stay, the value after them shimmers.
- `SkeletonRows(count:spacing:padding:_:)` — N copies of a preset or of a shape written at the call site.
- `SkeletonSpacer()` — takes the spare width in a row.
- `SkeletonReal(view)` — a real view (copy, a heading, a control) inside the shape.
- Presets: `.listRow`, `.cardRow`, `.priceColumn`, `.chipRow`, `.formField`, `.pickerRow`.
- Modifiers on any element: `.width(_:)`, `.height(_:)`, `.widthFraction(_:)`, `.padding(_:)`,
  `.hugging`; lines, blocks and photos also take `.radius(_:)`.

A field is not a block: `SkeletonField` and `SkeletonPickerRow` draw the loaded control's own
chrome and copy, and shimmer only the region the value occupies.

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
