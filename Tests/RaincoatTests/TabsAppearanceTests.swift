import RaincoatThemeBase
import RaincoatTokens
import Testing

@testable import Raincoat

// The mapping from a tab's selection and state to its tokens. Expected values are looked up by
// token id, so these tests do not repeat the switch statement they check. This file uses no
// SwiftUI and runs on Linux. The mappings are checked in every theme (allThemes, in
// Generated/Themes.swift).

private func tokens(
    _ mode: ColorMode, _ density: Density = .comfortable, in theme: RaincoatTheme = .base
) -> RaincoatTokenSet {
    theme.tokens(mode: mode, density: density)
}

private func canonical(_ color: TokenColor?) -> String? {
    color.map { TokenFormat.string($0) }
}

@Test func pressedWinsOverHover() {
    #expect(TabInteraction(isPressed: false, isHovered: false) == .rest)
    #expect(TabInteraction(isPressed: false, isHovered: true) == .hover)
    #expect(TabInteraction(isPressed: true, isHovered: true) == .pressed)
    #expect(TabInteraction(isPressed: true, isHovered: false) == .pressed)
}

@Test(arguments: allThemes, ColorMode.allCases)
func aTabTakesItsColorsFromItsTokens(theme: RaincoatTheme, mode: ColorMode) {
    let set = tokens(mode, in: theme)
    let source = set.flattened()

    for isSelected in [false, true] {
        let rest = TabColors(set.tabs, isSelected: isSelected, interaction: .rest)
        let hover = TabColors(set.tabs, isSelected: isSelected, interaction: .hover)
        let pressed = TabColors(set.tabs, isSelected: isSelected, interaction: .pressed)

        // No fill at rest, and no token for one.
        #expect(rest.fill == nil)
        #expect(canonical(hover.fill) == source["tabs.bg.hover"])
        #expect(canonical(pressed.fill) == source["tabs.bg.pressed"])

        #expect(canonical(rest.foreground) == source[isSelected ? "tabs.fg.selected" : "tabs.fg.default"])
        #expect(canonical(hover.foreground) == source["tabs.fg.hover"])
        #expect(canonical(pressed.foreground) == source["tabs.fg.hover"])

        // The indicator marks the selected tab in every state, and no other tab.
        for colors in [rest, hover, pressed] {
            #expect(canonical(colors.indicator) == (isSelected ? source["tabs.indicator.color"] : nil))
        }
    }
}

@Test(arguments: allThemes, Density.allCases)
func aTabTakesItsMeasurementsFromItsTokens(theme: RaincoatTheme, density: Density) {
    let set = tokens(.light, density, in: theme)
    let source = set.flattened()
    let measurements = TabMeasurements(set.tabs)

    #expect(TokenFormat.string(measurements.height) == source["tabs.height"])
    #expect(TokenFormat.string(measurements.paddingInline) == source["tabs.padding-inline"])
    #expect(TokenFormat.string(measurements.gap) == source["tabs.gap"])
    #expect(TokenFormat.string(measurements.iconSize) == source["tabs.icon-size"])
    #expect(TokenFormat.string(measurements.label) == source["tabs.label"])
    #expect(TokenFormat.string(measurements.targetMinimum) == source["tabs.target-minimum"])

    // One line of the label, with the padding above and below, is exactly the height.
    let line = measurements.label.lineHeight * measurements.label.size
    #expect(abs(line + 2 * measurements.paddingBlock - measurements.height) < 0.0001)

    // The touch area reaches far enough above and below to make up the minimum target.
    #expect(measurements.height + 2 * measurements.targetReach >= measurements.targetMinimum - 0.0001)
    #expect(measurements.targetReach >= 0)
}

@Test func compactDensityMakesTabsShorterButNotNarrower() {
    let comfortable = TabMeasurements(tokens(.light, .comfortable).tabs)
    let compact = TabMeasurements(tokens(.light, .compact).tabs)
    #expect(compact.height < comfortable.height)
    #expect(compact.paddingInline == comfortable.paddingInline)
    #expect(compact.label == comfortable.label)
    // A compact tab is shorter than the minimum target, so its touch area reaches past it.
    #expect(comfortable.targetReach == 0)
    #expect(compact.targetReach > 0)
}
