import Foundation

/// A color in sRGB. Channels run from 0 to 1.
public struct TokenColor: Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Creates a color from a hex value such as `0xF7D22A`.
    public init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

/// A composed text style. Sizes are in points; the line height is a multiple of the size.
public struct TokenTextStyle: Hashable, Sendable {
    /// Font families in order of preference.
    public let families: [String]
    public let size: Double
    /// A weight from 1 to 1000, where 400 is regular.
    public let weight: Int
    public let letterSpacing: Double
    public let lineHeight: Double

    public init(families: [String], size: Double, weight: Int, letterSpacing: Double, lineHeight: Double) {
        self.families = families
        self.size = size
        self.weight = weight
        self.letterSpacing = letterSpacing
        self.lineHeight = lineHeight
    }
}

/// A cubic Bézier timing curve.
public struct TokenEasing: Hashable, Sendable {
    public let x1: Double
    public let y1: Double
    public let x2: Double
    public let y2: Double

    public init(x1: Double, y1: Double, x2: Double, y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }
}

/// The four color modes every theme provides.
public enum ColorMode: String, CaseIterable, Sendable {
    case light
    case dark
    case lightHighContrast = "light-hc"
    case darkHighContrast = "dark-hc"

    /// The mode for a color scheme and contrast setting.
    public init(isDark: Bool, increasedContrast: Bool) {
        switch (isDark, increasedContrast) {
        case (false, false): self = .light
        case (true, false): self = .dark
        case (false, true): self = .lightHighContrast
        case (true, true): self = .darkHighContrast
        }
    }
}

/// How tightly controls are sized.
public enum Density: String, CaseIterable, Sendable {
    case comfortable
    case compact
}

/// A theme: the token values for every color mode and density.
public struct RaincoatTheme: Sendable {
    public let id: String
    private let resolve: @Sendable (ColorMode, Density) -> RaincoatTokenSet

    public init(id: String, tokens: @escaping @Sendable (ColorMode, Density) -> RaincoatTokenSet) {
        self.id = id
        resolve = tokens
    }

    public func tokens(mode: ColorMode, density: Density) -> RaincoatTokenSet {
        resolve(mode, density)
    }
}

extension RaincoatTheme: Hashable {
    /// Themes are identified by their id.
    public static func == (lhs: RaincoatTheme, rhs: RaincoatTheme) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Writes token values as text in one canonical form, so that the values compiled into a theme
/// can be compared with the values in the token source.
public enum TokenFormat {
    public static func string(_ value: TokenColor) -> String {
        let channel = { (component: Double) in String(format: "%02x", Int((component * 255).rounded())) }
        let alpha = value.alpha < 1 ? channel(value.alpha) : ""
        return "#" + channel(value.red) + channel(value.green) + channel(value.blue) + alpha
    }

    public static func string(_ value: Double) -> String {
        String(format: "%.4f", value)
    }

    public static func string(_ value: Int) -> String {
        String(value)
    }

    public static func string(_ value: [String]) -> String {
        value.joined(separator: ", ")
    }

    public static func string(_ value: TokenEasing) -> String {
        [value.x1, value.y1, value.x2, value.y2].map { string($0) }.joined(separator: ",")
    }

    public static func string(_ value: TokenTextStyle) -> String {
        [
            string(value.families),
            string(value.size),
            string(value.weight),
            string(value.letterSpacing),
            string(value.lineHeight),
        ].joined(separator: "|")
    }
}
