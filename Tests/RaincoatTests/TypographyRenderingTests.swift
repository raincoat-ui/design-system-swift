#if canImport(SwiftUI) && canImport(CoreGraphics)
    import CoreGraphics
    @testable import Raincoat
    import RaincoatThemeBase
    import RaincoatTokens
    import SwiftUI
    import Testing

    // These tests draw real text into a bitmap and read the pixels back, so they check what
    // SwiftUI actually lays out and paints: the height of a line, colors, wrapping, the ellipsis
    // after max-lines, and the side text starts on. Whatever a theme can change is drawn in
    // every theme (allThemes, in Generated/Themes.swift). Growth with Dynamic Type is checked by
    // the reference app on a simulator.

    /// A drawn view: its size in points and its pixels, at one pixel per point.
    @MainActor
    private struct Drawing {
        let width: Int
        let height: Int
        private let pixels: [UInt8]

        /// - Parameters:
        ///   - mode: The color mode to draw in. A high-contrast mode is drawn by a theme that
        ///     answers every request with that mode's tokens.
        ///   - width: The width offered to the view, or nil for its own ideal width.
        init(
            _ view: some View,
            theme: RaincoatTheme = .base,
            mode: ColorMode = .light,
            direction: LayoutDirection = .leftToRight,
            width: CGFloat? = nil
        ) throws {
            let fixed = RaincoatTheme(id: "\(theme.id)-\(mode.rawValue)") { _, density in
                theme.tokens(mode: mode, density: density)
            }
            let renderer = ImageRenderer(
                content: view
                    .raincoatTheme(fixed)
                    .environment(\.layoutDirection, direction)
            )
            renderer.scale = 1
            renderer.proposedSize = ProposedViewSize(width: width, height: nil)
            let image = try #require(renderer.cgImage)

            self.width = image.width
            self.height = image.height
            var buffer = [UInt8](repeating: 0, count: image.width * image.height * 4)
            let context = try #require(
                CGContext(
                    data: &buffer, width: image.width, height: image.height, bitsPerComponent: 8,
                    bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            )
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            pixels = buffer
        }

        /// The pixel at a point, with the origin at the top left: red, green, blue, alpha.
        func pixel(_ x: Int, _ y: Int) -> [Int] {
            let start = (y * width + x) * 4
            return pixels[start..<start + 4].map(Int.init)
        }

        /// Whether the pixel is this opaque color, give or take one step of rounding.
        func has(_ color: TokenColor, at x: Int, _ y: Int) -> Bool {
            let wanted = [color.red, color.green, color.blue, 1].map { Int(($0 * 255).rounded()) }
            return zip(pixel(x, y), wanted).allSatisfy { abs($0 - $1) <= 1 }
        }

        /// Whether this color appears anywhere.
        func contains(_ color: TokenColor) -> Bool {
            (0..<width).contains { x in (0..<height).contains { y in has(color, at: x, y) } }
        }
    }

    private let paragraph =
        "Your files are kept on this device and in the cloud. Changes made on one device reach the others the next time they connect."
    private let longHeading = "Notifications for comments, mentions, and changes to shared documents"

    /// The height of one line of a text style, in points.
    private func lineHeight(_ style: TokenTextStyle) -> Double { style.lineHeight * style.size }

    /// The tests are in a suite, so that a test of another component with the same name cannot
    /// clash with them.
    @Suite struct TypographyRenderingTests {
        @MainActor
        @Test(arguments: allThemes)
        func oneLineOfTextIsAsTallAsItsStylesLineHeight(theme: RaincoatTheme) throws {
            let type = theme.tokens(mode: .light, density: .comfortable).type
            let styles: [(TextVariant, TokenTextStyle)] = [
                (.bodyLg, type.body.lg), (.bodyMd, type.body.md), (.bodySm, type.body.sm),
                (.labelLg, type.label.lg), (.labelMd, type.label.md), (.labelSm, type.label.sm),
                (.caption, type.caption),
            ]
            for (variant, style) in styles {
                let drawing = try Drawing(Text("Synced 2 minutes ago").raincoatText(variant), theme: theme)
                #expect(abs(Double(drawing.height) - lineHeight(style)) < 1.5, "\(variant): \(drawing.height)")
            }
            let headings: [(Int, TokenTextStyle)] = [
                (1, type.heading.xl), (2, type.heading.lg), (3, type.heading.md), (4, type.heading.sm),
                (5, type.heading.sm), (6, type.heading.sm),
            ]
            for (level, style) in headings {
                let drawing = try Drawing(Text("Notifications").raincoatHeading(level: level), theme: theme)
                #expect(abs(Double(drawing.height) - lineHeight(style)) < 1.5, "level \(level): \(drawing.height)")
            }
        }

        @MainActor
        @Test func aHeadingVariantChangesTheLookAndNotTheLevel() throws {
            let type = RaincoatTheme.base.tokens(mode: .light, density: .comfortable).type
            let drawing = try Drawing(Text("Recent files").raincoatHeading(level: 1, variant: .headingSm))
            #expect(abs(Double(drawing.height) - lineHeight(type.heading.sm)) < 1.5)
        }

        @MainActor
        @Test(arguments: allThemes, ColorMode.allCases)
        func textIsPaintedInTheTokenOfItsColor(theme: RaincoatTheme, mode: ColorMode) throws {
            let fg = theme.tokens(mode: mode, density: .comfortable).color.fg
            let colors: [(TextColor, TokenColor)] = [(.default, fg.default), (.muted, fg.muted), (.danger, fg.danger)]
            for (color, token) in colors {
                let drawing = try Drawing(
                    Text("Settings").raincoatText(.labelLg, color: color), theme: theme, mode: mode
                )
                #expect(drawing.contains(token), "\(color)")
            }
            let headings: [(HeadingColor, TokenColor)] = [(.default, fg.default), (.muted, fg.muted)]
            for (color, token) in headings {
                let drawing = try Drawing(
                    Text("Settings").raincoatHeading(level: 2, color: color), theme: theme, mode: mode
                )
                #expect(drawing.contains(token), "heading in \(color)")
            }
        }

        @MainActor
        @Test(arguments: allThemes)
        func aLongHeadingWrapsAndIsNeverCutShort(theme: RaincoatTheme) throws {
            let xl = theme.tokens(mode: .light, density: .comfortable).type.heading.xl
            // A limit from further up does not cut a heading short.
            let drawing = try Drawing(
                Text(longHeading).raincoatHeading(level: 1).lineLimit(1), theme: theme, width: 240
            )
            #expect(drawing.width <= 240)
            #expect(Double(drawing.height) > 2.5 * lineHeight(xl))
        }

        @MainActor
        @Test(arguments: allThemes)
        func maxLinesCutsTextShortAfterThatManyLines(theme: RaincoatTheme) throws {
            let md = theme.tokens(mode: .light, density: .comfortable).type.body.md
            let whole = try Drawing(Text(paragraph).raincoatText(), theme: theme, width: 220)
            let two = try Drawing(Text(paragraph).raincoatText(maxLines: 2), theme: theme, width: 220)
            let one = try Drawing(Text(paragraph).raincoatText(maxLines: 1), theme: theme, width: 220)
            #expect(Double(whole.height) > 3 * lineHeight(md))
            #expect(abs(Double(two.height) - 2 * lineHeight(md)) < 2, "\(two.height)")
            #expect(abs(Double(one.height) - lineHeight(md)) < 1.5, "\(one.height)")
        }

        @MainActor
        @Test(arguments: [LayoutDirection.leftToRight, .rightToLeft])
        func textStartsOnTheSideWhereReadingStarts(direction: LayoutDirection) throws {
            // A short word, then a long one that fills the width: the short line starts at the
            // leading edge.
            let drawing = try Drawing(
                Text("Hi\n" + longHeading).raincoatText().frame(maxWidth: .infinity, alignment: .leading),
                direction: direction,
                width: 400
            )
            let firstLine = (0..<drawing.width).filter { x in
                (0..<Int(drawing.height / 4)).contains { y in drawing.pixel(x, y)[3] > 0 }
            }
            let first = try #require(firstLine.first)
            let last = try #require(firstLine.last)
            if direction == .leftToRight {
                #expect(first < 8)
                #expect(last < drawing.width / 2)
            } else {
                #expect(last > drawing.width - 8)
                #expect(first > drawing.width / 2)
            }
        }

        @MainActor
        @Test func theStyleAppliesToALabelAndATextField() throws {
            let md = RaincoatTheme.base.tokens(mode: .light, density: .comfortable).type.label.md
            let label = try Drawing(Label("Shared with you", systemImage: "person.2").raincoatText(.labelMd))
            #expect(abs(Double(label.height) - lineHeight(md)) < 2, "\(label.height)")
            let field = try Drawing(
                TextField("Name", text: .constant("Ada")).raincoatText(.labelMd), width: 200
            )
            #expect(Double(field.height) >= lineHeight(md) - 1, "\(field.height)")
        }
    }
#endif
