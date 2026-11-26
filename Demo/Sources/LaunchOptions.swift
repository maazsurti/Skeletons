import Skeletons
import UIKit

/// The states the README shows, each openable straight from a launch argument, so a screenshot or a
/// recording needs no tapping:
///
///     -state loading | loaded      hold one state instead of running the load
///     -alignment window            line the shimmer up across the screen
///     -angle 45                    the stripe's lean, in degrees
///     -rtl                         mirror the layout and sweep from the trailing edge
///     -customColors                the theme's colours, not the defaults
///     -hideControls                the feed alone
///     -screen manual               the layout written by hand
///     -heroLoop                    skeleton, content, back to the skeleton, on a loop
struct LaunchOptions {

    enum State {
        /// The demo's own load: a skeleton, then the content.
        case run
        /// The skeleton, held.
        case loading
        /// The content, held.
        case loaded
    }

    enum Screen {
        case feed
        case manual
        case mapping
    }

    var state: State = .run
    var screen: Screen = .feed
    var alignment: SkeletonShimmerAlignment = .component
    var angle: CGFloat?
    var isRightToLeft = false
    var usesCustomColours = false
    var showsControls = true
    var loops = false

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        var index = 1
        while index < arguments.count {
            let name = arguments[index]
            let value = index + 1 < arguments.count ? arguments[index + 1] : nil

            switch name {
            case "-state":
                if let value {
                    state = State(name: value)
                    index += 1
                }
            case "-screen":
                if let value {
                    screen = Screen(name: value)
                    index += 1
                }
            case "-alignment":
                if let value {
                    alignment = value == "window" ? .window : .component
                    index += 1
                }
            case "-angle":
                if let value, let degrees = Double(value) {
                    angle = CGFloat(degrees)
                    index += 1
                }
            case "-rtl":
                isRightToLeft = true
            case "-customColors":
                usesCustomColours = true
            case "-hideControls":
                showsControls = false
            case "-heroLoop":
                loops = true
            default:
                break
            }
            index += 1
        }
    }
}

private extension LaunchOptions.State {
    init(name: String) {
        switch name {
        case "loading": self = .loading
        case "loaded": self = .loaded
        default: self = .run
        }
    }
}

private extension LaunchOptions.Screen {
    init(name: String) {
        switch name {
        case "manual": self = .manual
        case "mapping": self = .mapping
        default: self = .feed
        }
    }
}
