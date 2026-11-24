import RaincoatThemeBase
import RaincoatTokens
import Testing

@testable import Raincoat

// The mapping from a card's state to its tokens. Expected values are looked up by token id, so
// these tests do not repeat the switch statement they check. This file uses no SwiftUI and runs
// on Linux. The mapping is checked in every theme (allThemes, in Generated/Themes.swift).

@Suite struct CardAppearanceTests {
    @Test func pressedWinsOverHover() {
        #expect(CardState(isPressed: false, isHovered: false) == .rest, "nothing")
        #expect(CardState(isPressed: false, isHovered: true) == .hover, "a pointer over it")
        #expect(CardState(isPressed: true, isHovered: true) == .pressed, "pressed under a pointer")
        #expect(CardState(isPressed: true, isHovered: false) == .pressed, "pressed by touch")
    }

    @Test(arguments: allThemes, ColorMode.allCases)
    func eachStateTakesItsColorsFromTheCardTokens(theme: RaincoatTheme, mode: ColorMode) {
        let set = theme.tokens(mode: mode, density: .comfortable)
        let source = set.flattened()
        let rest = CardColors(set.card, state: .rest)
        let hover = CardColors(set.card, state: .hover)
        let pressed = CardColors(set.card, state: .pressed)

        // At rest, as a static card.
        #expect(TokenFormat.string(rest.fill) == source["card.bg.default"], "fill at rest")
        #expect(TokenFormat.string(rest.border) == source["card.border.default"], "outline at rest")
        // Hovered: the outline steps to strong, and the fill stays.
        #expect(TokenFormat.string(hover.fill) == source["card.bg.default"], "fill under a pointer")
        #expect(TokenFormat.string(hover.border) == source["card.border.hover"], "outline under a pointer")
        // Pressed: the fill steps to the pressed fill, and the outline is strong.
        #expect(TokenFormat.string(pressed.fill) == source["card.bg.pressed"], "fill when pressed")
        #expect(TokenFormat.string(pressed.border) == source["card.border.hover"], "outline when pressed")
    }

    @Test(arguments: allThemes)
    func theCardTokensFollowTheRfc(theme: RaincoatTheme) {
        // The card's fill is the raised surface, its pressed fill the control hover color, and its
        // strong outline the strong border color, in every mode.
        for mode in ColorMode.allCases {
            let set = theme.tokens(mode: mode, density: .comfortable)
            #expect(set.card.bg.default == set.color.bg.raised, "fill in \(mode)")
            #expect(set.card.bg.pressed == set.color.control.hover, "pressed fill in \(mode)")
            #expect(set.card.border.hover == set.color.border.strong, "strong outline in \(mode)")
        }
    }
}
