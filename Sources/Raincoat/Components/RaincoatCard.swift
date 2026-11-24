#if canImport(SwiftUI)
    import RaincoatTokens
    import SwiftUI

    /// A surface that groups content about one subject, such as an order or a person. It follows
    /// the Raincoat Card spec.
    ///
    ///     RaincoatCard("Storage", level: 3) {
    ///         Text("4.2 GB of 15 GB used").raincoatText(color: .muted)
    ///     }
    ///     .footer { RaincoatButton("Manage storage") { manage() } }
    ///
    /// A card is static: a container that can hold links and buttons. To make the whole card lead
    /// somewhere or do one thing, make it the label of a `NavigationLink`, a `Link`, or a `Button`
    /// with the card style. It is then one element, read by VoiceOver title first, and it holds
    /// no other controls.
    ///
    ///     NavigationLink(value: order) {
    ///         RaincoatCard("Order 1042", level: 3) {
    ///             Text("Delivered on Monday").raincoatText(color: .muted)
    ///         }
    ///         .media { Image("parcel").resizable().scaledToFill().frame(height: 120) }
    ///     }
    ///     .buttonStyle(.raincoatCard)
    ///
    /// The title is a heading at `level`, in the `headingSm` look. The card fills the width it is
    /// offered and grows with its content. Its outline, fill, and shadow come from the theme in
    /// the environment; see `View.raincoatTheme(_:)`.
    public struct RaincoatCard<Content: View, Media: View, Footer: View>: View {
        private let title: Text
        private let level: Int
        private let contentView: Content?
        private let mediaView: Media?
        private let footerView: Footer?

        @Tokens private var tokens
        @Environment(\.raincoatCardState) private var state
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private init(title: Text, level: Int, content: Content?, media: Media?, footer: Footer?) {
            self.title = title
            self.level = level
            contentView = content
            mediaView = media
            footerView = footer
        }

        public var body: some View {
            let card = tokens.card
            let colors = CardColors(card, state: state ?? .rest)
            let shape = RoundedRectangle(cornerRadius: card.radius, style: .continuous)
            let easing = card.transition.easing

            // The padding is inside the outline, as on the web.
            let surface = CardStack(padding: card.border.width + card.padding, gap: card.gap) {
                // The title comes first, so that VoiceOver reads it first; the media is drawn
                // above it.
                title
                    .raincoatHeading(level: level, variant: .headingSm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilitySortPriority(1)
                if let mediaView {
                    VStack(spacing: 0) { mediaView }
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .layoutValue(key: IsCardMedia.self, value: true)
                }
                if let contentView {
                    contentView
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let footerView {
                    CardFooterLayout(spacing: card.gap) { footerView }
                }
            }
            .foregroundStyle(Color(tokens.color.fg.default))
            // The media's top corners follow the card's.
            .clipShape(shape)
            .raincoatShadow(card.shadow, in: shape, fill: Color(colors.fill))
            .overlay { shape.strokeBorder(Color(colors.border), lineWidth: card.border.width) }
            // Outline and fill changes ease in. With reduced motion they are immediate.
            .animation(
                reduceMotion
                    ? nil
                    : .timingCurve(easing.x1, easing.y1, easing.x2, easing.y2, duration: card.transition.duration),
                value: state
            )

            // In the card style the card is the label of one button or link, which reads its
            // content as one element. A static card keeps its parts apart, title first.
            if state == nil {
                surface.accessibilityElement(children: .contain)
            } else {
                surface.accessibilityElement(children: .combine)
            }
        }
    }

    extension RaincoatCard where Media == Never, Footer == Never {
        /// Creates a card with a title and a body.
        ///
        /// - Parameters:
        ///   - title: What the card is about. It is a heading, and it wraps and is never cut short.
        ///   - level: The title's place in the outline of the screen, from 1 to 6.
        ///   - content: The body: any content, such as text, a list of facts, or a status.
        /// - Precondition: `level` is from 1 to 6.
        public init(_ title: Text, level: Int, @ViewBuilder content: () -> Content) {
            self.init(title: title, level: level, content: content(), media: nil, footer: nil)
        }

        /// Creates a card whose title is a localized string key.
        public init(_ titleKey: LocalizedStringKey, level: Int, @ViewBuilder content: () -> Content) {
            self.init(Text(titleKey), level: level, content: content)
        }

        /// Creates a card whose title is a string that is shown as it is.
        @_disfavoredOverload
        public init(_ title: some StringProtocol, level: Int, @ViewBuilder content: () -> Content) {
            self.init(Text(title), level: level, content: content)
        }
    }

    extension RaincoatCard where Content == Never, Media == Never, Footer == Never {
        /// Creates a card with a title alone.
        ///
        /// - Precondition: `level` is from 1 to 6.
        public init(_ title: Text, level: Int) {
            self.init(title: title, level: level, content: nil, media: nil, footer: nil)
        }

        /// Creates a card whose title is a localized string key.
        public init(_ titleKey: LocalizedStringKey, level: Int) {
            self.init(Text(titleKey), level: level)
        }

        /// Creates a card whose title is a string that is shown as it is.
        @_disfavoredOverload
        public init(_ title: some StringProtocol, level: Int) {
            self.init(Text(title), level: level)
        }
    }

    extension RaincoatCard {
        /// Adds an image at the top of the card, edge to edge, with the card's top corners. It is
        /// offered the card's width; give it a height, or an aspect ratio, of its own.
        ///
        /// Give the image an accessibility label that says what it shows, or none when it only
        /// decorates. VoiceOver reads it after the title.
        public func media<NewMedia: View>(
            @ViewBuilder _ media: () -> NewMedia
        ) -> RaincoatCard<Content, NewMedia, Footer> {
            RaincoatCard<Content, NewMedia, Footer>(
                title: title, level: level, content: contentView, media: media(), footer: footerView
            )
        }

        /// Adds actions, as Buttons, at the end of a static card. They sit at the trailing edge,
        /// and wrap onto more rows when they do not fit.
        public func footer<NewFooter: View>(
            @ViewBuilder _ footer: () -> NewFooter
        ) -> RaincoatCard<Content, Media, NewFooter> {
            RaincoatCard<Content, Media, NewFooter>(
                title: title, level: level, content: contentView, media: mediaView, footer: footer()
            )
        }
    }

    /// The appearance of an interactive card, for a `Button`, a `NavigationLink`, or a `Link`
    /// whose label is a `RaincoatCard`.
    ///
    ///     Button { startReturn() } label: {
    ///         RaincoatCard("Start a return", level: 3) { Text("Within 30 days of delivery").raincoatText() }
    ///     }
    ///     .buttonStyle(.raincoatCard)
    ///
    /// The whole card takes touches. Its outline steps to the strong border color under a pointer,
    /// and its fill changes while it is pressed. With Full Keyboard Access, the system draws its
    /// focus indicator around it.
    public struct RaincoatCardStyle: ButtonStyle {
        public init() {}

        public func makeBody(configuration: Configuration) -> some View {
            CardButtonBody(label: configuration.label, isPressed: configuration.isPressed)
        }
    }

    extension ButtonStyle where Self == RaincoatCardStyle {
        /// The appearance of an interactive card.
        public static var raincoatCard: RaincoatCardStyle { RaincoatCardStyle() }
    }

    extension EnvironmentValues {
        /// The state of the card style around a card, which draws it: nil for a static card.
        @Entry var raincoatCardState: CardState? = nil
    }

    /// The label of an interactive card: the card, told its state, taking touches across its
    /// surface.
    private struct CardButtonBody<Label: View>: View {
        let label: Label
        let isPressed: Bool

        @Tokens private var tokens
        @State private var isHovered = false

        var body: some View {
            label
                .environment(\.raincoatCardState, CardState(isPressed: isPressed, isHovered: isHovered))
                .contentShape(RoundedRectangle(cornerRadius: tokens.card.radius, style: .continuous))
                // Only a pointer hovers.
                .onHover { isHovered = $0 }
        }
    }

    /// Marks the media among the parts of a card.
    private struct IsCardMedia: LayoutValueKey {
        static let defaultValue = false
    }

    /// The parts of a card: the media at the top, edge to edge, then the title, body, and footer,
    /// inside the padding, one under the other, the gap apart. The card fills the width it is
    /// offered. The media is placed first wherever it is among the parts, so that the title can
    /// come first for VoiceOver.
    private struct CardStack: Layout {
        let padding: CGFloat
        let gap: CGFloat

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
            arrangement(width: proposal.width, subviews: subviews).size
        }

        func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
            let frames = arrangement(width: bounds.width, subviews: subviews).frames
            for (subview, frame) in zip(subviews, frames) {
                subview.place(
                    at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(frame.size)
                )
            }
        }

        /// Where each part goes in a given width, or, with no width to fill, in the widest part's
        /// ideal width.
        private func arrangement(width: CGFloat?, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
            let finite = width.flatMap { $0.isFinite ? $0 : nil }
            let cardWidth =
                finite
                ?? subviews.map { subview in
                    let ideal = subview.sizeThatFits(.unspecified).width
                    return subview[IsCardMedia.self] ? ideal : ideal + 2 * padding
                }.max() ?? 2 * padding
            let inner = max(0, cardWidth - 2 * padding)
            var frames = [CGRect](repeating: .zero, count: subviews.count)
            var y: CGFloat = 0

            var hasMedia = false
            for (index, subview) in subviews.enumerated() where subview[IsCardMedia.self] {
                let height = subview.sizeThatFits(ProposedViewSize(width: cardWidth, height: nil)).height
                frames[index] = CGRect(x: 0, y: y, width: cardWidth, height: height)
                y += height
                hasMedia = true
            }
            // Below the media, the gap between parts; without it, the padding.
            y += hasMedia ? gap : padding
            var isFirst = true
            for (index, subview) in subviews.enumerated() where !subview[IsCardMedia.self] {
                if !isFirst { y += gap }
                isFirst = false
                let height = subview.sizeThatFits(ProposedViewSize(width: inner, height: nil)).height
                frames[index] = CGRect(x: padding, y: y, width: inner, height: height)
                y += height
            }
            y += padding
            return (CGSize(width: cardWidth, height: y), frames)
        }
    }

    /// The actions of a footer, in rows against the trailing edge, the gap apart. An action moves
    /// to a new row when it does not fit beside the one before it, and one wider than the footer
    /// is offered the footer's width, so that its label wraps.
    private struct CardFooterLayout: Layout {
        let spacing: CGFloat

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
            arrangement(width: proposal.width, subviews: subviews).size
        }

        func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
            let frames = arrangement(width: bounds.width, subviews: subviews).frames
            for (subview, frame) in zip(subviews, frames) {
                subview.place(
                    at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(frame.size)
                )
            }
        }

        private func arrangement(width: CGFloat?, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
            let finite = width.flatMap { $0.isFinite ? $0 : nil }
            let available = finite ?? .infinity
            let sizes = subviews.map { subview in
                let ideal = subview.sizeThatFits(.unspecified)
                return ideal.width <= available
                    ? ideal : subview.sizeThatFits(ProposedViewSize(width: available, height: nil))
            }

            // The actions of each row, by index.
            var rows: [[Int]] = []
            var filled: CGFloat = 0
            for index in sizes.indices {
                let actionWidth = sizes[index].width
                if !rows.isEmpty, filled + spacing + actionWidth <= available {
                    rows[rows.count - 1].append(index)
                    filled += spacing + actionWidth
                } else {
                    rows.append([index])
                    filled = actionWidth
                }
            }
            let rowWidths = rows.map { row in
                row.map { sizes[$0].width }.reduce(0, +) + spacing * CGFloat(max(0, row.count - 1))
            }
            let footerWidth = finite ?? rowWidths.max() ?? 0

            var frames = [CGRect](repeating: .zero, count: subviews.count)
            var y: CGFloat = 0
            for (row, rowWidth) in zip(rows, rowWidths) {
                let height = row.map { sizes[$0].height }.max() ?? 0
                var x = footerWidth - rowWidth
                for index in row {
                    let size = sizes[index]
                    frames[index] = CGRect(x: x, y: y + (height - size.height) / 2, width: size.width, height: size.height)
                    x += size.width + spacing
                }
                y += height + spacing
            }
            if !rows.isEmpty { y -= spacing }
            return (CGSize(width: footerWidth, height: y), frames)
        }
    }
#endif
