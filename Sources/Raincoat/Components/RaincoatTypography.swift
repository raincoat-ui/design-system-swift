#if canImport(SwiftUI)
    import RaincoatTokens
    import SwiftUI

    extension View {
        /// Sets the text of this view in a Raincoat text style. It follows the Text part of the
        /// Raincoat Typography spec.
        ///
        ///     Text("Your files are kept on this device and in the cloud.").raincoatText()
        ///     Text("Synced 2 minutes ago").raincoatText(.caption, color: .muted)
        ///     Label("Shared with you", systemImage: "person.2").raincoatText(.labelMd)
        ///     Text(message.preview).raincoatText(maxLines: 2)
        ///
        /// It applies to any `Text`, `Label`, or `TextField`. The size, weight, line height, and
        /// color come from the theme in the environment; see `View.raincoatTheme(_:)`. The text
        /// aligns to the leading edge, grows with Dynamic Type, and wraps onto as many lines as
        /// it needs.
        ///
        /// - Parameters:
        ///   - variant: The text style.
        ///   - color: The color of the text, from the theme's text roles.
        ///   - maxLines: The most lines the text shows. Text beyond them ends in an ellipsis,
        ///     and VoiceOver still reads all of it. Use it only for text that is repeated
        ///     elsewhere. Nil, the default, lets the text wrap.
        public func raincoatText(
            _ variant: TextVariant = .standard,
            color: TextColor = .standard,
            maxLines: Int? = nil
        ) -> some View {
            modifier(TypographyModifier(choice: .text(variant, color), maxLines: maxLines))
        }

        /// Makes this view a heading of the screen's outline, in a Raincoat heading style. It
        /// follows the Heading part of the Raincoat Typography spec.
        ///
        ///     Text("Settings").raincoatHeading(level: 1)
        ///     Text("Recent files").raincoatHeading(level: 3, variant: .headingSm)
        ///
        /// VoiceOver is told that the view is a header, at its level, so people can move from
        /// heading to heading with the rotor. The heading wraps and is never cut short.
        ///
        /// - Parameters:
        ///   - level: The heading's place in the outline of the screen, from 1 to 6. Choose it
        ///     for that place, not for its size.
        ///   - variant: How the heading looks. Nil, the default, follows the level: 1 is
        ///     `headingXl`, 2 `headingLg`, 3 `headingMd`, and 4 to 6 `headingSm`.
        ///   - color: The color of the heading, from the theme's text roles.
        /// - Precondition: `level` is from 1 to 6.
        public func raincoatHeading(
            level: Int,
            variant: HeadingVariant? = nil,
            color: HeadingColor = .standard
        ) -> some View {
            let look = variant ?? .standard(level: level)
            return modifier(TypographyModifier(choice: .heading(look, color), maxLines: nil))
                .accessibilityAddTraits(.isHeader)
                .accessibilityHeading(AccessibilityHeadingLevel(level: level))
        }
    }

    extension AccessibilityHeadingLevel {
        /// The heading level for a level of the spec, from 1 to 6.
        init(level: Int) {
            switch level {
            case 1: self = .h1
            case 2: self = .h2
            case 3: self = .h3
            case 4: self = .h4
            case 5: self = .h5
            case 6: self = .h6
            default: preconditionFailure("A heading's level is a whole number from 1 to 6, not \(level).")
            }
        }
    }

    extension TextScaling {
        /// The system text style itself.
        var textStyle: Font.TextStyle {
            switch self {
            case .largeTitle: .largeTitle
            case .title2: .title2
            case .title3: .title3
            case .headline: .headline
            case .body: .body
            case .caption: .caption
            }
        }
    }

    /// Sets text in a token text style, through the same line-height handling as the Button's
    /// label, and grows it with the system text style nearest its role. A heading also grows to
    /// at least the size of the heading look below it (`TypographyChoice.scale`).
    private struct TypographyModifier: ViewModifier {
        let choice: TypographyChoice
        let maxLines: Int?

        @Tokens private var tokens
        // How much each system text style enlarges text at the person's setting. A heading
        // needs the styles of the looks below it too.
        @TextScale(relativeTo: .largeTitle) private var largeTitle
        @TextScale(relativeTo: .title2) private var title2
        @TextScale(relativeTo: .title3) private var title3
        @TextScale(relativeTo: .headline) private var headline
        @TextScale(relativeTo: .body) private var bodyText
        @TextScale(relativeTo: .caption) private var caption

        init(choice: TypographyChoice, maxLines: Int?) {
            self.choice = choice
            self.maxLines = maxLines
        }

        func body(content: Content) -> some View {
            let look = TextAppearance(tokens, choice)
            let scales = TextScales(
                largeTitle: largeTitle, title2: title2, title3: title3, headline: headline,
                body: bodyText, caption: caption
            )
            let text = look.style.resolved(scale: choice.scale(scales, headings: tokens.type.heading))
            content
                .font(text.font)
                .tracking(text.tracking)
                .lineSpacing(text.lineSpacing)
                .foregroundStyle(Color(look.color))
                // Lines start at the leading edge: the right in right-to-left layouts.
                .multilineTextAlignment(.leading)
                // Wrap onto as many lines as it takes, unless the app asked for fewer. A
                // limit from further up does not apply: max-lines is the way to cut text short.
                .lineLimit(maxLines)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                // One line is exactly as tall as the token's line height; more lines keep that
                // rhythm.
                .padding(.vertical, text.halfLeading)
                .frame(minHeight: text.lineHeight)
        }
    }
#endif
