import RaincoatThemeBase
import RaincoatTokens
import Testing

@testable import Raincoat

// The mapping from a button's variant, size, and state to its tokens. Expected values are
// looked up by token id, built from the variant's and size's names in the spec, so these tests
// do not repeat the switch statements they check. This file uses no SwiftUI and runs on Linux.

private func tokens(_ mode: ColorMode, _ density: Density = .comfortable) -> RaincoatTokenSet {
    RaincoatTheme.base.tokens(mode: mode, density: density)
}

private func canonical(_ color: TokenColor?) -> String? {
    color.map { TokenFormat.string($0) }
}

@Test func disabledWinsThenLoadingThenPressedThenHover() {
    typealias State = ButtonInteraction
    #expect(State(isEnabled: true, isLoading: false, isPressed: false, isHovered: false) == .rest)
    #expect(State(isEnabled: true, isLoading: false, isPressed: false, isHovered: true) == .hover)
    #expect(State(isEnabled: true, isLoading: false, isPressed: true, isHovered: true) == .pressed)
    // A loading button ignores the pointer.
    #expect(State(isEnabled: true, isLoading: true, isPressed: true, isHovered: true) == .rest)
    #expect(State(isEnabled: false, isLoading: true, isPressed: true, isHovered: true) == .disabled)
    #expect(State(isEnabled: false, isLoading: false, isPressed: false, isHovered: false) == .disabled)
}

@Test(arguments: ColorMode.allCases, ButtonVariant.allCases)
func eachVariantTakesItsColorsFromItsTokens(mode: ColorMode, variant: ButtonVariant) {
    let set = tokens(mode)
    let source = set.flattened()
    let name = variant.rawValue

    let rest = ButtonColors(set.button, variant: variant, interaction: .rest)
    let hover = ButtonColors(set.button, variant: variant, interaction: .hover)
    let pressed = ButtonColors(set.button, variant: variant, interaction: .pressed)

    // A ghost button has no fill at rest, and no token for one.
    #expect(canonical(rest.fill) == source["button.\(name).bg.default"])
    #expect((rest.fill == nil) == (variant == .ghost))
    #expect(canonical(hover.fill) == source["button.\(name).bg.hover"])
    #expect(canonical(pressed.fill) == source["button.\(name).bg.pressed"])
    #expect(hover.fill != nil && pressed.fill != nil)

    for colors in [rest, hover, pressed] {
        #expect(canonical(colors.foreground) == source["button.\(name).fg"])
        // Only the secondary button has an outline, and a token for one.
        #expect(canonical(colors.border) == source["button.\(name).border"])
        #expect((colors.border != nil) == (variant == .secondary))
    }
}

@Test(arguments: ColorMode.allCases)
func everyVariantLooksTheSameWhenDisabled(mode: ColorMode) {
    let set = tokens(mode)
    let source = set.flattened()
    for variant in ButtonVariant.allCases {
        let colors = ButtonColors(set.button, variant: variant, interaction: .disabled)
        #expect(canonical(colors.fill) == source["button.disabled.bg"])
        #expect(canonical(colors.foreground) == source["button.disabled.fg"])
        #expect(canonical(colors.border) == source["button.disabled.border"])
    }
}

@Test(arguments: Density.allCases, ButtonSize.allCases)
func eachSizeTakesItsMeasurementsFromItsTokens(density: Density, size: ButtonSize) {
    let set = tokens(.light, density)
    let source = set.flattened()
    let name = size.rawValue
    let measurements = ButtonMeasurements(set.button, size: size)

    #expect(TokenFormat.string(measurements.height) == source["button.height.\(name)"])
    #expect(TokenFormat.string(measurements.paddingInline) == source["button.padding-inline.\(name)"])
    #expect(TokenFormat.string(measurements.iconSize) == source["button.icon-size.\(name)"])
    #expect(TokenFormat.string(measurements.label) == source["button.label.\(name)"])

    // One line of the label, with the padding above and below, is exactly the height.
    let line = measurements.label.lineHeight * measurements.label.size
    #expect(abs(line + 2 * measurements.paddingBlock - measurements.height) < 0.0001)
}

@Test func compactDensityMakesButtonsShorterButNotNarrower() {
    let comfortable = ButtonMeasurements(tokens(.light, .comfortable).button, size: .md)
    let compact = ButtonMeasurements(tokens(.light, .compact).button, size: .md)
    #expect(compact.height < comfortable.height)
    #expect(compact.paddingInline == comfortable.paddingInline)
    #expect(compact.label == comfortable.label)
}
