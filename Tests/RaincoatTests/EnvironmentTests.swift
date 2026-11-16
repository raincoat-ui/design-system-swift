#if canImport(SwiftUI)
    import Raincoat
    import RaincoatThemeBase
    import RaincoatTokens
    import SwiftUI
    import Testing

    @MainActor
    @Test func theEnvironmentDefaultsToTheBaseThemeAtComfortableDensity() {
        let environment = EnvironmentValues()
        #expect(environment.raincoatTheme == .base)
        #expect(environment.raincoatDensity == .comfortable)
    }

    @MainActor
    @Test func aThemeAndDensityCanBeSetInTheEnvironment() {
        var environment = EnvironmentValues()
        environment.raincoatTheme = RaincoatTheme(id: "other") { mode, density in
            RaincoatTheme.base.tokens(mode: mode, density: density)
        }
        environment.raincoatDensity = .compact
        #expect(environment.raincoatTheme.id == "other")
        #expect(environment.raincoatDensity == .compact)
    }

    @Test func aTokenColorConvertsToASwiftUIColor() {
        let token = TokenColor(hex: 0xF7D22A)
        #expect(Color(token) == Color(.sRGB, red: token.red, green: token.green, blue: token.blue, opacity: 1))
    }
#endif
