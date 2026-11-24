import RaincoatThemeBase
import RaincoatTokens
import Testing

@testable import Raincoat

// The mapping from an input's size, type, and state to its tokens. Expected values are looked up
// by token id, built from the size's name in the spec, so these tests do not repeat the switch
// statements they check. This file uses no SwiftUI and runs on Linux. The mappings are checked in
// every theme (allThemes, in Generated/Themes.swift).

private func tokens(
    _ mode: ColorMode, _ density: Density = .comfortable, in theme: RaincoatTheme = .base
) -> RaincoatTokenSet {
    theme.tokens(mode: mode, density: density)
}

private func canonical(_ color: TokenColor) -> String {
    TokenFormat.string(color)
}

@Test(arguments: allThemes, ColorMode.allCases)
func eachStateOfAFieldTakesItsColorsFromItsTokens(theme: RaincoatTheme, mode: ColorMode) {
    let set = tokens(mode, in: theme)
    let source = set.flattened()
    func colors(enabled: Bool = true, invalid: Bool = false, readOnly: Bool = false) -> InputColors {
        InputColors(set.input, isEnabled: enabled, isInvalid: invalid, isReadOnly: readOnly)
    }

    let rest = colors()
    #expect(canonical(rest.fill) == source["input.bg.default"])
    #expect(canonical(rest.border) == source["input.border.default"])
    #expect(canonical(rest.foreground) == source["input.fg.default"])
    #expect(canonical(rest.placeholder) == source["input.placeholder"])

    let invalid = colors(invalid: true)
    #expect(canonical(invalid.fill) == source["input.bg.default"])
    #expect(canonical(invalid.border) == source["input.border.invalid"])
    #expect(canonical(invalid.foreground) == source["input.fg.default"])

    let readOnly = colors(readOnly: true)
    #expect(canonical(readOnly.fill) == source["input.bg.read-only"])
    #expect(canonical(readOnly.border) == source["input.border.read-only"])
    #expect(canonical(readOnly.foreground) == source["input.fg.default"])

    // An invalid read-only field keeps its fill and takes the danger outline.
    let both = colors(invalid: true, readOnly: true)
    #expect(canonical(both.fill) == source["input.bg.read-only"])
    #expect(canonical(both.border) == source["input.border.invalid"])

    // Disabled wins over everything else.
    for disabled in [colors(enabled: false), colors(enabled: false, invalid: true, readOnly: true)] {
        #expect(canonical(disabled.fill) == source["input.bg.disabled"])
        #expect(canonical(disabled.border) == source["input.border.disabled"])
        #expect(canonical(disabled.foreground) == source["input.fg.disabled"])
        #expect(canonical(disabled.placeholder) == source["input.fg.disabled"])
    }
}

@Test(arguments: allThemes, Density.allCases)
func eachSizeOfAFieldTakesItsMeasurementsFromItsTokens(theme: RaincoatTheme, density: Density) {
    let set = tokens(.light, density, in: theme)
    let source = set.flattened()
    for size in InputSize.allCases {
        let name = size.rawValue
        let measurements = InputMeasurements(set.input, size: size)
        #expect(TokenFormat.string(measurements.height) == source["input.height.\(name)"])
        #expect(TokenFormat.string(measurements.paddingInline) == source["input.padding-inline.\(name)"])
        #expect(TokenFormat.string(measurements.iconSize) == source["input.icon-size.\(name)"])
        #expect(TokenFormat.string(measurements.label) == source["input.label.\(name)"])
        #expect(TokenFormat.string(measurements.value) == source["input.value.\(name)"])

        // One line of the value, with the padding above and below, is exactly the height.
        let line = measurements.value.lineHeight * measurements.value.size
        #expect(abs(line + 2 * measurements.paddingBlock - measurements.height) < 0.0001)
    }
}

@Test func aFieldIsAsTallAsAButtonOfTheSameSize() {
    for density in Density.allCases {
        let set = tokens(.light, density)
        #expect(InputMeasurements(set.input, size: .sm).height == set.button.height.sm)
        #expect(InputMeasurements(set.input, size: .md).height == set.button.height.md)
        #expect(InputMeasurements(set.input, size: .lg).height == set.button.height.lg)
    }
}

@Test func eachTypeChoosesItsKeyboardAndAutofill() {
    let expected: [InputType: (InputKeyboard.Keys, InputKeyboard.Content)] = [
        .text: (.standard, .unspecified),
        .email: (.email, .email),
        .password: (.standard, .password),
        .search: (.search, .unspecified),
        .tel: (.phone, .phone),
        .url: (.url, .url),
    ]
    #expect(Set(expected.keys) == Set(InputType.allCases))
    for (type, (keys, content)) in expected {
        let keyboard = InputKeyboard(type)
        #expect(keyboard.keys == keys, "\(type)")
        #expect(keyboard.content == content, "\(type)")
        // Only a password is hidden as it is typed.
        #expect(keyboard.isSecure == (type == .password), "\(type)")
    }
}

@Test func addressesAndNumbersStayLeftToRightAndUncorrected() {
    for type in InputType.allCases {
        let keyboard = InputKeyboard(type)
        let isAddressOrNumber = [.email, .tel, .url].contains(type)
        #expect(keyboard.isLeftToRight == isAddressOrNumber, "\(type)")
        #expect(keyboard.corrects == (type == .text || type == .search), "\(type)")
    }
}
