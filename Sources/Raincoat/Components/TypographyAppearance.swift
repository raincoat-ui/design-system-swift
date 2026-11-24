import RaincoatTokens

// What Text and Heading look like for a variant and a color, taken from the semantic text
// styles and text colors. This file uses no SwiftUI, so its tests also run on Linux.

/// What a piece of text is set as: a Text style and color, or a Heading look and color.
enum TypographyChoice: Hashable, Sendable {
    case text(TextVariant, TextColor)
    case heading(HeadingVariant, HeadingColor)
}

/// The system text style that a Raincoat text style grows with when the person changes their
/// text size: the one nearest its role. Large headings grow less than body text, as the
/// system's own do.
enum TextScaling: Hashable, CaseIterable, Sendable {
    case largeTitle
    case title2
    case title3
    case headline
    case body
    case caption

    // The switches below are exhaustive on purpose: a variant added to the spec does not
    // compile until it is given a style here.

    init(_ variant: TextVariant) {
        switch variant {
        case .bodyLg, .bodyMd, .bodySm, .labelLg, .labelMd, .labelSm: self = .body
        case .caption: self = .caption
        }
    }

    init(_ variant: HeadingVariant) {
        switch variant {
        case .headingXl: self = .largeTitle
        case .headingLg: self = .title2
        case .headingMd: self = .title3
        case .headingSm: self = .headline
        }
    }

    init(_ choice: TypographyChoice) {
        switch choice {
        case .text(let variant, _): self.init(variant)
        case .heading(let variant, _): self.init(variant)
        }
    }
}

/// The text style and color of a piece of text.
struct TextAppearance: Hashable, Sendable {
    let style: TokenTextStyle
    let color: TokenColor

    init(_ tokens: RaincoatTokenSet, variant: TextVariant, color: TextColor) {
        let type = tokens.type
        switch variant {
        case .bodyLg: style = type.body.lg
        case .bodyMd: style = type.body.md
        case .bodySm: style = type.body.sm
        case .labelLg: style = type.label.lg
        case .labelMd: style = type.label.md
        case .labelSm: style = type.label.sm
        case .caption: style = type.caption
        }
        switch color {
        case .default: self.color = tokens.color.fg.default
        case .muted: self.color = tokens.color.fg.muted
        case .danger: self.color = tokens.color.fg.danger
        }
    }

    init(_ tokens: RaincoatTokenSet, variant: HeadingVariant, color: HeadingColor) {
        style = Self.style(of: variant, in: tokens.type.heading)
        switch color {
        case .default: self.color = tokens.color.fg.default
        case .muted: self.color = tokens.color.fg.muted
        }
    }

    init(_ tokens: RaincoatTokenSet, _ choice: TypographyChoice) {
        switch choice {
        case .text(let variant, let color): self.init(tokens, variant: variant, color: color)
        case .heading(let variant, let color): self.init(tokens, variant: variant, color: color)
        }
    }
}

/// How much each system text style enlarges text at the person's text size setting: 1 at the
/// default size. SwiftUI gives each one through `TextScale(relativeTo:)`.
struct TextScales: Hashable, Sendable {
    var largeTitle: Double = 1
    var title2: Double = 1
    var title3: Double = 1
    var headline: Double = 1
    var body: Double = 1
    var caption: Double = 1

    subscript(scaling: TextScaling) -> Double {
        switch scaling {
        case .largeTitle: largeTitle
        case .title2: title2
        case .title3: title3
        case .headline: headline
        case .body: body
        case .caption: caption
        }
    }
}

extension TypographyChoice {
    /// How much this text is enlarged at the person's text size setting: 1 at the default size.
    ///
    /// Text grows with the system text style nearest its role. A heading also grows to at least
    /// the size of the heading look below it, so that a heading is never smaller than the
    /// heading one level below it. iOS enlarges its large title less than its smaller titles:
    /// at the largest accessibility size, heading-xl would otherwise be smaller than heading-lg.
    func scale(_ scales: TextScales, headings: RaincoatTokenSet.TypeHeadingTokens) -> Double {
        switch self {
        case .text(let variant, _):
            return scales[TextScaling(variant)]
        case .heading(let variant, _):
            let size = { (look: HeadingVariant) in TextAppearance.style(of: look, in: headings).size }
            return Self.headingSize(variant, scales, size) / size(variant)
        }
    }

    /// The point size of a heading look at the person's setting: its own scaled size, or the
    /// size of the look below it, whichever is larger. The looks are in the spec's order, from
    /// the largest.
    private static func headingSize(
        _ look: HeadingVariant, _ scales: TextScales, _ size: (HeadingVariant) -> Double
    ) -> Double {
        let own = size(look) * scales[TextScaling(look)]
        let looks = HeadingVariant.allCases
        guard let index = looks.firstIndex(of: look), index + 1 < looks.count else { return own }
        return max(own, headingSize(looks[index + 1], scales, size))
    }
}

extension TextAppearance {
    /// The text style of a heading look.
    static func style(of look: HeadingVariant, in headings: RaincoatTokenSet.TypeHeadingTokens) -> TokenTextStyle {
        switch look {
        case .headingXl: headings.xl
        case .headingLg: headings.lg
        case .headingMd: headings.md
        case .headingSm: headings.sm
        }
    }
}

extension HeadingVariant {
    /// How a heading of this level looks unless it is told otherwise, as the spec says: 1 is
    /// `headingXl`, 2 `headingLg`, 3 `headingMd`, and 4 to 6 `headingSm`.
    ///
    /// - Precondition: `level` is from 1 to 6.
    static func standard(level: Int) -> HeadingVariant {
        guard let variant = standardByLevel[level] else {
            preconditionFailure("A heading's level is a whole number from 1 to 6, not \(level).")
        }
        return variant
    }
}
