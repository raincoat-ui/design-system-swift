#if os(iOS)
    import Raincoat
    import SwiftUI
    import Testing

    extension VisualSnapshots {
        @MainActor
        @Test("Card", arguments: allThemes, allSnapshots)
        func card(theme: RaincoatTheme, snapshot: VisualSnapshot) throws {
            try expectSnapshot(
                of: "card", examples: cardExamples, theme: theme, snapshot: snapshot
            ) { card, text in
                CardInstanceView(
                    interactive: card.interactive,
                    title: text("title"),
                    summary: text("body"),
                    media: text.optional("media"),
                    footer: text.optional("footer")
                )
            }
        }
    }

    /// One card, as an app writes it: in the card style when it is interactive, and with media and
    /// a footer when its example has text for them, as on the web.
    private struct CardInstanceView: View {
        let interactive: Bool
        let title: String
        /// The body's text.
        let summary: String
        let media: String?
        let footer: String?

        var body: some View {
            let card = RaincoatCard(title, level: 3) {
                Text(verbatim: summary).raincoatText(color: .muted)
            }
            if let media, let footer {
                card
                    .media { CardPicture(label: media) }
                    .footer { RaincoatButton(footer, variant: .primary) {} }
            } else if interactive {
                Button {} label: { card }
                    .buttonStyle(.raincoatCard)
            } else {
                card
            }
        }
    }

    /// The media: hills under a sky, in the theme's colors, at the web's aspect ratio of 10 to 3.
    private struct CardPicture: View {
        let label: String
        @Tokens private var tokens

        var body: some View {
            ZStack {
                Rectangle().fill(Color(tokens.color.bg.subtle))
                Hills().fill(Color(tokens.color.accent.default))
            }
            .aspectRatio(10 / 3, contentMode: .fit)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: label))
        }
    }

    /// The web's path for the hills, "M0 120 L0 70 Q100 20 200 70 T400 60 L400 120 Z", in a box of
    /// 400 by 120.
    private struct Hills: Shape {
        func path(in rect: CGRect) -> Path {
            let x = { (value: CGFloat) in rect.minX + value / 400 * rect.width }
            let y = { (value: CGFloat) in rect.minY + value / 120 * rect.height }
            var path = Path()
            path.move(to: CGPoint(x: x(0), y: y(120)))
            path.addLine(to: CGPoint(x: x(0), y: y(70)))
            path.addQuadCurve(to: CGPoint(x: x(200), y: y(70)), control: CGPoint(x: x(100), y: y(20)))
            // T reflects the previous control point through the current point.
            path.addQuadCurve(to: CGPoint(x: x(400), y: y(60)), control: CGPoint(x: x(300), y: y(120)))
            path.addLine(to: CGPoint(x: x(400), y: y(120)))
            path.closeSubpath()
            return path
        }
    }
#endif
