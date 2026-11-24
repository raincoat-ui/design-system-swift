import RaincoatTokens

// What a Card looks like in each state, taken from the Card tokens. This file uses no SwiftUI,
// so its tests also run on Linux.

/// How an interactive card is being interacted with: the states of the Card spec that change its
/// colors. A static card is always at rest. Keyboard focus changes no color on iOS: the system
/// draws its own focus indicator.
enum CardState: Hashable, CaseIterable, Sendable {
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

/// The colors of a card's container.
struct CardColors: Hashable, Sendable {
    /// Fill of the container.
    let fill: TokenColor
    /// Outline of the container.
    let border: TokenColor

    init(_ tokens: RaincoatTokenSet.CardTokens, state: CardState) {
        // The switch is exhaustive on purpose: a state added to the spec does not compile until it
        // is given colors here.
        switch state {
        case .rest:
            fill = tokens.bg.default
            border = tokens.border.default
        case .hover:
            fill = tokens.bg.default
            border = tokens.border.hover
        case .pressed:
            fill = tokens.bg.pressed
            border = tokens.border.hover
        }
    }
}
