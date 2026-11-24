#if canImport(SwiftUI) && canImport(CoreGraphics)
    import CoreGraphics
    @testable import Raincoat
    import RaincoatThemeBase
    import RaincoatTokens
    import SwiftUI
    import Testing

    // These tests draw real cards into a bitmap and read the pixels back, so they check what
    // SwiftUI actually lays out and paints: the width a card takes, its fill and outline in each
    // state, the media at the top, the padding and the gap, wrapping, and the side the footer's
    // actions sit on. Hover and press cannot be triggered here; the state is set as the card
    // style sets it. Whatever a theme can change is drawn in every theme (allThemes, in
    // Generated/Themes.swift).

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
            width: CGFloat? = 300
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

        /// The columns of a row in this color.
        func columns(with color: TokenColor, inRow y: Int) -> [Int] {
            (0..<width).filter { has(color, at: $0, y) }
        }

        /// The rows of a column in this color.
        func rows(with color: TokenColor, inColumn x: Int) -> [Int] {
            (0..<height).filter { has(color, at: x, $0) }
        }

        /// The columns where this color appears anywhere.
        func columns(with color: TokenColor) -> [Int] {
            (0..<width).filter { x in (0..<height).contains { y in has(color, at: x, y) } }
        }
    }

    private func tokens(_ mode: ColorMode = .light, in theme: RaincoatTheme = .base) -> RaincoatTokenSet {
        theme.tokens(mode: mode, density: .comfortable)
    }

    /// A solid square of one color, to stand for a picture that is easy to find in a drawing.
    private func marker(_ color: TokenColor) -> Image {
        let context = CGContext(
            data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(red: color.red, green: color.green, blue: color.blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        return Image(decorative: context.makeImage()!, scale: 1)
    }

    private let magenta = TokenColor(hex: 0xFF00FF)
    private let cyan = TokenColor(hex: 0x00FFFF)
    private let longTitle = "Your order of three linen shirts and a wool scarf is on its way"

    /// The height of one line of a text style, in points.
    private func lineHeight(_ style: TokenTextStyle) -> Double { style.lineHeight * style.size }

    /// A static card with a title and a body, of a type that takes media and a footer.
    @MainActor
    private func storage() -> RaincoatCard<Text, Never, Never> {
        RaincoatCard("Storage", level: 3) { Text("4.2 GB of 15 GB used") }
    }

    @Suite struct CardRenderingTests {
        @MainActor
        @Test(arguments: allThemes, ColorMode.allCases)
        func aCardFillsItsWidthAndIsPaintedWithItsTokens(theme: RaincoatTheme, mode: ColorMode) throws {
            let card = tokens(mode, in: theme).card
            let drawing = try Drawing(storage(), theme: theme, mode: mode)
            let middle = drawing.height / 2
            #expect(drawing.width == 300, "the card fills the width it is offered")
            #expect(drawing.has(card.border.default, at: 0, middle), "the outline")
            #expect(drawing.has(card.border.default, at: drawing.width - 1, middle), "the outline")
            #expect(drawing.has(card.bg.default, at: Int(card.border.width) + 2, middle), "the fill")
        }

        @MainActor
        @Test(arguments: allThemes, ColorMode.allCases)
        func eachStateOfTheCardStyleIsPaintedWithItsTokens(theme: RaincoatTheme, mode: ColorMode) throws {
            let card = tokens(mode, in: theme).card
            for state in CardState.allCases {
                let colors = CardColors(card, state: state)
                let drawing = try Drawing(
                    storage().environment(\.raincoatCardState, state), theme: theme, mode: mode
                )
                let middle = drawing.height / 2
                #expect(drawing.has(colors.border, at: 0, middle), "the outline, \(state)")
                #expect(drawing.has(colors.fill, at: Int(card.border.width) + 2, middle), "the fill, \(state)")
            }
        }

        @MainActor
        @Test(arguments: allThemes)
        func aCardInTheCardStyleLooksStaticAtRest(theme: RaincoatTheme) throws {
            let card = tokens(in: theme).card
            let drawing = try Drawing(
                Button(action: {}, label: { storage() }).buttonStyle(.raincoatCard), theme: theme
            )
            let middle = drawing.height / 2
            #expect(drawing.width == 300, "the card fills the width it is offered")
            #expect(drawing.has(card.border.default, at: 0, middle), "the outline at rest")
            #expect(drawing.has(card.bg.default, at: Int(card.border.width) + 2, middle), "the fill at rest")
        }

        @MainActor
        @Test(arguments: allThemes)
        func thePartsAreInsideThePaddingTheGapApart(theme: RaincoatTheme) throws {
            let set = tokens(in: theme)
            let title = lineHeight(set.type.heading.sm)
            let body = lineHeight(set.type.body.md)
            let alone = try Drawing(RaincoatCard("Storage", level: 3), theme: theme)
            let withBody = try Drawing(
                RaincoatCard("Storage", level: 3) { Text("4.2 GB of 15 GB used").raincoatText() }, theme: theme
            )
            // The padding is inside the outline.
            let inset = set.card.border.width + set.card.padding
            #expect(abs(Double(alone.height) - (2 * inset + title)) < 2, "a title alone: \(alone.height)")
            #expect(
                abs(Double(withBody.height) - (2 * inset + title + set.card.gap + body)) < 3,
                "a title and a body: \(withBody.height)"
            )
        }

        @MainActor
        @Test(arguments: allThemes)
        func theMediaIsAtTheTopEdgeToEdgeAndTheTitleBelowIt(theme: RaincoatTheme) throws {
            let card = tokens(in: theme).card
            let title = lineHeight(tokens(in: theme).type.heading.sm)
            let drawing = try Drawing(
                RaincoatCard("Summer trip", level: 3)
                    .media { marker(magenta).resizable().frame(height: 40) },
                theme: theme
            )
            let border = Int(card.border.width)
            // Across the width, inside the outline.
            let across = drawing.columns(with: magenta, inRow: 20)
            #expect(across.first == border, "from the leading outline: \(across.first ?? -1)")
            #expect(across.last == drawing.width - 1 - border, "to the trailing outline: \(across.last ?? -1)")
            // From the top, inside the outline, 40 points tall.
            let down = drawing.rows(with: magenta, inColumn: drawing.width / 2)
            #expect(down.first == border, "from the top outline: \(down.first ?? -1)")
            #expect(down.last == 39, "40 points tall: \(down.last ?? -1)")
            // The title is the gap below it, and the padding and the outline below the title.
            #expect(
                abs(Double(drawing.height) - (40 + card.gap + title + card.padding + card.border.width)) < 2,
                "the height: \(drawing.height)"
            )
            // The top corners follow the card's.
            if card.radius > card.border.width + 2 {
                #expect(!drawing.has(magenta, at: border, border), "the top corner is round")
            }
        }

        @MainActor
        @Test(arguments: allThemes)
        func aLongTitleWrapsAndTheCardGrowsTaller(theme: RaincoatTheme) throws {
            let set = tokens(in: theme)
            let short = try Drawing(RaincoatCard("Order 1042", level: 3), theme: theme, width: 220)
            let long = try Drawing(RaincoatCard(longTitle, level: 3), theme: theme, width: 220)
            #expect(long.width == 220, "the card keeps its width")
            #expect(
                Double(long.height - short.height) > 1.5 * lineHeight(set.type.heading.sm),
                "\(long.height) against \(short.height)"
            )
        }

        @MainActor
        @Test(arguments: [LayoutDirection.leftToRight, .rightToLeft])
        func theFooterSitsAtTheTrailingEdge(direction: LayoutDirection) throws {
            let card = tokens().card
            let drawing = try Drawing(
                storage().footer { Rectangle().fill(Color(magenta)).frame(width: 40, height: 20) },
                direction: direction
            )
            let inset = Int(card.border.width + card.padding)
            let action = drawing.columns(with: magenta)
            if direction == .leftToRight {
                #expect(action.last == drawing.width - 1 - inset, "on the right: \(action.last ?? -1)")
            } else {
                #expect(action.first == inset, "on the left: \(action.first ?? -1)")
            }
        }

        @MainActor
        @Test func footerActionsThatDoNotFitMoveToAnotherRow() throws {
            let card = tokens().card
            let action = { (color: TokenColor) in Rectangle().fill(Color(color)).frame(width: 120, height: 20) }
            let wide = try Drawing(storage().footer { action(magenta); action(cyan) }, width: 400)
            let narrow = try Drawing(storage().footer { action(magenta); action(cyan) }, width: 220)
            // Side by side, the gap apart, when there is room.
            let first = try #require(wide.columns(with: magenta).last)
            let second = try #require(wide.columns(with: cyan).first)
            #expect(second - first - 1 == Int(card.gap), "the gap between them: \(second - first - 1)")
            // One under the other, the gap apart, when there is not.
            #expect(narrow.height - wide.height == 20 + Int(card.gap), "\(narrow.height) against \(wide.height)")
        }
    }
#endif
