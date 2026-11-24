#if os(iOS)
    @testable import Raincoat
    import SwiftUI

    /// A specimen is this wide, in points, as the web's is in CSS pixels, so that long text wraps
    /// at about the same place on both.
    let specimenWidth: CGFloat = 480
    private let specimenPadding: CGFloat = 24
    private let specimenGap: CGFloat = 16

    /// Every example of a component's spec, one under the other, on the theme's canvas color. The
    /// instances of an example sit side by side, from the leading edge, and wrap onto another row
    /// when they do not fit, as on the web.
    struct Specimen<Properties: Sendable, Instance: View>: View {
        let examples: [SpecExample<Properties>]
        /// The locale whose text the examples show.
        let locale: String
        let draw: (Properties, _ text: SnapshotText) -> Instance

        @Tokens private var tokens

        init(
            examples: [SpecExample<Properties>],
            locale: String,
            draw: @escaping (Properties, _ text: SnapshotText) -> Instance
        ) {
            self.examples = examples
            self.locale = locale
            self.draw = draw
        }

        var body: some View {
            VStack(alignment: .leading, spacing: specimenGap) {
                ForEach(examples.indices, id: \.self) { index in
                    let example = examples[index]
                    let text = SnapshotText(example: example.id, locale: locale, values: example.text[locale] ?? [:])
                    WrappingRow(spacing: specimenGap) {
                        ForEach(example.instances.indices, id: \.self) { instance in
                            draw(example.instances[instance], text)
                        }
                    }
                }
            }
            .padding(specimenPadding)
            .frame(width: specimenWidth, alignment: .topLeading)
            .background(Color(tokens.color.bg.canvas))
        }
    }

    /// Views side by side from the leading edge, with a new row for a view that does not fit: a
    /// wrapping flex row on the web. Each view is offered the whole width, so a view wider than
    /// that wraps its own text, and a full-width view takes the row.
    ///
    /// It places views from the left. SwiftUI mirrors a layout in a right-to-left environment, as
    /// it does its stacks.
    struct WrappingRow: Layout {
        let spacing: CGFloat

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
            let frames = arrange(subviews, width: proposal.width)
            let width = proposal.width.flatMap { $0.isFinite ? $0 : nil }
            return CGSize(
                width: width ?? frames.map(\.maxX).max() ?? 0,
                height: frames.map(\.maxY).max() ?? 0
            )
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
            let frames = arrange(subviews, width: bounds.width)
            for (subview, frame) in zip(subviews, frames) {
                subview.place(
                    at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(frame.size)
                )
            }
        }

        /// Where each view goes, from the top left, in rows no wider than the width.
        private func arrange(_ subviews: Subviews, width: CGFloat?) -> [CGRect] {
            let available = width.flatMap { $0.isFinite ? $0 : nil }
            var frames: [CGRect] = []
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            for subview in subviews {
                let size = subview.sizeThatFits(ProposedViewSize(width: available, height: nil))
                if let available, x > 0, x + size.width > available {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
            return frames
        }
    }

    /// Reads how much the environment's Dynamic Type size enlarges body text, as the components'
    /// own scaled metrics do. It draws nothing.
    struct TextScaleProbe: View {
        @MainActor
        final class Reading {
            var scale: CGFloat?
            /// The Dynamic Type size SwiftUI gives the views.
            var dynamicTypeSize: DynamicTypeSize?
        }

        let reading: Reading
        @TextScale private var scale: CGFloat
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        /// - Parameter textStyle: The system text style whose scale is read: body text, as most
        ///   of the components' text follows.
        init(reading: Reading, textStyle: Font.TextStyle = .body) {
            self.reading = reading
            _scale = TextScale(relativeTo: textStyle)
        }

        var body: some View {
            reading.scale = scale
            reading.dynamicTypeSize = dynamicTypeSize
            return Color.clear.frame(width: 0, height: 0)
        }
    }

    /// A text field holding a word, black on white, and nothing else to draw.
    struct TextFieldCheck: View {
        var body: some View {
            TextField("Name", text: .constant("Raincoat"))
                .textFieldStyle(.plain)
                .font(.system(size: 40))
                .foregroundStyle(Color(.sRGB, red: 0, green: 0, blue: 0))
                .padding(24)
                .frame(width: specimenWidth, alignment: .leading)
                .background(Color(.sRGB, red: 1, green: 1, blue: 1))
                .environment(\.colorScheme, .light)
        }
    }

    /// A row four times as wide as the window, red then blue, that scrolls to its blue end as it
    /// appears, as a row of tabs scrolls to the selected tab.
    struct ScrollCheck: View {
        var body: some View {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        Color(.sRGB, red: 1, green: 0, blue: 0)
                            .frame(width: 2 * specimenWidth, height: 40)
                        Color(.sRGB, red: 0, green: 0, blue: 1)
                            .frame(width: 2 * specimenWidth, height: 40)
                            .id("end")
                    }
                }
                .scrollIndicators(.hidden)
                .onAppear { proxy.scrollTo("end", anchor: .trailing) }
            }
            .frame(width: specimenWidth, height: 40)
        }
    }
#endif
