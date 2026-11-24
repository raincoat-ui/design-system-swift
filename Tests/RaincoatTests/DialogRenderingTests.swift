#if canImport(SwiftUI) && canImport(CoreGraphics)
    import CoreGraphics
    @testable import Raincoat
    import RaincoatThemeBase
    import RaincoatTokens
    import SwiftUI
    import Testing

    // These tests draw a dialog as it is laid out in its sheet, into a bitmap, and read the
    // pixels back: its fill, the color of its title, where the title and the footer's buttons
    // start in each direction, and the footer's buttons stacking when they do not fit. The
    // system sheet around it, its sizing, and scrolling are checked by the reference app on a
    // simulator.

    /// A drawn view: its size in points and its pixels, at one pixel per point.
    @MainActor
    private struct Drawing {
        let width: Int
        let height: Int
        private let pixels: [UInt8]

        init(
            _ view: some View,
            theme: RaincoatTheme = .base,
            mode: ColorMode = .light,
            direction: LayoutDirection = .leftToRight,
            width: CGFloat
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

        /// The rows in which this color appears, in a column.
        func rows(of color: TokenColor, inColumn x: Int) -> [Int] {
            (0..<height).filter { has(color, at: x, $0) }
        }

        /// The columns in which this color appears, in a row.
        func columns(of color: TokenColor, inRow y: Int) -> [Int] {
            (0..<width).filter { has(color, at: $0, y) }
        }

        /// The columns, in some rows, of pixels that are not the color.
        func columns(notOf color: TokenColor, inRows rows: Range<Int>) -> [Int] {
            (0..<width).filter { x in rows.contains { y in !has(color, at: x, y) } }
        }
    }

    private func heading(
        _ title: String = "Rename file", description: String? = nil, closeLabel: String? = nil
    ) -> DialogHeading {
        DialogHeading(
            title: Text(title), level: 2, description: description.map { Text($0) },
            closeLabel: closeLabel.map { Text($0) }
        )
    }

    /// A dialog with a footer of Cancel and a primary action.
    @MainActor
    private func renameDialog(cancel: String = "Cancel", action: String = "Rename") -> some View {
        DialogPanel(
            heading: heading(description: "Everyone the file is shared with sees the new name."),
            content: EmptyView(),
            actions: Group {
                RaincoatButton(cancel) {}
                RaincoatButton(action, variant: .primary) {}
            }
        )
    }

    @MainActor @Suite struct DialogRenderingTests {
        @Test(arguments: allThemes, ColorMode.allCases)
        func aDialogIsFilledWithItsBackgroundAndItsTitleIsPaintedInItsForeground(
            theme: RaincoatTheme, mode: ColorMode
        ) throws {
            let look = DialogAppearance(theme.tokens(mode: mode, density: .comfortable))
            let drawing = try Drawing(renameDialog(), theme: theme, mode: mode, width: 400)
            #expect(drawing.has(look.background, at: 2, 2), "the fill at the top left corner")
            #expect(drawing.has(look.background, at: drawing.width - 3, drawing.height - 3), "and the bottom right")
            #expect(drawing.contains(look.foreground), "the title and description")
        }

        @Test(arguments: [LayoutDirection.leftToRight, .rightToLeft])
        func theTitleStartsThePaddingInFromTheLeadingEdge(direction: LayoutDirection) throws {
            let look = DialogAppearance(RaincoatTheme.base.tokens(mode: .light, density: .comfortable))
            let drawing = try Drawing(
                DialogPanel(heading: heading(), content: EmptyView(), actions: EmptyView()),
                direction: direction,
                width: 400
            )
            let padding = Int(look.padding)
            // Only the title is drawn, in the rows below the padding.
            let title = drawing.columns(notOf: look.background, inRows: padding..<(drawing.height - padding))
            let first = try #require(title.first, "the title is drawn")
            let last = try #require(title.last, "the title is drawn")
            if direction == .leftToRight {
                #expect(abs(first - padding) <= 2, "starts at the padding: \(first)")
                #expect(last < drawing.width / 2, "and is short")
            } else {
                #expect(abs(last - (drawing.width - 1 - padding)) <= 2, "starts at the padding: \(last)")
                #expect(first > drawing.width / 2, "and is short")
            }
            // A dialog with only a title is the padding, a line of the title, and the padding.
            let line = look.title.lineHeight * look.title.size
            #expect(abs(Double(drawing.height) - (2 * look.padding + line)) < 2, "height \(drawing.height)")
        }

        @Test(arguments: [LayoutDirection.leftToRight, .rightToLeft])
        func theFootersButtonsSitInARowAtTheTrailingEdgeThePrimaryLast(direction: LayoutDirection) throws {
            let set = RaincoatTheme.base.tokens(mode: .light, density: .comfortable)
            let look = DialogAppearance(set)
            let primary = set.button.primary.bg.default
            let drawing = try Drawing(renameDialog(), direction: direction, width: 400)
            let middle = drawing.width / 2
            // The primary button's fill, in the footer, the padding up from the bottom.
            let row = drawing.height - Int(look.padding) - Int(set.button.height.md / 2)
            let fill = drawing.columns(of: primary, inRow: row)
            let first = try #require(fill.first, "the primary button is drawn")
            let last = try #require(fill.last, "the primary button is drawn")
            let padding = Int(look.padding)
            if direction == .leftToRight {
                #expect(abs(last - (drawing.width - 1 - padding)) <= 2, "against the trailing edge: \(last)")
                #expect(first > middle, "on the right")
            } else {
                #expect(abs(first - padding) <= 2, "against the trailing edge: \(first)")
                #expect(last < middle, "on the left")
            }
            // Cancel is beside it, on the same line, and not above it.
            #expect(drawing.rows(of: primary, inColumn: (first + last) / 2).count < Int(set.button.height.md) + 2)
        }

        @Test(arguments: [LayoutDirection.leftToRight, .rightToLeft])
        func theFootersButtonsStackThePrimaryFirstWhenTheyDoNotFit(direction: LayoutDirection) throws {
            let set = RaincoatTheme.base.tokens(mode: .light, density: .comfortable)
            let look = DialogAppearance(set)
            let width: CGFloat = 280
            let title = heading("Delete this address?")
            let drawing = try Drawing(
                DialogPanel(
                    heading: title,
                    content: EmptyView(),
                    actions: Group {
                        RaincoatButton("Keep the address") {}
                        RaincoatButton("Delete the address", variant: .danger) {}
                    }
                ),
                direction: direction,
                width: width
            )
            // The title is drawn in the secondary button's border color, so only the rows below
            // the header count: the header alone is the padding, the title, and the padding, and
            // above a footer it keeps half the gap below the title instead.
            let header = try Drawing(
                DialogPanel(heading: title, content: EmptyView(), actions: EmptyView()),
                direction: direction,
                width: width
            )
            let footerTop = header.height - Int(look.padding) + Int(look.halfGap)
            let danger = set.button.danger.bg.default
            let border = set.button.secondary.border
            let center = drawing.width / 2
            let dangerRows = drawing.rows(of: danger, inColumn: center)
            let borderRows = drawing.rows(of: border, inColumn: center).filter { $0 >= footerTop }
            let dangerTop = try #require(dangerRows.first, "the danger button is drawn")
            let dangerBottom = try #require(dangerRows.last, "the danger button is drawn")
            let cancelTop = try #require(borderRows.first, "the secondary button is drawn")
            #expect(dangerTop >= footerTop, "the danger button is in the footer: \(dangerTop), \(footerTop)")
            #expect(dangerBottom < cancelTop, "the primary action is first, and the other is below it")
            // Each is as wide as the footer.
            let fill = drawing.columns(of: danger, inRow: dangerTop + 4)
            let padding = Int(look.padding)
            #expect(abs((fill.first ?? 0) - padding) <= 2, "from the leading padding: \(fill.first ?? -1)")
            #expect(abs((fill.last ?? 0) - (drawing.width - 1 - padding)) <= 2, "to the trailing padding")
        }

        @Test func aBodySitsBetweenTheHeaderAndTheFooterInTheDescriptionsColor() throws {
            let look = DialogAppearance(RaincoatTheme.base.tokens(mode: .light, density: .comfortable))
            let withBody = try Drawing(
                DialogPanel(
                    heading: heading(closeLabel: "Close"),
                    content: Text("Press N for a new file."),
                    actions: EmptyView()
                ),
                width: 400
            )
            let without = try Drawing(
                DialogPanel(heading: heading(closeLabel: "Close"), content: EmptyView(), actions: EmptyView()),
                width: 400
            )
            // The body adds a line of text, and the gap between it and the header: half on each side.
            let line = look.description.lineHeight * look.description.size
            let added = Double(withBody.height - without.height)
            #expect(abs(added - (line + look.gap)) < 2, "the body adds \(added)")
            #expect(withBody.contains(look.foreground), "the body's text")
        }
    }
#endif
