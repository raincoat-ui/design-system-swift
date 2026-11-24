import RaincoatTokens

// What a Dialog and a Sheet look like, and how their parts are laid out, taken from the dialog
// tokens. This file uses no SwiftUI, so its tests also run on Linux.

/// The colors, spaces, and text styles of a dialog or a sheet.
struct DialogAppearance: Hashable, Sendable {
    /// The fill of the sheet the dialog is presented in.
    let background: TokenColor
    /// The color of the title and the description.
    let foreground: TokenColor
    /// The hairline under the header and over the footer while content is beneath them.
    let divider: TokenColor
    let dividerWidth: Double
    /// The space between the edge of the sheet and its content.
    let padding: Double
    /// The space between the header, the body, and the footer.
    let gap: Double
    /// The space between the footer's buttons.
    let footerGap: Double
    /// The space between the title and the description.
    let titleGap: Double
    let title: TokenTextStyle
    let description: TokenTextStyle

    init(_ tokens: RaincoatTokenSet) {
        let dialog = tokens.dialog
        background = dialog.bg
        foreground = dialog.fg
        divider = dialog.divider
        dividerWidth = dialog.border.width
        padding = dialog.padding
        gap = dialog.gap
        footerGap = dialog.footer.gap
        titleGap = tokens.space._2
        title = dialog.title
        description = dialog.description
    }

    /// The space each of two neighbouring sections keeps on its side of the line between them:
    /// half the gap, so that a hairline between them sits halfway.
    var halfGap: Double { gap / 2 }
}

/// How a dialog's sections are arranged to scroll.
enum DialogScrolling: Hashable, Sendable {
    /// The header and the footer stay in place, and the body scrolls between them.
    case body
    /// The whole dialog is one scrolling area, header and footer included. While everything
    /// fits, it does not move.
    case whole

    /// - Parameters:
    ///   - available: The height the dialog has.
    ///   - header: The height of the header, its space included.
    ///   - body: The height of the body's content, its space included, or 0 without a body.
    ///   - footer: The height of the footer, its space included, or 0 without a footer.
    ///   - bodyLine: The height of one line of the body's text.
    ///   - bodySpace: The body's own space above and below its content.
    ///
    /// The body scrolls between the header and the footer only when it has more than fits, and
    /// room for three lines of text. Otherwise the dialog is one scrolling area: when everything
    /// fits, so that text that grows, as with a larger text size, is never cut off before the
    /// sheet grows with it; and in a window too short for three lines of the body, as at the
    /// largest text sizes, so that every part of the dialog can be reached.
    init(available: Double, header: Double, body: Double, footer: Double, bodyLine: Double, bodySpace: Double) {
        if header + body + footer <= available + 0.5 {
            self = .whole
        } else if body > 0, available - header - footer >= 3 * bodyLine + bodySpace - 0.5 {
            self = .body
        } else {
            self = .whole
        }
    }
}

/// How much of a dialog the software keyboard covers: from the keyboard's top down to the
/// dialog's bottom, while the keyboard is docked at the bottom of the screen over it. A sheet
/// that cannot rise above the keyboard has its bottom covered; the dialog keeps to what shows,
/// so that its scrolling area ends above the keyboard. A keyboard elsewhere, as one floating
/// on an iPad, or none, covers nothing.
struct KeyboardCover: Hashable, Sendable {
    let height: Double

    /// - Parameters:
    ///   - dialogTop: The top of the dialog on the screen.
    ///   - dialogBottom: The bottom of the dialog on the screen.
    ///   - keyboardTop: The top of the keyboard on the screen, or nil while it is hidden.
    ///   - keyboardBottom: The bottom of the keyboard on the screen, or nil while it is hidden.
    init(dialogTop: Double, dialogBottom: Double, keyboardTop: Double?, keyboardBottom: Double?) {
        guard let keyboardTop, let keyboardBottom, keyboardTop < dialogBottom,
            keyboardBottom >= dialogBottom - 0.5
        else {
            height = 0
            return
        }
        height = dialogBottom - max(keyboardTop, dialogTop)
    }
}

/// Whether the hairlines under the header and over the footer show: while the body has content
/// scrolled beneath them.
struct DialogDividers: Hashable, Sendable {
    let underHeader: Bool
    let overFooter: Bool

    /// - Parameters:
    ///   - offset: How far the body is scrolled from its top.
    ///   - viewport: The height of the body's visible area.
    ///   - content: The height of the body's content.
    init(offset: Double, viewport: Double, content: Double) {
        let scrolls = content > viewport + 0.5
        underHeader = scrolls && offset > 0.5
        overFooter = scrolls && offset + viewport < content - 0.5
    }

    static let none = DialogDividers(offset: 0, viewport: 0, content: 0)
}

/// Where the footer's buttons go. In a row at the end edge, the primary action last, while they
/// fit; otherwise stacked, the primary action first, each as wide as the footer. Frames are in
/// the order of the buttons, from the footer's top left; a right-to-left layout mirrors them.
struct FooterArrangement: Equatable, Sendable {
    struct Frame: Equatable, Sendable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }

    let frames: [Frame]
    let width: Double
    let height: Double
    let isStacked: Bool

    /// - Parameters:
    ///   - sizes: Each button's own width and height, on one line.
    ///   - available: The width of the footer, or nil when it can be as wide as the buttons.
    ///   - spacing: The space between two buttons.
    ///   - heightAtWidth: The height of a button, by its index, at a given width.
    init(
        sizes: [(width: Double, height: Double)],
        available: Double?,
        spacing: Double,
        heightAtWidth: (Int, Double) -> Double
    ) {
        let gaps = spacing * Double(max(0, sizes.count - 1))
        let row = sizes.reduce(0) { $0 + $1.width } + gaps
        if sizes.count < 2 || available.map({ row <= $0 + 0.5 }) ?? true {
            let width = max(row, available ?? row)
            let height = sizes.map(\.height).max() ?? 0
            var x = width - row
            var frames: [Frame] = []
            for size in sizes {
                frames.append(Frame(x: x, y: (height - size.height) / 2, width: size.width, height: size.height))
                x += size.width + spacing
            }
            self.init(frames: frames, width: width, height: height, isStacked: false)
            return
        }
        let width = available ?? row
        let heights = sizes.indices.map { heightAtWidth($0, width) }
        // The primary action, the last button, goes on top.
        var frames = [Frame](repeating: Frame(x: 0, y: 0, width: 0, height: 0), count: sizes.count)
        var y = 0.0
        for index in sizes.indices.reversed() {
            frames[index] = Frame(x: 0, y: y, width: width, height: heights[index])
            y += heights[index] + spacing
        }
        self.init(frames: frames, width: width, height: max(0, y - spacing), isStacked: true)
    }

    private init(frames: [Frame], width: Double, height: Double, isStacked: Bool) {
        self.frames = frames
        self.width = width
        self.height = height
        self.isStacked = isStacked
    }
}
