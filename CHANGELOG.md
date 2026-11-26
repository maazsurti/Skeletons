# Changelog

## 1.5.0

Skeletons can now share one shimmer line across a whole screen, and lean it at any angle.

### New

- Shimmer bands now line up across every skeleton on a screen. `SkeletonTheme.shimmerAlignment` takes `.window` for one continuous diagonal across cards, sections and separate containers, or `.component` (the default) for each piece sweeping on its own.
- `SkeletonTheme.shimmerAngle` sets the stripe's lean in degrees: `0` is an upright band, `45` the steep diagonal, and a negative value leans it the other way. Right-to-left layouts still mirror it.

```swift
SkeletonTheme.current = SkeletonTheme(
    shimmerAlignment: .window,
    shimmerAngle: 45
)
```

### Improved

- The default stripe is gentler: it now leans 20° instead of 45°, which reads as a highlight rather than a slash across each card. Pass `shimmerAngle: 45` to keep the steeper look.
- `restartSweep()` keeps the screens around it in step: with `.window` alignment it restarts the shared wave only when that skeleton is the only one sweeping.

### Upgrading

No code changes needed. Add `shimmerAlignment: .window` to line the bands up across a screen, and `shimmerAngle: 45` to keep the previous 45° stripe.

## 1.4.2
