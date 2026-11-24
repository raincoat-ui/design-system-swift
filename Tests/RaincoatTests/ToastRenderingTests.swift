#if canImport(SwiftUI) && canImport(CoreGraphics)
    import Accessibility
    import CoreGraphics
    @testable import Raincoat
    import RaincoatThemeBase
    import RaincoatTokens
    import SwiftUI
    import Testing
    #if os(macOS)
        import AppKit
    #endif

    // These tests draw real toasts into a bitmap and read the pixels back, so they check what
    // SwiftUI actually lays out and paints: fills, outlines, heights, and wrapping. They also draw
    // the shadow helper that every raised component uses, and drive a toast host's state with a
    // clock of their own. The queue and the timer are tested on their own in ToastQueueTests.

    /// A drawn view: its size in points and its pixels, at one pixel per point.
    ///
    /// On macOS the view is drawn in a hosting view in a window, as an app shows it, not with
    /// ImageRenderer: ImageRenderer measures a view that uses `accessibilityFocused`, as the toast
    /// does, as if it had no content (docs/adr/0019-visual-snapshots.md).
    @MainActor
    private struct Drawing {
        let width: Int
        let height: Int
        private let pixels: [UInt8]

        /// - Parameters:
        ///   - mode: The color mode to draw in, given by a theme that answers every request with
        ///     that mode's tokens, as the Button's rendering tests do.
        ///   - width: The width offered to the view, or nil for its own ideal width.
        ///   - height: The height offered to the view, or nil for its own ideal height.
        init(
            _ view: some View,
            theme: RaincoatTheme = .base,
            mode: ColorMode = .light,
            density: Density = .comfortable,
            width: CGFloat? = nil,
            height: CGFloat? = nil
        ) throws {
            let fixed = RaincoatTheme(id: "\(theme.id)-\(mode.rawValue)") { _, density in
                theme.tokens(mode: mode, density: density)
            }
            let themed = view.raincoatTheme(fixed).raincoatDensity(density)
            let offered = ProposedViewSize(width: width, height: height)
            #if os(macOS)
                let image = try Self.hosted(themed, offered: offered)
            #else
                let renderer = ImageRenderer(content: themed)
                renderer.scale = 1
                renderer.proposedSize = offered
                let rendered = try #require(renderer.cgImage)
                let image = (cgImage: rendered, size: CGSize(width: rendered.width, height: rendered.height))
            #endif
            // One pixel per point, whatever the scale it was drawn at.
            self.width = Int(image.size.width)
            self.height = Int(image.size.height)
            let (columns, rows) = (self.width, self.height)
            var buffer = [UInt8](repeating: 0, count: columns * rows * 4)
            let drawn = buffer.withUnsafeMutableBytes { raw -> Bool in
                guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                    let context = CGContext(
                        data: raw.baseAddress, width: columns, height: rows, bitsPerComponent: 8,
                        bytesPerRow: columns * 4, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    )
                else { return false }
                context.interpolationQuality = .none
                context.draw(image.cgImage, in: CGRect(x: 0, y: 0, width: columns, height: rows))
                return true
            }
            try #require(drawn)
            pixels = buffer
        }

        #if os(macOS)
            /// Draws a view in a hosting view in a borderless window, through AppKit's display
            /// cache, at the size the view takes when it is offered `offered`.
            private static func hosted(_ view: some View, offered: ProposedViewSize) throws -> (
                cgImage: CGImage, size: CGSize
            ) {
                _ = NSApplication.shared
                let host = NSHostingView(rootView: Offering(offered: offered) { view })
                let fitting = host.fittingSize
                let size = CGSize(width: fitting.width.rounded(.up), height: fitting.height.rounded(.up))
                let window = NSWindow(
                    contentRect: CGRect(origin: .zero, size: size), styleMask: .borderless,
                    backing: .buffered, defer: false
                )
                window.isReleasedWhenClosed = false
                window.colorSpace = .sRGB
                window.contentView = host
                host.frame = CGRect(origin: .zero, size: size)
                host.layoutSubtreeIfNeeded()
                host.display()
                defer { window.close() }
                let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let image = try #require(bitmap.cgImage)
                return (cgImage: image, size: size)
            }
        #endif

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

        /// The columns where this color appears anywhere.
        func columns(with color: TokenColor) -> [Int] {
            (0..<width).filter { x in (0..<height).contains { y in has(color, at: x, y) } }
        }
    }

    /// Offers its one view a given size, nil for the view's ideal, whatever it is offered itself,
    /// and is the size the view takes: as ImageRenderer's `proposedSize` does.
    private struct Offering: Layout {
        let offered: ProposedViewSize

        func sizeThatFits(proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
            subviews.first?.sizeThatFits(offered) ?? .zero
        }

        func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
            subviews.first?.place(at: bounds.origin, anchor: .topLeading, proposal: offered)
        }
    }

    private func tokens(
        _ mode: ColorMode = .light, _ density: Density = .comfortable, in theme: RaincoatTheme = .base
    ) -> RaincoatTokenSet {
        theme.tokens(mode: mode, density: density)
    }

    /// The toast, its shadow helper, and its host, drawn and driven on macOS.
    @Suite struct ToastRenderingTests {
        /// An action for the toasts to show. It does nothing.
        private var undo: RaincoatToast.Action { RaincoatToast.Action("Undo") {} }
        private let longMessage = "Messages older than one year were moved from Archive to the Deleted folder"

        // MARK: - The toast

        @MainActor
        @Test(arguments: allThemes, ColorMode.allCases)
        func aToastIsPaintedWithItsTokens(theme: RaincoatTheme, mode: ColorMode) throws {
            let toast = tokens(mode, in: theme).toast
            let drawing = try Drawing(
                RaincoatToast("Message archived", action: undo, closeLabel: "Close"), theme: theme, mode: mode
            )
            let middle = drawing.height / 2
            // The outline at the edge, the fill just inside it, and the message in its color.
            #expect(drawing.has(toast.border.color, at: 0, middle))
            #expect(drawing.has(toast.bg, at: Int(toast.border.width) + 1, middle))
            #expect(!drawing.columns(with: toast.fg).isEmpty)
        }

        @MainActor
        @Test(arguments: allThemes, Density.allCases)
        func aOneLineToastIsAsTallAsASmallButtonAndItsPadding(theme: RaincoatTheme, density: Density) throws {
            let set = tokens(.light, density, in: theme)
            let toast = set.toast
            let expected = Int(set.button.height.sm + 2 * (toast.paddingBlock + toast.border.width))
            for view in [
                RaincoatToast("Message archived"),
                RaincoatToast("Link copied", closeLabel: "Close"),
                RaincoatToast("Message archived", action: undo, closeLabel: "Close"),
            ] {
                let drawing = try Drawing(view, theme: theme, density: density)
                #expect(drawing.height == expected)
            }
        }

        @MainActor
        @Test func offeredAScreenfulAToastIsAsTallAsItsContent() throws {
            let set = tokens()
            let expected = Int(set.button.height.sm + 2 * (set.toast.paddingBlock + set.toast.border.width))
            let drawing = try Drawing(RaincoatToast("Message archived"), width: 400, height: 800)
            #expect(drawing.height == expected)
        }

        @MainActor
        @Test func offeredMoreRoomThanItNeedsAToastStaysAsWideAsItsContentCentered() throws {
            let toast = tokens().toast
            let drawing = try Drawing(RaincoatToast("Saved"), width: 400)
            let middle = drawing.height / 2
            #expect(drawing.isTransparent(1, middle))
            #expect(drawing.isTransparent(drawing.width - 2, middle))
            #expect(drawing.has(toast.border.color, at: drawing.width / 2, 0))
        }

        @MainActor
        @Test(arguments: allThemes)
        func aLongMessageWrapsAndTheActionMovesBelowIt(theme: RaincoatTheme) throws {
            let set = tokens(in: theme)
            let toast = set.toast
            let oneLine = try Drawing(
                RaincoatToast("Message archived", action: undo, closeLabel: "Close"), theme: theme, width: 360
            )
            let wrapped = try Drawing(
                RaincoatToast(longMessage, action: undo, closeLabel: "Close"), theme: theme, width: 360
            )
            let line = toast.message.lineHeight * toast.message.size
            #expect(wrapped.width == 360)
            // At least two lines of the message, and a row below them for the action.
            #expect(Double(wrapped.height) >= Double(oneLine.height) + line + set.button.height.sm - 1)
            // The fill reaches the bottom: nothing hangs out of the toast.
            let edge = Int(toast.border.width)
            #expect(wrapped.has(toast.bg, at: edge + 1, wrapped.height - edge - 2))
        }

        @MainActor
        @Test func aToastIsNeverWiderThanThePanelWidth() throws {
            let toast = tokens().toast
            let drawing = try Drawing(RaincoatToast(longMessage + " " + longMessage), width: 2000)
            #expect(drawing.width == Int(toast.maxWidth))
        }

        @MainActor
        @Test func theCloseButtonIsASquareSmallButtonWithACross() throws {
            let set = tokens()
            let withClose = try Drawing(RaincoatToast("Link copied", closeLabel: "Close"))
            let without = try Drawing(RaincoatToast("Link copied"))
            let toast = set.toast
            // The close button and one gap.
            #expect(withClose.width == without.width + Int(set.button.height.sm + toast.gap))
            // Something is drawn on the fill where the close button is: its cross.
            let edge = Int(toast.border.width)
            let drawn = (without.width..<withClose.width - edge - 1).contains { x in
                (edge + 1..<withClose.height - edge - 1).contains { y in !withClose.has(toast.bg, at: x, y) }
            }
            #expect(drawn)
        }

        /// The first and last columns with ink on the fill: anything drawn inside the outline that is
        /// not the fill, such as text or the cross.
        @MainActor
        private func inkedColumns(_ drawing: Drawing, fill: TokenColor, edge: Int) -> ClosedRange<Int>? {
            let columns = (edge + 1..<drawing.width - edge - 1).filter { x in
                (edge + 1..<drawing.height - edge - 1).contains { y in !drawing.has(fill, at: x, y) }
            }
            guard let first = columns.first, let last = columns.last else { return nil }
            return first...last
        }

        @MainActor
        @Test func inRightToLeftTheActionAndTheCloseButtonAreOnTheLeft() throws {
            let toast = tokens().toast
            let edge = Int(toast.border.width)
            let view = RaincoatToast("Message archived", action: undo, closeLabel: "Close")
            let ltr = try Drawing(view)
            let rtl = try Drawing(view.environment(\.layoutDirection, .rightToLeft))
            let left = try #require(inkedColumns(ltr, fill: toast.bg, edge: edge))
            let right = try #require(inkedColumns(rtl, fill: toast.bg, edge: edge))
            let inset = Int(toast.paddingInline) + edge
            // Left to right, the message starts right after the padding and the cross ends well
            // before it on the other side. Right to left, the other way round.
            #expect(left.lowerBound <= inset + 3)
            #expect(left.upperBound < ltr.width - inset - 6)
            #expect(right.lowerBound > inset + 6)
            #expect(right.upperBound >= rtl.width - inset - 4)
        }

        // MARK: - The shadow helper

        private let ink = TokenColor(hex: 0x000000)
        private let paper = TokenColor(hex: 0xFFFFFF)

        /// A 40-point square filled with paper, with a shadow, on 20 points of clear space.
        @MainActor
        private func square(_ shadow: TokenShadow) throws -> Drawing {
            try Drawing(
                Color.clear
                    .frame(width: 40, height: 40)
                    .raincoatShadow(shadow, in: Rectangle(), fill: Color(paper))
                    .padding(20)
            )
        }

        private func layer(offsetY: Double, inset: Bool = false, alpha: Double = 1) -> TokenShadowLayer {
            TokenShadowLayer(
                color: TokenColor(hex: 0x000000, alpha: alpha), offsetX: 0, offsetY: offsetY, blur: 0, spread: 0,
                inset: inset
            )
        }

        @MainActor
        @Test func anOuterShadowIsDrawnBehindTheShapeMovedByItsOffset() throws {
            let drawing = try square(TokenShadow(layers: [layer(offsetY: 10)]))
            // Below the square, inside the offset, and not above it.
            #expect(drawing.has(ink, at: 40, 65))
            #expect(drawing.isTransparent(40, 15))
            // The square stays on top.
            #expect(drawing.has(paper, at: 40, 40))
        }

        @MainActor
        @Test func anInsetShadowIsDrawnInsideTheShape() throws {
            let drawing = try square(TokenShadow(layers: [layer(offsetY: 10, inset: true)]))
            // Along the top edge, inside, where the offset uncovers it; the rest is paper.
            #expect(drawing.has(ink, at: 40, 23))
            #expect(drawing.has(paper, at: 40, 45))
            #expect(drawing.isTransparent(40, 65))
        }

        @MainActor
        @Test func aShadowOfTransparentLayersDrawsNothing() throws {
            let none = tokens().shadow.overlay
            let transparent = TokenShadow(layers: [layer(offsetY: 10, alpha: 0)])
            #expect(transparent.visibleLayers.isEmpty)
            for shadow in [none, transparent] {
                let drawing = try square(shadow)
                #expect(drawing.isTransparent(40, 65))
                #expect(drawing.isTransparent(40, 15))
            }
        }

        // MARK: - The host

        /// A clock the test moves by hand, and what the host asked VoiceOver to say.
        @MainActor
        private final class Recorder {
            var now: Double = 0
            var announced: [String] = []
        }

        @MainActor
        @Test func theHostAnnouncesEachToastWhenItIsShownInOrder() async throws {
            let clock = Recorder()
            let model = ToastHostModel(now: { clock.now }, announce: { clock.announced.append($0) })
            model.show(RaincoatToast("First", action: undo, closeLabel: "Close"))
            model.show(RaincoatToast("Second"))
            #expect(clock.announced == ["First"])
            #expect(model.queue.shown?.message == "First")

            // With no time to leave the screen, the second follows at once.
            model.close(try #require(model.queue.shown?.id))
            #expect(clock.announced == ["First", "Second"])
            #expect(model.queue.shown?.message == "Second")
            #expect(model.queue.deadline == clock.now + toastDuration)
        }

        @MainActor
        @Test func theNextToastWaitsUntilTheLastHasLeftTheScreen() async throws {
            let clock = Recorder()
            let model = ToastHostModel(now: { clock.now }, announce: { clock.announced.append($0) })
            model.exitDuration = 0.05
            model.show(RaincoatToast("First", closeLabel: "Close"))
            model.show(RaincoatToast("Second", closeLabel: "Close"))
            model.close(try #require(model.queue.shown?.id))
            #expect(model.queue.shown?.id == nil)
            #expect(model.queue.isLeaving)
            // Waits on the system's clock for the first toast to leave, a few frames at most.
            for _ in 0..<200 where model.queue.shown == nil {
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(model.queue.shown?.message == "Second")
            #expect(clock.announced == ["First", "Second"])
        }

        @MainActor
        @Test func theHostStopsTheTimerWhileTheAppIsInTheBackground() {
            let clock = Recorder()
            let model = ToastHostModel(now: { clock.now }, announce: { _ in })
            model.show(RaincoatToast("Message archived"))
            clock.now = 2
            model.setPaused(.background, true)
            #expect(model.queue.deadline == nil)
            clock.now = 100
            model.setPaused(.background, false)
            #expect(model.queue.deadline == 104)
        }

        @Test func theAnnouncementWaitsForWhatVoiceOverIsSaying() {
            let announcement = toastAnnouncement("Link copied")
            #expect(String(announcement.characters) == "Link copied")
            #expect(announcement.accessibilitySpeechAnnouncementPriority == .low)
        }
    }
#endif
