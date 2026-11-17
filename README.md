# Skeletons

Placeholder blocks for UIKit screens while their content loads. The blocks carry one shimmer band
that crosses them as a wave, a Reduce Motion pulse replaces it when that setting is on, and a
switcher keeps the exchange from flashing.

The package draws the blocks. Each screen places them in its own cards and cells.

## For agents

Adding or changing a skeleton in a host app: read [`AGENTS.md`](./AGENTS.md) first. It carries the
rules — what to grey out and what to keep real, how a field loads, when a selection brings the
skeleton back, the timings, and the accessibility requirements.

## Install

```swift
.package(url: "https://github.com/maazsurti/Skeletons.git", from: "1.2.2")
```

## Products

- **`Skeletons`** — UIKit.

## Set up

Set the theme once at launch, beside the rest of the app's theming:

```swift
import Skeletons

SkeletonTheme.current = SkeletonTheme(
    base: .skeletonBase,
    highlight: .skeletonHighlight,
    cornerRadius: 8,
    shimmerDuration: 1.7,
    shimmerStagger: 0.10,
    loadingText: String(localized: "Loading"),
    isRightToLeft: { Locale.current.language.characterDirection == .rightToLeft }
)
```

Every value has a system default, so `SkeletonTheme()` works as it is. Default colours are dynamic
and follow light and dark mode.

A loading field takes `fieldSurface`, `fieldBorder`, `fieldText`, `fieldTextFont`, `fieldHeight`,
`fieldRadius` and `fieldPadding` from the same theme. Point them at the app's field metrics so the
field sits where the real field sits.

## Compose a skeleton

Declare the shape. Spacing, radii and line heights come from the theme:

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

Blocks carry no layout of their own, so a screen can also place them by hand:

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
- `SkeletonView.block(height:cornerRadius:)` — anything else; give it constraints from the layout.
- `SkeletonView(cornerRadius:corners:)` — the plain block, for a corner radius the factories do not
  cover. `corners` names the corners that round.

A width a call site states is a preference: the block keeps it while it fits and gives way in a
container that is narrower, so a wide line never forces its host into an unsatisfiable layout. A
height is the block's own assertion and always holds.

`SkeletonContainerView` gives VoiceOver one "Loading" element in place of the individual blocks and
takes its label from `loadingText`. Its `isShimmering` covers every block inside it.

## Elements

- `SkeletonLayout` — the root: a vertical arrangement, one `SkeletonContainerView`, one VoiceOver
  "Loading". Takes `spacing`, `padding` and `alignment`.
- `SkeletonColumn` / `SkeletonRow` — vertical and horizontal stacks, with `spacing`, `padding` and
  `alignment`; columns lead by default, rows center. A row's height is its tallest element and a
  row never stretches a child vertically, so a short copy column beside a tall photo lays out.
- `SkeletonLine(style, width:widthFraction:)` — a text line. `SkeletonTextStyle` is `.title`,
  `.headline`, `.body`, `.caption` or `.custom(size)`; the height comes from
  `SkeletonTheme.lineHeight`.
- `SkeletonBlock(height:width:radius:)`, `SkeletonPhoto(width:height:aspect:radius:)`,
  `SkeletonCircle(diameter:)` — everything else a response fills.
- `SkeletonCard(padding:radius:background:border:shadow:)` — the real card's chrome around content.
- `SkeletonField(placeholder:icon:leading:showsChevron:valueWidthFraction:height:radius:padding:)` —
  a text field in the loaded field's chrome. No placeholder is drawn: the shimmering value line is
  the text, and the placeholder copy, when given, only sets that line's width.
- `SkeletonPickerRow(label:icon:leading:showsChevron:valueWidthFraction:height:radius:padding:)` — a
  field whose value is chosen elsewhere: label and chevron stay, the value after them shimmers.
- `SkeletonRows(count:spacing:padding:_:)` — N copies of a preset, or of a shape written at the call
  site.
- `SkeletonSpacer()` — takes the spare width in a row.
- `SkeletonReal(view)` — a real view (copy, a heading, a control) inside the shape.
- Presets: `.listRow`, `.cardRow`, `.priceColumn`, `.chipRow`, `.formField`, `.pickerRow`.
- Modifiers on any element: `.width(_:)`, `.height(_:)`, `.widthFraction(_:)`, `.padding(_:)`,
  `.hugging`. Lines, blocks and photos also take `.radius(_:)`.

Lines with nothing between them — a column or layout at `spacing: 0`, with no padding on the
elements — draw as one block: one continuous fill with rounded outer corners and no seam where the
lines meet. A gap of any size keeps them as separate bars. When the flush lines differ in width the
run reads as one stepped block, and each line keeps the width it asked for.

A field is not a block. `SkeletonField` and `SkeletonPickerRow` draw the loaded control's chrome and
real copy, and shimmer only the region the value occupies.

A loading field shows no placeholder: the value line stands in for the text. An accessory the app
already has — a country picker, an icon — stays real, keeps its own size and the field's full
height, and takes no shimmer of its own; pass the real view as `leading: SkeletonReal(view)` and
only the value area after it shimmers. An accessory whose own content is fetched takes a skeleton
element in the same place, and that element is what shimmers then.

## Swap it for the content

`SkeletonSwitcher` owns the timings, not the layout. Put the skeleton and the content in the same
place, one over the other, and tell the switcher what happened:

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
- `startLoading()` again puts the skeleton back with the same timings, so a retry behaves like the
  first load.

Pass a `SkeletonSwitcher.Timing` to change the three durations. Both views need a superview. The
switcher changes only their opacity; read `isSkeletonVisible` for anything else that has to know
which one is on screen.

## Behaviour

- **One band, one wave over the components.** Every block positions its highlight in window
  coordinates on a shared `CACurrentMediaTime()`-aligned clock, and each component takes the next
  phase in document order: the topmost component starts the wave, and each one below it crosses
  `shimmerStagger` seconds after the one above it, so a screen's offsets run 0, 0.1, 0.2 … A component
  is the piece the eye reads as one — a card, a row, a field, a section — and every block inside it
  crosses with it, so a card of five blocks sweeps as one surface. A piece the response does not
  fill, such as a real banner or a heading that is already text, takes no place. `shimmerStagger` 0
  puts every component back in phase. A block keeps its place while it is on screen, so a scroll or
  a second block arriving cannot move its phase.
- **A cycle long enough for the whole wave.** One pass takes `shimmerDuration`; the screen repeats
  after a pass plus the time the wave needs to reach its last component — the stagger times the gaps
  between components. No two components of a screen share a phase, however long the screen is.
- **A seamless loop.** The band's travel is the window's, not each block's own edges, so every block
  crosses the same distance at the same speed whatever its width or origin. The pass starts and ends
  with the band clear of the window, so the repeat happens with nothing on screen, and a block that
  scrolls carries its band with it rather than re-attaching it mid-pass.
- **Right to left.** When `isRightToLeft` returns true the sweep enters from the trailing edge and the
  wave runs from the trailing edge across.
- **Reduce Motion.** A gentle opacity pulse (0.55 ↔ 1) replaces the sweep, and the switcher swaps
  views without a dissolve. Both follow the setting while the app runs.
- **Nothing runs while hidden.** A block off-window or hidden stops its animation;
  `isShimmering = false` stops it outright.

## Requirements

iOS 17+, Swift 6 tools (Swift 5 language mode).
