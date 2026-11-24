#if canImport(SwiftUI) && canImport(CoreGraphics)
    import CoreGraphics
    @testable import Raincoat
    import RaincoatThemeBase
    import RaincoatTokens
    import SwiftUI
    import Testing

    // These tests draw a row of real tabs into a bitmap and read the pixels back, so they check
    // what SwiftUI lays out and paints: heights, labels on one line, the indicator, and the order
    // of the tabs. They draw the row without its scroll view, which ImageRenderer does not draw:
    // the reference app's UI tests check the scrolling row on a simulator. Hover and pressed
    // colors cannot be triggered here; TabsAppearanceTests covers them.

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
            density: Density = .comfortable,
            direction: LayoutDirection = .leftToRight,
            width: CGFloat? = nil
        ) throws {
            let fixed = RaincoatTheme(id: "\(theme.id)-\(mode.rawValue)") { _, density in
                theme.tokens(mode: mode, density: density)
            }
            let renderer = ImageRenderer(
                content: view
                    .raincoatTheme(fixed)
                    .raincoatDensity(density)
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

        func isTransparent(_ x: Int, _ y: Int) -> Bool { pixel(x, y)[3] == 0 }

        /// Whether the pixel is this opaque color, give or take one step of rounding.
        func has(_ color: TokenColor, at x: Int, _ y: Int) -> Bool {
            let wanted = [color.red, color.green, color.blue, 1].map { Int(($0 * 255).rounded()) }
            return zip(pixel(x, y), wanted).allSatisfy { abs($0 - $1) <= 1 }
        }

        /// The columns where this color appears in a row.
        func columns(with color: TokenColor, inRow y: Int) -> [Int] {
            (0..<width).filter { has(color, at: $0, y) }
        }

        /// The columns where this color appears anywhere.
        func columns(with color: TokenColor) -> [Int] {
            (0..<width).filter { x in (0..<height).contains { y in has(color, at: x, y) } }
        }
    }

    private func tokens(
        _ mode: ColorMode, _ density: Density = .comfortable, in theme: RaincoatTheme = .base
    ) -> RaincoatTokenSet {
        theme.tokens(mode: mode, density: density)
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

    /// A row of tabs as RaincoatTabs lays them out, without the scroll view around them.
    @MainActor
    private func strip(_ labels: [String], selected: Int = 0, icons: [Image?] = []) -> some View {
        let tabs = labels.enumerated().map { index, label in
            RaincoatTab(label, value: index, icon: index < icons.count ? icons[index] : nil)
        }
        return TabStrip(tabs: tabs, selected: selected) { _ in }
    }

    @MainActor
    @Test(arguments: allThemes, ColorMode.allCases)
    func theSelectedTabIsMarkedAndEachLabelIsInItsColor(theme: RaincoatTheme, mode: ColorMode) throws {
        let tabs = tokens(mode, in: theme).tabs
        let selectedFirst = try Drawing(strip(["Details", "Reviews"], selected: 0), theme: theme, mode: mode)
        let selectedSecond = try Drawing(strip(["Details", "Reviews"], selected: 1), theme: theme, mode: mode)
        let bottom = selectedFirst.height - 1

        // The indicator runs under the selected tab only, and it is as thick as its token.
        let marked = selectedFirst.columns(with: tabs.indicator.color, inRow: bottom)
        let first = try #require(marked.first)
        let last = try #require(marked.last)
        #expect(first == 0)
        #expect(last < selectedFirst.width - 1)
        #expect(selectedFirst.isTransparent(selectedFirst.width - 2, bottom))
        let thickness = (0..<selectedFirst.height).filter { selectedFirst.has(tabs.indicator.color, at: 1, $0) }.count
        #expect(thickness == Int(tabs.indicator.width))

        // The selected label is in the selected color, the other in the color at rest.
        #expect(!selectedFirst.columns(with: tabs.fg.selected).filter { $0 <= last }.isEmpty)
        #expect(!selectedFirst.columns(with: tabs.fg.default).filter { $0 > last }.isEmpty)

        // Selecting the other tab moves the indicator and does not change any width.
        #expect(selectedSecond.width == selectedFirst.width)
        #expect(selectedSecond.isTransparent(1, bottom))
        #expect(selectedSecond.has(tabs.indicator.color, at: selectedSecond.width - 2, bottom))
    }

    @MainActor
    @Test(arguments: allThemes, Density.allCases)
    func aTabIsAsTallAsItsTokenAndTakesNoMoreRoomThanItShows(theme: RaincoatTheme, density: Density) throws {
        let tabs = tokens(.light, density, in: theme).tabs
        let drawing = try Drawing(strip(["Details", "Reviews"]), theme: theme, density: density)
        #expect(drawing.height == Int(tabs.height))
        // The indicator is at the bottom edge of the layout size.
        #expect(drawing.has(tabs.indicator.color, at: 1, drawing.height - 1))
    }

    @MainActor
    @Test(arguments: allThemes)
    func aLongLabelStaysOnOneLineAndIsNeverCutShort(theme: RaincoatTheme) throws {
        let tabs = tokens(.light, in: theme).tabs
        let labels = ["Questions and answers from other buyers", "Shipping and returns"]
        let natural = try Drawing(strip(labels), theme: theme)
        let offeredLess = try Drawing(strip(labels), theme: theme, width: 200)
        // One line: the tab keeps its height. Its whole width is drawn, more than was offered;
        // the scroll view around the row lets a person reach it.
        #expect(offeredLess.height == Int(tabs.height))
        #expect(offeredLess.width == natural.width)
        #expect(natural.width > 200)
    }

    @MainActor
    @Test(arguments: [LayoutDirection.leftToRight, .rightToLeft])
    func theFirstTabAndTheIconAreOnTheSideWhereReadingStarts(direction: LayoutDirection) throws {
        let tabs = tokens(.light).tabs
        let drawing = try Drawing(
            strip(["Photos", "Videos"], selected: 0, icons: [marker(magenta), marker(cyan)]),
            direction: direction
        )
        let bottom = drawing.height - 1
        let marked = drawing.columns(with: tabs.indicator.color, inRow: bottom)
        let first = try #require(drawing.columns(with: magenta).first)
        let second = try #require(drawing.columns(with: cyan).first)
        if direction == .leftToRight {
            #expect(marked.first == 0)
            #expect(first < second)
        } else {
            #expect(marked.last == drawing.width - 1)
            #expect(first > second)
        }
    }

    @MainActor
    @Test func anIconIsDrawnAtItsTokenSize() throws {
        let tabs = tokens(.light).tabs
        let drawing = try Drawing(strip(["Photos"], icons: [marker(magenta)]))
        #expect(drawing.columns(with: magenta).count == Int(tabs.iconSize))
    }

    /// XCUITest shows a tab's selected state but not that the row is a tab bar, so the traits
    /// the tabs give VoiceOver are checked here.
    @Test func theRowIsATabBarAndOnlyTheSelectedTabIsSelected() {
        #expect(TabsAccessibility.row == .isTabBar)
        #expect(TabsAccessibility.tab(isSelected: true) == .isSelected)
        #expect(TabsAccessibility.tab(isSelected: false).isEmpty)
    }

    @MainActor
    @Test func aTabWithOnlyAnIconIsNamedForAssistiveTechnology() throws {
        let tab = RaincoatTab(icon: marker(magenta), accessibilityLabel: Text("List"), value: 0)
        #expect(tab.accessibilityLabel == Text("List"))
        #expect(tab.title == nil)
        let drawing = try Drawing(TabStrip(tabs: [tab], selected: 0) { _ in })
        #expect(drawing.columns(with: magenta).count == Int(tokens(.light).tabs.iconSize))
    }
#endif
