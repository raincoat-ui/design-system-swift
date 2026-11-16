import RaincoatTokens
import Testing

@Test func colorFromHexSplitsChannels() {
    let color = TokenColor(hex: 0xF7D22A)
    #expect(color.red == 247.0 / 255)
    #expect(color.green == 210.0 / 255)
    #expect(color.blue == 42.0 / 255)
    #expect(color.alpha == 1)
}

@Test func colorFormatsBackToHex() {
    #expect(TokenFormat.string(TokenColor(hex: 0xF7D22A)) == "#f7d22a")
    #expect(TokenFormat.string(TokenColor(hex: 0x000000)) == "#000000")
    #expect(TokenFormat.string(TokenColor(hex: 0xFFFFFF, alpha: 0.5)) == "#ffffff80")
}

@Test func numbersFormatWithFourDecimals() {
    #expect(TokenFormat.string(16.0) == "16.0000")
    #expect(TokenFormat.string(0.1) == "0.1000")
    #expect(TokenFormat.string(500) == "500")
}

@Test func compositeValuesFormatFieldByField() {
    let style = TokenTextStyle(
        families: ["Be Vietnam Pro", "system-ui"], size: 16, weight: 500, letterSpacing: 0, lineHeight: 1.4
    )
    #expect(TokenFormat.string(style) == "Be Vietnam Pro, system-ui|16.0000|500|0.0000|1.4000")
    #expect(TokenFormat.string(TokenEasing(x1: 0.2, y1: 0, x2: 0, y2: 1)) == "0.2000,0.0000,0.0000,1.0000")
}

@Test func colorModeFollowsSchemeAndContrast() {
    #expect(ColorMode(isDark: false, increasedContrast: false) == .light)
    #expect(ColorMode(isDark: true, increasedContrast: false) == .dark)
    #expect(ColorMode(isDark: false, increasedContrast: true) == .lightHighContrast)
    #expect(ColorMode(isDark: true, increasedContrast: true) == .darkHighContrast)
}

@Test func modeAndDensityNamesMatchTheTokenSource() {
    #expect(ColorMode.allCases.map(\.rawValue) == ["light", "dark", "light-hc", "dark-hc"])
    #expect(Density.allCases.map(\.rawValue) == ["comfortable", "compact"])
}

@Test func themesAreComparedById() {
    let one = RaincoatTheme(id: "one") { _, _ in fatalError("not resolved in this test") }
    let alsoOne = RaincoatTheme(id: "one") { _, _ in fatalError("not resolved in this test") }
    let two = RaincoatTheme(id: "two") { _, _ in fatalError("not resolved in this test") }
    #expect(one == alsoOne)
    #expect(one != two)
}
