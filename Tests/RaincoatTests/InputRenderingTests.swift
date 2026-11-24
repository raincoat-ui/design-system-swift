#if canImport(SwiftUI) && canImport(CoreGraphics)
    import CoreGraphics
    @testable import Raincoat
    import RaincoatThemeBase
    import RaincoatTokens
    import SwiftUI
    import Testing

    // These tests draw real inputs into a bitmap and read the pixels back, so they check what
    // SwiftUI actually lays out and paints: heights, fills, outlines, and the order of the parts.
    //
    // A text field is a platform control, which an image renderer does not draw. The tests read
    // the field's box only where SwiftUI paints it: the outline, and the padding beside the text.
    // Whatever a theme can change is drawn in every theme (allThemes, in Generated/Themes.swift).

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
            density: Density = .comfortable,
            direction: LayoutDirection = .leftToRight,
            width: CGFloat = 300
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

        /// Whether the pixel is this opaque color, give or take one step of rounding.
        func has(_ color: TokenColor, at x: Int, _ y: Int) -> Bool {
            let wanted = [color.red, color.green, color.blue, 1].map { Int(($0 * 255).rounded()) }
            return zip(pixel(x, y), wanted).allSatisfy { abs($0 - $1) <= 1 }
        }

        /// The rows of a column where this color appears.
        func rows(with color: TokenColor, inColumn x: Int) -> [Int] {
            (0..<height).filter { has(color, at: x, $0) }
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
    private let longText = "Write the address where the invoice should go, including the floor and the building"

    /// A field with its label hidden: the drawing is the field's box alone.
    @MainActor
    private func field(
        size: InputSize = .md, isInvalid: Bool = false, isReadOnly: Bool = false, type: InputType = .text,
        leadingIcon: Image? = nil
    ) -> RaincoatInput {
        RaincoatInput(
            "Email", text: .constant("ana"), type: type, size: size, isInvalid: isInvalid,
            error: Text("Enter an email address"), isReadOnly: isReadOnly, isLabelHidden: true,
            leadingIcon: leadingIcon
        )
    }

    private func height(_ input: RaincoatTokenSet.InputTokens, _ size: InputSize) -> Double {
        switch size {
        case .sm: input.height.sm
        case .md: input.height.md
        case .lg: input.height.lg
        }
    }

    @MainActor
    @Test(arguments: allThemes, ColorMode.allCases)
    func eachStateOfAFieldIsPaintedWithItsTokens(theme: RaincoatTheme, mode: ColorMode) throws {
        let input = tokens(mode, in: theme).input
        let cases: [(String, AnyView, TokenColor, TokenColor)] = [
            ("rest", AnyView(field()), input.bg.default, input.border.default),
            ("invalid", AnyView(field(isInvalid: true)), input.bg.default, input.border.invalid),
            ("read-only", AnyView(field(isReadOnly: true)), input.bg.readOnly, input.border.readOnly),
            ("disabled", AnyView(field(isInvalid: true).disabled(true)), input.bg.disabled, input.border.disabled),
        ]
        for (state, view, fill, border) in cases {
            let drawing = try Drawing(view, theme: theme, mode: mode)
            let middle = drawing.height / 2
            // Just inside the outline, in the padding beside the text; and on the outline.
            #expect(drawing.has(fill, at: 3, middle), "\(state)")
            #expect(drawing.has(border, at: 0, middle), "\(state)")
            #expect(drawing.has(border, at: drawing.width - 1, middle), "\(state)")
        }
    }

    @MainActor
    @Test(arguments: allThemes, Density.allCases)
    func aFieldIsAsTallAsItsTokenAndTakesNoMoreRoomThanItShows(theme: RaincoatTheme, density: Density) throws {
        let input = tokens(.light, density, in: theme).input
        for size in InputSize.allCases {
            let expected = Int(height(input, size))
            let drawing = try Drawing(field(size: size), theme: theme, density: density)
            #expect(drawing.height == expected, "\(size)")
            // The outline is the first and the last row: nothing is drawn past it, even where
            // the field is shorter than the touch target.
            #expect(drawing.has(input.border.default, at: drawing.width / 2, 0), "\(size)")
            #expect(drawing.has(input.border.default, at: drawing.width / 2, expected - 1), "\(size)")

            let styled = try Drawing(
                TextField("Search", text: .constant("")).textFieldStyle(.raincoat(size: size)),
                theme: theme, density: density
            )
            #expect(styled.height == expected, "the style, \(size)")
            #expect(styled.has(input.bg.default, at: 3, expected / 2), "the style, \(size)")
        }
    }

    @MainActor
    @Test(arguments: allThemes)
    func theLabelIsAboveTheFieldAndTheErrorBelowItOnlyWhileInvalid(theme: RaincoatTheme) throws {
        let set = tokens(.light, in: theme)
        let input = set.input
        @MainActor func drawn(isInvalid: Bool, description: Text? = nil) throws -> Drawing {
            try Drawing(
                RaincoatInput(
                    "Email", text: .constant(""), description: description, isInvalid: isInvalid,
                    error: Text("Enter an email address")
                ),
                theme: theme
            )
        }
        let line = { (style: TokenTextStyle) in style.lineHeight * style.size }
        let label = line(input.label.md)
        let box = input.height.md

        // The label, the gap, then the field.
        let valid = try drawn(isInvalid: false)
        #expect(abs(Double(valid.height) - (label + input.gap + box)) <= 1)
        #expect(!valid.columns(with: input.label.fg).isEmpty)
        // The field's outline starts below the label and the gap.
        let outline = valid.rows(with: input.border.default, inColumn: valid.width / 2)
        #expect(abs(Double(outline.first ?? 0) - (label + input.gap)) <= 1)

        // An error is shown only while the field is invalid, below the field, after the gap.
        let invalid = try drawn(isInvalid: true)
        let error = line(input.error.type)
        #expect(abs(Double(invalid.height - valid.height) - (input.gap + error)) <= 1)
        #expect(!invalid.columns(with: input.error.fg).isEmpty)
        #expect(valid.columns(with: input.error.fg).isEmpty)

        // The description is between the label and the field, and stays with the error.
        let described = try drawn(isInvalid: true, description: Text("We send the receipt here."))
        let description = line(input.description.type)
        #expect(abs(Double(described.height - invalid.height) - (input.gap + description)) <= 1)
        #expect(!described.columns(with: input.description.fg).isEmpty)
    }

    @MainActor
    @Test func aHiddenLabelTakesNoRoom() throws {
        let input = tokens(.light).input
        let drawing = try Drawing(field())
        #expect(drawing.height == Int(input.height.md))
    }

    @MainActor
    @Test(arguments: allThemes)
    func aLongLabelDescriptionAndErrorWrap(theme: RaincoatTheme) throws {
        let input = tokens(.light, in: theme).input
        let short = try Drawing(
            RaincoatInput(
                "Address", text: .constant(""), description: Text("Where to send it."), isInvalid: true,
                error: Text("Enter an address")
            ),
            theme: theme, width: 220
        )
        let long = try Drawing(
            RaincoatInput(
                longText, text: .constant(""), description: Text(longText), isInvalid: true,
                error: Text(longText)
            ),
            theme: theme, width: 220
        )
        #expect(long.width == 220)
        // Each of the three takes several lines.
        let line = input.description.type.lineHeight * input.description.type.size
        #expect(Double(long.height - short.height) > 4 * line)
    }

    @MainActor
    @Test(arguments: [LayoutDirection.leftToRight, .rightToLeft])
    func aFieldsLeadingIconIsOnTheSideWhereReadingStarts(direction: LayoutDirection) throws {
        let drawing = try Drawing(field(leadingIcon: marker(magenta)), direction: direction)
        let icon = try #require(drawing.columns(with: magenta).first)
        if direction == .leftToRight {
            #expect(icon < drawing.width / 2)
        } else {
            #expect(icon > drawing.width / 2)
        }
    }

    @MainActor
    @Test(arguments: [InputType.email, .tel, .url])
    func anAddressOrNumberFieldStaysLeftToRightWithItsIcon(type: InputType) throws {
        let drawing = try Drawing(field(type: type, leadingIcon: marker(magenta)), direction: .rightToLeft)
        let icon = try #require(drawing.columns(with: magenta).first)
        #expect(icon < drawing.width / 2)
    }

    @MainActor
    @Test(arguments: InputSize.allCases)
    func theIconIsDrawnAtItsTokenSize(size: InputSize) throws {
        let input = tokens(.light).input
        let drawing = try Drawing(field(size: size, leadingIcon: marker(magenta)))
        let expected: Double =
            switch size {
            case .sm: input.iconSize.sm
            case .md: input.iconSize.md
            case .lg: input.iconSize.lg
            }
        let columns = drawing.columns(with: magenta)
        #expect(columns.count == Int(expected))
        // It starts after the outline and the padding.
        let padding: Double =
            switch size {
            case .sm: input.paddingInline.sm
            case .md: input.paddingInline.md
            case .lg: input.paddingInline.lg
            }
        #expect(abs((columns.first ?? 0) - Int(padding)) <= 1)
    }

    @Test func theFieldAreaIsTheWholeFieldAndAtLeastTheMinimumTarget() {
        // A text field 300 wide and 22 tall, in a one-line field 36 tall with 12 on each side:
        // the area is the field, then grown to the minimum target, centered on it.
        let small = FieldArea(leading: 12, trailing: 12, height: 36, paddingBlock: 7, minimum: 44, isRightToLeft: false)
        #expect(
            small.path(in: CGRect(x: 0, y: 0, width: 300, height: 22)).boundingRect
                == CGRect(x: -12, y: -11, width: 324, height: 44)
        )
        // A field as tall as the target: the area is the field.
        let medium = FieldArea(leading: 12, trailing: 12, height: 44, paddingBlock: 10, minimum: 44, isRightToLeft: false)
        #expect(
            medium.path(in: CGRect(x: 0, y: 0, width: 300, height: 22)).boundingRect
                == CGRect(x: -12, y: -11, width: 324, height: 44)
        )
        // The icon's side is where reading starts: on the right in a right-to-left layout.
        let withIcon = FieldArea(leading: 40, trailing: 12, height: 44, paddingBlock: 10, minimum: 44, isRightToLeft: true)
        #expect(
            withIcon.path(in: CGRect(x: 0, y: 0, width: 300, height: 22)).boundingRect
                == CGRect(x: -12, y: -11, width: 352, height: 44)
        )
        // A multi-line field: its lines and the space above and below them.
        let lines = FieldArea(leading: 12, trailing: 12, height: nil, paddingBlock: 10, minimum: 44, isRightToLeft: false)
        #expect(
            lines.path(in: CGRect(x: 0, y: 0, width: 300, height: 72)).boundingRect
                == CGRect(x: -12, y: -10, width: 324, height: 92)
        )
    }

    @MainActor
    @Test func aReadOnlyFieldShowsItsValueInTheValueColor() throws {
        let input = tokens(.light).input
        let drawing = try Drawing(field(isReadOnly: true))
        #expect(!drawing.columns(with: input.fg.default).isEmpty)
    }
#endif
