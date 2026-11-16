#if canImport(SwiftUI) && canImport(CoreGraphics)
    import CoreGraphics
    @testable import Raincoat
    import RaincoatThemeBase
    import RaincoatTokens
    import SwiftUI
    import Testing

    // These tests draw real buttons into a bitmap and read the pixels back, so they check what
    // SwiftUI actually lays out and paints: heights, fills, outlines, and the order of content.
    // Pressed and hover colors cannot be triggered here; ButtonAppearanceTests covers them.

    /// A drawn view: its size in points and its pixels, at one pixel per point.
    @MainActor
    private struct Drawing {
        let width: Int
        let height: Int
        private let pixels: [UInt8]

        /// - Parameters:
        ///   - mode: The color mode to draw in. SwiftUI lets a test set the color scheme but not
        ///     the contrast setting, so a high-contrast mode is drawn by a theme that answers
        ///     every request with that mode's tokens.
        ///   - width: The width offered to the view, or nil for its own ideal width.
        init(
            _ view: some View,
            mode: ColorMode = .light,
            density: Density = .comfortable,
            direction: LayoutDirection = .leftToRight,
            width: CGFloat? = nil
        ) throws {
            let theme = RaincoatTheme(id: "test-\(mode.rawValue)") { _, density in
                RaincoatTheme.base.tokens(mode: mode, density: density)
            }
            let renderer = ImageRenderer(
                content: view
                    .raincoatTheme(theme)
                    .raincoatDensity(density)
                    .environment(\.layoutDirection, direction)
            )
            renderer.scale = 1
            renderer.proposedSize = ProposedViewSize(width: width, height: nil)
            let image = try #require(renderer.cgImage)

            // Redraw into a bitmap of known layout: 8-bit sRGB, alpha last, not premultiplied
            // away (premultiplied, which is exact wherever alpha is 0 or 255).
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

        func isTransparent(_ x: Int, _ y: Int) -> Bool { pixel(x, y)[3] == 0 }

        /// Whether the pixel is this opaque color, give or take one step of rounding.
        func has(_ color: TokenColor, at x: Int, _ y: Int) -> Bool {
            let wanted = [color.red, color.green, color.blue, 1].map { Int(($0 * 255).rounded()) }
            return zip(pixel(x, y), wanted).allSatisfy { abs($0 - $1) <= 1 }
        }

        /// The rows of a column that have any paint, as a range.
        func paintedRows(inColumn x: Int) -> ClosedRange<Int>? {
            let rows = (0..<height).filter { !isTransparent(x, $0) }
            guard let first = rows.first, let last = rows.last else { return nil }
            return first...last
        }

        /// The columns of a row that have any paint, as a range.
        func paintedColumns(inRow y: Int) -> ClosedRange<Int>? {
            let columns = (0..<width).filter { !isTransparent($0, y) }
            guard let first = columns.first, let last = columns.last else { return nil }
            return first...last
        }

        /// The columns where this color appears anywhere.
        func columns(with color: TokenColor) -> [Int] {
            (0..<width).filter { x in (0..<height).contains { y in has(color, at: x, y) } }
        }
    }

    private func tokens(_ mode: ColorMode, _ density: Density = .comfortable) -> RaincoatTokenSet {
        RaincoatTheme.base.tokens(mode: mode, density: density)
    }

    /// A solid square of one color, to stand for an icon that is easy to find in a drawing.
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
    private let longLabel = "Save all of these changes and send the updated version to every reviewer"

    @MainActor
    @Test(arguments: ColorMode.allCases, ButtonVariant.allCases)
    func aButtonIsPaintedWithItsTokens(mode: ColorMode, variant: ButtonVariant) throws {
        let button = tokens(mode).button
        let drawing = try Drawing(RaincoatButton("Save", variant: variant) {}, mode: mode)
        let middle = drawing.height / 2
        // Just inside the outline, at the left edge and vertical middle; and on the outline.
        let inside = (x: 3, y: middle)
        let edge = (x: 0, y: middle)

        switch variant {
        case .primary:
            #expect(drawing.has(button.primary.bg.default, at: inside.x, inside.y))
            #expect(drawing.has(button.primary.bg.default, at: edge.x, edge.y))
        case .secondary:
            #expect(drawing.has(button.secondary.bg.default, at: inside.x, inside.y))
            #expect(drawing.has(button.secondary.border, at: edge.x, edge.y))
        case .ghost:
            #expect(drawing.isTransparent(inside.x, inside.y))
            #expect(drawing.isTransparent(edge.x, edge.y))
        case .danger:
            #expect(drawing.has(button.danger.bg.default, at: inside.x, inside.y))
            #expect(drawing.has(button.danger.bg.default, at: edge.x, edge.y))
        }

        // The label is drawn in the variant's foreground color.
        let foreground: TokenColor =
            switch variant {
            case .primary: button.primary.fg
            case .secondary: button.secondary.fg
            case .ghost: button.ghost.fg
            case .danger: button.danger.fg
            }
        #expect(!drawing.columns(with: foreground).isEmpty)
    }

    @MainActor
    @Test(arguments: ColorMode.allCases)
    func aDisabledButtonIsPaintedWithTheDisabledTokens(mode: ColorMode) throws {
        let disabled = tokens(mode).button.disabled
        for variant in ButtonVariant.allCases {
            let drawing = try Drawing(RaincoatButton("Save", variant: variant) {}.disabled(true), mode: mode)
            let middle = drawing.height / 2
            #expect(drawing.has(disabled.bg, at: 3, middle), "\(variant)")
            #expect(drawing.has(disabled.border, at: 0, middle), "\(variant)")
        }
    }

    @MainActor
    @Test(arguments: Density.allCases, ButtonSize.allCases)
    func aButtonIsAsTallAsItsTokenAndTakesNoMoreRoomThanItShows(density: Density, size: ButtonSize) throws {
        let button = tokens(.light, density).button
        let height = Int(ButtonHeight(button, size))
        let drawing = try Drawing(RaincoatButton("Save", variant: .primary, size: size) {}, density: density)

        // The layout size is the painted container. (A quarter of the way along is clear of
        // the round corners.)
        #expect(drawing.height == height)
        #expect(drawing.paintedRows(inColumn: drawing.width / 4)?.count == height)
    }

    @MainActor
    @Test(arguments: Density.allCases, ButtonSize.allCases)
    func anIconOnlyButtonIsSquare(density: Density, size: ButtonSize) throws {
        let button = tokens(.light, density).button
        let side = Int(ButtonHeight(button, size))
        let drawing = try Drawing(
            RaincoatButton(icon: marker(magenta), accessibilityLabel: Text("Delete page"), variant: .primary, size: size) {},
            density: density
        )
        #expect(drawing.width == side)
        #expect(drawing.height == side)
        #expect(drawing.paintedRows(inColumn: side / 2)?.count == side)
        #expect(drawing.paintedColumns(inRow: side / 2)?.count == side)

        // The icon is drawn at the token's icon size.
        let iconSize: Double =
            switch size {
            case .sm: button.iconSize.sm
            case .md: button.iconSize.md
            case .lg: button.iconSize.lg
            }
        #expect(drawing.columns(with: magenta).count == Int(iconSize))
    }

    @Test func theTouchTargetIsAtLeastTheMinimumAroundASmallerButton() {
        let target = TouchTarget(minimum: 44)
        // A small square button: the target reaches the same distance past every side.
        #expect(target.path(in: CGRect(x: 0, y: 0, width: 32, height: 32)).boundingRect == CGRect(x: -6, y: -6, width: 44, height: 44))
        // A wide button: only the height is short of the minimum.
        #expect(target.path(in: CGRect(x: 0, y: 0, width: 120, height: 40)).boundingRect == CGRect(x: 0, y: -2, width: 120, height: 44))
        // A button that is already large enough: the target is the button.
        #expect(target.path(in: CGRect(x: 0, y: 0, width: 120, height: 48)).boundingRect == CGRect(x: 0, y: 0, width: 120, height: 48))
    }

    @MainActor
    @Test func aLongLabelWrapsAndTheButtonGrowsTaller() throws {
        let button = tokens(.light).button
        let oneLine = try Drawing(RaincoatButton("Save", variant: .primary) {})
        let wrapped = try Drawing(RaincoatButton(longLabel, variant: .primary) {}, width: 220)
        let lineHeight = button.label.md.lineHeight * button.label.md.size

        #expect(oneLine.height == Int(button.height.md))
        #expect(wrapped.width == 220)
        // At least four lines of text, all of it inside the fill. (The middle column is
        // measured because the corners are round.)
        #expect(Double(wrapped.height) > 4 * lineHeight)
        #expect(wrapped.paintedRows(inColumn: wrapped.width / 2)?.count == wrapped.height)
        #expect(wrapped.has(button.primary.bg.default, at: 3, wrapped.height - 3))
    }

    @MainActor
    @Test func aFullWidthButtonFillsTheWidthItIsOffered() throws {
        let natural = try Drawing(RaincoatButton("Save", variant: .primary) {}, width: 300)
        let full = try Drawing(RaincoatButton("Save", variant: .primary, isFullWidth: true) {}, width: 300)
        #expect(natural.width < 300)
        #expect(full.width == 300)
        #expect(full.paintedColumns(inRow: full.height / 2) == 0...299)
    }

    @MainActor
    @Test(arguments: [LayoutDirection.leftToRight, .rightToLeft])
    func theLeadingIconIsOnTheSideWhereReadingStarts(direction: LayoutDirection) throws {
        let drawing = try Drawing(
            RaincoatButton("Next", variant: .secondary, leadingIcon: marker(magenta), trailingIcon: marker(cyan)) {},
            direction: direction
        )
        let leading = try #require(drawing.columns(with: magenta).first)
        let trailing = try #require(drawing.columns(with: cyan).first)
        if direction == .leftToRight {
            #expect(leading < trailing)
        } else {
            #expect(leading > trailing)
        }
    }

    @MainActor
    @Test func aLoadingButtonShowsASpinnerInPlaceOfTheLeadingIconAndKeepsItsColors() throws {
        let button = tokens(.light).button
        let plain = try Drawing(RaincoatButton("Save", variant: .primary) {})
        let withIcon = try Drawing(RaincoatButton("Save", variant: .primary, leadingIcon: marker(magenta)) {})
        let loading = try Drawing(
            RaincoatButton("Save", variant: .primary, leadingIcon: marker(magenta), isLoading: true) {}
        )
        let loadingWithoutIcon = try Drawing(RaincoatButton("Save", variant: .primary, isLoading: true) {})

        // The spinner takes the icon's place: same width with or without an icon, and wider
        // than the plain button by one icon and one gap.
        #expect(withIcon.columns(with: magenta).count == Int(button.iconSize.md))
        #expect(loading.columns(with: magenta).isEmpty)
        #expect(loading.width == withIcon.width)
        #expect(loadingWithoutIcon.width == withIcon.width)
        #expect(loading.width == plain.width + Int(button.iconSize.md + button.gap))
        #expect(loading.has(button.primary.bg.default, at: 3, loading.height / 2))
    }

    @MainActor
    @Test func aDisabledButtonIsNotAlsoBusy() throws {
        let disabled = try Drawing(RaincoatButton("Save", variant: .primary) {}.disabled(true))
        let disabledAndLoading = try Drawing(
            RaincoatButton("Save", variant: .primary, isLoading: true) {}.disabled(true)
        )
        #expect(disabledAndLoading.width == disabled.width)
    }

    @MainActor
    @Test func theStyleGivesAnyButtonTheSameLook() throws {
        let button = tokens(.dark).button
        let styled = try Drawing(
            Button("Read the guide") {}.buttonStyle(.raincoat(variant: .danger, size: .lg)),
            mode: .dark
        )
        #expect(styled.height == Int(button.height.lg))
        #expect(styled.has(button.danger.bg.default, at: 3, styled.height / 2))
    }

    /// The height token of a size.
    private func ButtonHeight(_ button: RaincoatTokenSet.ButtonTokens, _ size: ButtonSize) -> Double {
        switch size {
        case .sm: button.height.sm
        case .md: button.height.md
        case .lg: button.height.lg
        }
    }
#endif
