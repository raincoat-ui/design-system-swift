import RaincoatThemeBase
import RaincoatTokens
import Testing

@testable import Raincoat

// The mapping from a Text or Heading's variant and color to its tokens. Expected values are
// looked up by token id, built from the variant's and color's names in the spec, so these tests
// do not repeat the switch statements they check. This file uses no SwiftUI and runs on Linux.
// The mappings are checked in every theme (allThemes, in Generated/Themes.swift).

/// The id of a variant's text style: body-lg is type.body.lg, caption is type.caption.
private func styleId(_ variant: String) -> String {
    "type." + variant.split(separator: "-").joined(separator: ".")
}

/// The tests are in a suite, so that a test of another component with the same name cannot clash
/// with them.
@Suite struct TypographyAppearanceTests {
    @Test(arguments: allThemes, ColorMode.allCases)
    func eachTextVariantAndColorTakesItsTokens(theme: RaincoatTheme, mode: ColorMode) {
        let set = theme.tokens(mode: mode, density: .comfortable)
        let source = set.flattened()
        for variant in TextVariant.allCases {
            for color in TextColor.allCases {
                let appearance = TextAppearance(set, variant: variant, color: color)
                #expect(TokenFormat.string(appearance.style) == source[styleId(variant.rawValue)], "\(variant)")
                #expect(TokenFormat.string(appearance.color) == source["color.fg.\(color.rawValue)"], "\(color)")
                #expect(TextAppearance(set, .text(variant, color)) == appearance)
            }
        }
    }

    @Test(arguments: allThemes, ColorMode.allCases)
    func eachHeadingVariantAndColorTakesItsTokens(theme: RaincoatTheme, mode: ColorMode) {
        let set = theme.tokens(mode: mode, density: .comfortable)
        let source = set.flattened()
        for variant in HeadingVariant.allCases {
            for color in HeadingColor.allCases {
                let appearance = TextAppearance(set, variant: variant, color: color)
                #expect(TokenFormat.string(appearance.style) == source[styleId(variant.rawValue)], "\(variant)")
                #expect(TokenFormat.string(appearance.color) == source["color.fg.\(color.rawValue)"], "\(color)")
                #expect(TextAppearance(set, .heading(variant, color)) == appearance)
            }
        }
    }

    @Test func textStylesDoNotChangeWithDensity() {
        let comfortable = RaincoatTheme.base.tokens(mode: .light, density: .comfortable)
        let compact = RaincoatTheme.base.tokens(mode: .light, density: .compact)
        for variant in TextVariant.allCases {
            #expect(
                TextAppearance(comfortable, variant: variant, color: .default)
                    == TextAppearance(compact, variant: variant, color: .default)
            )
        }
    }

    @Test func aHeadingLooksAsItsLevelSaysUnlessToldOtherwise() {
        // As the spec says: 1 is heading-xl, 2 heading-lg, 3 heading-md, and 4 to 6 heading-sm.
        let looks = (1...6).map { HeadingVariant.standard(level: $0) }
        #expect(looks == [.headingXl, .headingLg, .headingMd, .headingSm, .headingSm, .headingSm])
        #expect(HeadingVariant.standardByLevel.keys.sorted() == Array(1...6))
    }

    @Test func eachStyleGrowsWithTheSystemTextStyleNearestItsRole() {
        #expect(TextScaling(HeadingVariant.headingXl) == .largeTitle)
        #expect(TextScaling(HeadingVariant.headingLg) == .title2)
        #expect(TextScaling(HeadingVariant.headingMd) == .title3)
        #expect(TextScaling(HeadingVariant.headingSm) == .headline)
        for variant in TextVariant.allCases {
            #expect(TextScaling(variant) == (variant == .caption ? .caption : .body), "\(variant)")
        }
        #expect(TextScaling(.text(.caption, .muted)) == .caption)
        #expect(TextScaling(.heading(.headingMd, .default)) == .title3)
    }
}

/// The point size of each system text style that Raincoat grows with, at each Dynamic Type size,
/// from the smallest to the largest accessibility size, as Apple's Human Interface Guidelines
/// list them for iOS. The fourth, Large, is the default.
private let dynamicTypeSizes: [TextScaling: [Double]] = [
    .largeTitle: [31, 32, 33, 34, 36, 38, 40, 44, 48, 52, 56, 60],
    .title2: [19, 20, 21, 22, 24, 26, 28, 34, 39, 44, 50, 56],
    .title3: [17, 18, 19, 20, 22, 24, 26, 31, 37, 43, 49, 55],
    .headline: [14, 15, 16, 17, 19, 21, 23, 28, 33, 40, 47, 53],
    .body: [14, 15, 16, 17, 19, 21, 23, 28, 33, 40, 47, 53],
    .caption: [11, 11, 11, 12, 14, 16, 18, 22, 26, 32, 37, 43],
]
private let dynamicTypeSizeNames = [
    "xSmall", "small", "medium", "large", "xLarge", "xxLarge", "xxxLarge",
    "accessibility1", "accessibility2", "accessibility3", "accessibility4", "accessibility5",
]
private let defaultDynamicTypeSize = 3
private let largestDynamicTypeSize = 11

/// How much each system text style enlarges text at one Dynamic Type size, by its index.
private func textScales(at size: Int) -> TextScales {
    func scale(_ style: TextScaling) -> Double {
        let sizes = dynamicTypeSizes[style] ?? []
        return sizes[size] / sizes[defaultDynamicTypeSize]
    }
    return TextScales(
        largeTitle: scale(.largeTitle), title2: scale(.title2), title3: scale(.title3),
        headline: scale(.headline), body: scale(.body), caption: scale(.caption)
    )
}

/// How text grows with Dynamic Type, at every size. On Linux too: the sizes come from the table
/// above, and SwiftUI on macOS does not enlarge text for a larger Dynamic Type size. The
/// reference app checks the order of the headings on an iOS simulator.
@Suite struct TypographyScalingTests {
    /// The point size of each heading look, from the largest, at one Dynamic Type size.
    private func headingSizes(_ theme: RaincoatTheme, at size: Int) -> [Double] {
        let headings = theme.tokens(mode: .light, density: .comfortable).type.heading
        return HeadingVariant.allCases.map { look in
            let scale = TypographyChoice.heading(look, .default).scale(textScales(at: size), headings: headings)
            return TextAppearance.style(of: look, in: headings).size * scale
        }
    }

    @Test(arguments: allThemes)
    func typographyHeadingsAreNeverSmallerThanTheLevelBelowAtAnyTextSize(theme: RaincoatTheme) {
        for size in dynamicTypeSizeNames.indices {
            let sizes = headingSizes(theme, at: size)
            for (larger, smaller) in zip(sizes, sizes.dropFirst()) {
                #expect(larger >= smaller, "heading sizes at \(dynamicTypeSizeNames[size]): \(sizes)")
            }
        }
    }

    @Test(arguments: allThemes)
    func typographyHeadingsGrowAtLeastWithTheirOwnTextStyle(theme: RaincoatTheme) {
        let headings = theme.tokens(mode: .light, density: .comfortable).type.heading
        for size in dynamicTypeSizeNames.indices {
            let scales = textScales(at: size)
            for look in HeadingVariant.allCases {
                let scale = TypographyChoice.heading(look, .default).scale(scales, headings: headings)
                #expect(scale >= scales[TextScaling(look)], "\(look) at \(dynamicTypeSizeNames[size])")
            }
        }
        // At the default size nothing is enlarged.
        for look in HeadingVariant.allCases {
            let scale = TypographyChoice.heading(look, .default)
                .scale(textScales(at: defaultDynamicTypeSize), headings: headings)
            #expect(scale == 1, "\(look) at the default size")
        }
    }

    @Test func typographyHeadingXlKeepsUpWithHeadingLgAtTheLargestSize() {
        // Large Title grows from 34 to 60 points and Title 2 from 22 to 56. By its own style
        // alone, a 32-point heading-xl would be drawn at about 56 points and a 24-point
        // heading-lg at about 61.
        let headings = RaincoatTheme.base.tokens(mode: .light, density: .comfortable).type.heading
        let largest = textScales(at: largestDynamicTypeSize)
        let own = headings.xl.size * largest.largeTitle
        let lg = headings.lg.size * largest.title2
        #expect(own < lg, "heading-xl by its own style: \(own); heading-lg: \(lg)")
        let scale = TypographyChoice.heading(.headingXl, .default).scale(largest, headings: headings)
        let xl = headings.xl.size * scale
        #expect(abs(xl - lg) < 0.0001, "heading-xl is drawn as large as heading-lg: \(xl) and \(lg)")
    }

    @Test func typographyTextGrowsWithItsOwnTextStyle() {
        let headings = RaincoatTheme.base.tokens(mode: .light, density: .comfortable).type.heading
        let largest = textScales(at: largestDynamicTypeSize)
        for variant in TextVariant.allCases {
            let scale = TypographyChoice.text(variant, .default).scale(largest, headings: headings)
            #expect(scale == largest[TextScaling(variant)], "\(variant)")
        }
    }
}
