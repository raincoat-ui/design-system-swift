#if canImport(SwiftUI)
    import CoreText
    import RaincoatTokens
    import SwiftUI

    #if canImport(UIKit)
        import UIKit
    #endif

    /// How much the person's text size setting enlarges a system text style: the system font's
    /// size for the style at the environment's Dynamic Type size over its size at the default,
    /// such as 53 / 17 for body text at the largest accessibility size. That is how the system
    /// grows the style's own text.
    ///
    /// `@ScaledMetric` scales by a factor of its own, 2.82 at the largest accessibility size,
    /// where the system's body font is 3.12 times as large, so it is not used. A Mac has no
    /// Dynamic Type, and the scale there is 1.
    @propertyWrapper
    struct TextScale: DynamicProperty {
        private let textStyle: Font.TextStyle
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        init(relativeTo textStyle: Font.TextStyle) {
            self.textStyle = textStyle
        }

        var wrappedValue: CGFloat {
            #if canImport(UIKit)
                let style = textStyle.uiKit
                let category = dynamicTypeSize.uiKit
                // Views are drawn on the main actor.
                return MainActor.assumeIsolated { () -> CGFloat in
                    let size = { (category: UIContentSizeCategory) in
                        UIFont.preferredFont(
                            forTextStyle: style,
                            compatibleWith: UITraitCollection(preferredContentSizeCategory: category)
                        ).pointSize
                    }
                    return size(category) / size(.large)
                }
            #else
                return 1
            #endif
        }
    }

    #if canImport(UIKit)
        extension Font.TextStyle {
            /// The UIKit text style of the same role.
            var uiKit: UIFont.TextStyle {
                switch self {
                case .largeTitle: return .largeTitle
                case .title: return .title1
                case .title2: return .title2
                case .title3: return .title3
                case .headline: return .headline
                case .subheadline: return .subheadline
                case .callout: return .callout
                case .footnote: return .footnote
                case .caption: return .caption1
                case .caption2: return .caption2
                default: return .body
                }
            }
        }

        extension DynamicTypeSize {
            /// The UIKit text size of the same name.
            var uiKit: UIContentSizeCategory {
                switch self {
                case .xSmall: return .extraSmall
                case .small: return .small
                case .medium: return .medium
                case .large: return .large
                case .xLarge: return .extraLarge
                case .xxLarge: return .extraExtraLarge
                case .xxxLarge: return .extraExtraExtraLarge
                case .accessibility1: return .accessibilityMedium
                case .accessibility2: return .accessibilityLarge
                case .accessibility3: return .accessibilityExtraLarge
                case .accessibility4: return .accessibilityExtraExtraLarge
                case .accessibility5: return .accessibilityExtraExtraExtraLarge
                @unknown default: return .large
                }
            }
        }
    #endif

    /// A token text style made ready for SwiftUI.
    struct ResolvedTextStyle {
        let font: Font
        let tracking: CGFloat
        /// Height of one line as the token defines it.
        let lineHeight: CGFloat
        /// Extra space between lines, which brings the distance between baselines to the
        /// token's line height.
        let lineSpacing: CGFloat
        /// Space to add above the first line and below the last, so that a block of text is
        /// about as tall as its lines at the token's line height. It is rounded down, so that
        /// one line never exceeds `lineHeight`; give the text that as its minimum height.
        let halfLeading: CGFloat
    }

    extension TokenTextStyle {
        // CSS keywords in a font stack. They name no font file; the system font stands in.
        private static let genericFamilies: Set<String> = [
            "system-ui", "sans-serif", "serif", "monospace", "cursive", "fantasy",
            "ui-sans-serif", "ui-serif", "ui-monospace", "ui-rounded",
        ]

        /// The first family of the style that is installed, or registered by the app.
        var installedFamily: String? {
            families.first { family in
                guard !Self.genericFamilies.contains(family) else { return false }
                let wanted = CTFontDescriptorCreateWithAttributes(
                    [kCTFontFamilyNameAttribute: family] as CFDictionary
                )
                // The family is mandatory: without that, a missing family matches a fallback.
                let mandatory = NSSet(object: kCTFontFamilyNameAttribute) as CFSet
                return CTFontDescriptorCreateMatchingFontDescriptor(wanted, mandatory) != nil
            }
        }

        /// - Parameter scale: how much the person's text size setting enlarges text; 1 at the
        ///   default setting.
        func resolved(scale: CGFloat = 1) -> ResolvedTextStyle {
            let pointSize = size * scale
            let font: Font
            let metrics: CTFont
            if let family = installedFamily {
                font = Font.custom(family, fixedSize: pointSize).weight(fontWeight)
                metrics = CTFontCreateWithFontDescriptor(
                    CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary),
                    pointSize,
                    nil
                )
            } else {
                font = Font.system(size: pointSize, weight: fontWeight)
                metrics =
                    CTFontCreateUIFontForLanguage(.system, pointSize, nil)
                    ?? CTFontCreateWithName("Helvetica" as CFString, pointSize, nil)
            }
            let natural = CTFontGetAscent(metrics) + CTFontGetDescent(metrics) + CTFontGetLeading(metrics)
            let target = lineHeight * pointSize
            return ResolvedTextStyle(
                font: font,
                tracking: letterSpacing * scale,
                lineHeight: target,
                lineSpacing: max(0, target - natural),
                // SwiftUI lays a line out on whole points, so the font's own height is rounded up.
                halfLeading: max(0, (target - natural.rounded(.up)) / 2)
            )
        }

        private var fontWeight: Font.Weight {
            switch weight {
            case ..<150: .ultraLight
            case ..<250: .thin
            case ..<350: .light
            case ..<450: .regular
            case ..<550: .medium
            case ..<650: .semibold
            case ..<750: .bold
            case ..<850: .heavy
            default: .black
            }
        }
    }
#endif
