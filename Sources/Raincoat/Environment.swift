// The token types, such as ButtonVariant and Density, are part of this module's API, so that
// `import Raincoat` is all an app needs to use a component.
@_exported import RaincoatTokens

#if canImport(SwiftUI)
    import RaincoatThemeBase
    import SwiftUI

    extension EnvironmentValues {
        /// The theme components draw with. Defaults to the Raincoat base theme.
        @Entry public var raincoatTheme: RaincoatTheme = .base

        /// The density components lay out with.
        @Entry public var raincoatDensity: Density = .comfortable
    }

    extension View {
        /// Applies a Raincoat theme to this view and everything inside it.
        ///
        /// An app calls this once, near its root, with the theme module it links:
        /// `ContentView().raincoatTheme(.base)`.
        public func raincoatTheme(_ theme: RaincoatTheme) -> some View {
            environment(\.raincoatTheme, theme)
        }

        /// Sets the density for this view and everything inside it.
        public func raincoatDensity(_ density: Density) -> some View {
            environment(\.raincoatDensity, density)
        }
    }

    /// The tokens for the current theme, color scheme, contrast setting, and density.
    ///
    /// Components read every color, size, and text style through this wrapper, so they follow
    /// the system's appearance settings without any code of their own:
    ///
    ///     @Tokens private var tokens
    ///     var body: some View { Text("Hello").foregroundStyle(Color(tokens.color.fg.default)) }
    @propertyWrapper
    public struct Tokens: DynamicProperty {
        @Environment(\.raincoatTheme) private var theme
        @Environment(\.raincoatDensity) private var density
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.colorSchemeContrast) private var contrast

        public init() {}

        public var wrappedValue: RaincoatTokenSet {
            theme.tokens(
                mode: ColorMode(isDark: colorScheme == .dark, increasedContrast: contrast == .increased),
                density: density
            )
        }
    }

    extension Color {
        /// Creates a SwiftUI color from a token color.
        public init(_ token: TokenColor) {
            self.init(.sRGB, red: token.red, green: token.green, blue: token.blue, opacity: token.alpha)
        }
    }
#endif
