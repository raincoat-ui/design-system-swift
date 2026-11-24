import RaincoatTokens

// What a tab looks like when it is selected or not, and in each state, taken from the Tabs
// tokens. This file uses no SwiftUI, so its tests also run on Linux.

/// How a tab is being interacted with: the states of the Tabs spec that change its colors.
/// Selection is separate: a selected tab can also be hovered or pressed.
enum TabInteraction: Hashable, CaseIterable, Sendable {
    case rest
    case hover
    case pressed

    /// Pressed wins over hover.
    init(isPressed: Bool, isHovered: Bool) {
        if isPressed {
            self = .pressed
        } else if isHovered {
            self = .hover
        } else {
            self = .rest
        }
    }
}

/// The colors of a tab.
struct TabColors: Hashable, Sendable {
    /// Fill of the tab. Nil when there is none, as at rest.
    let fill: TokenColor?
    /// Color of the label and the icon.
    let foreground: TokenColor
    /// The bar under the tab. Nil unless the tab is selected.
    let indicator: TokenColor?

    init(_ tokens: RaincoatTokenSet.TabsTokens, isSelected: Bool, interaction: TabInteraction) {
        indicator = isSelected ? tokens.indicator.color : nil
        switch interaction {
        case .rest:
            fill = nil
            foreground = isSelected ? tokens.fg.selected : tokens.fg.default
        case .hover:
            fill = tokens.bg.hover
            foreground = tokens.fg.hover
        case .pressed:
            fill = tokens.bg.pressed
            foreground = tokens.fg.hover
        }
    }
}

/// The measurements of a tab. There is one size; density sets its height.
struct TabMeasurements: Hashable, Sendable {
    /// Height of the tab when its label is at the default text size.
    let height: Double
    let paddingInline: Double
    let gap: Double
    let iconSize: Double
    let label: TokenTextStyle
    /// The smallest area that takes touches, whatever the visible height.
    let targetMinimum: Double

    init(_ tokens: RaincoatTokenSet.TabsTokens) {
        height = tokens.height
        paddingInline = tokens.paddingInline
        gap = tokens.gap
        iconSize = tokens.iconSize
        label = tokens.label
        targetMinimum = tokens.targetMinimum
    }

    /// Space above and below the label that centers one line in `height`. It stays the same
    /// when the text is enlarged, so the tab grows taller instead.
    var paddingBlock: Double {
        max(0, (height - label.lineHeight * label.size) / 2)
    }

    /// How far the touch area reaches above and below a tab shorter than the minimum target.
    var targetReach: Double {
        max(0, (targetMinimum - height) / 2)
    }
}
