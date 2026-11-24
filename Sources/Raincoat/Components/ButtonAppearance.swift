import RaincoatTokens

// What a Button looks like for a variant, a size, and a state, taken from the Button tokens.
// This file uses no SwiftUI, so its tests also run on Linux.

/// How a button is being interacted with: the states of the Button spec that change its colors.
enum ButtonInteraction: Hashable, CaseIterable, Sendable {
    case rest
    case hover
    case pressed
    case disabled

    /// Disabled wins over everything else. A loading button ignores the pointer, so it stays at
    /// rest. Pressed wins over hover.
    init(isEnabled: Bool, isLoading: Bool, isPressed: Bool, isHovered: Bool) {
        if !isEnabled {
            self = .disabled
        } else if isLoading {
            self = .rest
        } else if isPressed {
            self = .pressed
        } else if isHovered {
            self = .hover
        } else {
            self = .rest
        }
    }
}

/// The colors of a button.
struct ButtonColors: Hashable, Sendable {
    /// Fill of the container. Nil when there is none, as for a ghost button at rest.
    let fill: TokenColor?
    /// Color of the label, the icons, and the spinner.
    let foreground: TokenColor
    /// Outline of the container. Nil when there is none.
    let border: TokenColor?

    init(_ tokens: RaincoatTokenSet.ButtonTokens, variant: ButtonVariant, interaction: ButtonInteraction) {
        // Every variant looks the same when disabled.
        if interaction == .disabled {
            fill = tokens.disabled.bg
            foreground = tokens.disabled.fg
            border = tokens.disabled.border
            return
        }
        // The switches below are exhaustive on purpose: a variant added to the spec does not
        // compile until it is given colors here.
        switch variant {
        case .primary:
            foreground = tokens.primary.fg
            border = nil
            switch interaction {
            case .hover: fill = tokens.primary.bg.hover
            case .pressed: fill = tokens.primary.bg.pressed
            case .rest, .disabled: fill = tokens.primary.bg.default
            }
        case .secondary:
            foreground = tokens.secondary.fg
            border = tokens.secondary.border
            switch interaction {
            case .hover: fill = tokens.secondary.bg.hover
            case .pressed: fill = tokens.secondary.bg.pressed
            case .rest, .disabled: fill = tokens.secondary.bg.default
            }
        case .ghost:
            foreground = tokens.ghost.fg
            border = nil
            switch interaction {
            case .hover: fill = tokens.ghost.bg.hover
            case .pressed: fill = tokens.ghost.bg.pressed
            case .rest, .disabled: fill = nil
            }
        case .danger:
            foreground = tokens.danger.fg
            border = nil
            switch interaction {
            case .hover: fill = tokens.danger.bg.hover
            case .pressed: fill = tokens.danger.bg.pressed
            case .rest, .disabled: fill = tokens.danger.bg.default
            }
        }
    }
}

/// The measurements of a button of one size.
struct ButtonMeasurements: Hashable, Sendable {
    /// Height of the visible container when the label is on one line.
    let height: Double
    let paddingInline: Double
    let iconSize: Double
    let label: TokenTextStyle

    init(_ tokens: RaincoatTokenSet.ButtonTokens, size: ButtonSize) {
        switch size {
        case .sm:
            height = tokens.height.sm
            paddingInline = tokens.paddingInline.sm
            iconSize = tokens.iconSize.sm
            label = tokens.label.sm
        case .md:
            height = tokens.height.md
            paddingInline = tokens.paddingInline.md
            iconSize = tokens.iconSize.md
            label = tokens.label.md
        case .lg:
            height = tokens.height.lg
            paddingInline = tokens.paddingInline.lg
            iconSize = tokens.iconSize.lg
            label = tokens.label.lg
        }
    }

    /// Space above and below the label that centers one line in `height`. It stays the same
    /// when the label wraps or the text is enlarged, so the button grows instead.
    var paddingBlock: Double {
        max(0, (height - label.lineHeight * label.size) / 2)
    }

    /// Space on every side of the icon of a button that shows only an icon, which centers the
    /// icon in `height`. It stays the same when the text is enlarged and the icon with it, so
    /// the button grows instead, and stays square.
    var paddingAroundIcon: Double {
        max(0, (height - iconSize) / 2)
    }
}
