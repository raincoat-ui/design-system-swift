#if canImport(SwiftUI)
    import RaincoatTokens
    import SwiftUI

    /// A button that triggers an action. It follows the Raincoat Button spec.
    ///
    ///     RaincoatButton("Save changes", variant: .primary) { save() }
    ///     RaincoatButton("Save changes", isLoading: isSaving) { save() }
    ///     RaincoatButton(icon: Image(systemName: "trash"), accessibilityLabel: Text("Delete page")) { delete() }
    ///
    /// Disable it with `disabled(_:)`, as any SwiftUI control. Colors, sizes, and text styles
    /// come from the theme in the environment; see `View.raincoatTheme(_:)`.
    ///
    /// The button takes the room it shows. A button smaller than the minimum touch target also
    /// takes touches that land just outside it, so leave at least that much room between two
    /// small buttons.
    public struct RaincoatButton: View {
        private let title: Text?
        private let accessibilityLabel: Text?
        private let variant: ButtonVariant
        private let size: ButtonSize
        private let leadingIcon: Image?
        private let trailingIcon: Image?
        private let isFullWidth: Bool
        private let isLoading: Bool
        private let action: () -> Void

        @Environment(\.isEnabled) private var isEnabled

        /// Creates a button with a label.
        ///
        /// - Parameters:
        ///   - title: The label. It wraps when it does not fit and is never truncated.
        ///   - variant: How much emphasis the action gets.
        ///   - size: The height and text size of the button.
        ///   - leadingIcon: An icon before the label. It is decoration: the label carries the meaning.
        ///   - trailingIcon: An icon after the label.
        ///   - isFullWidth: Whether the button stretches to the width of its container.
        ///   - isLoading: Whether the action is in progress. A loading button keeps its label and
        ///     focus, shows a spinner in place of the leading icon, ignores activation, and tells
        ///     assistive technology that it is in progress.
        ///   - action: What the button does.
        public init(
            _ title: Text,
            variant: ButtonVariant = .standard,
            size: ButtonSize = .standard,
            leadingIcon: Image? = nil,
            trailingIcon: Image? = nil,
            isFullWidth: Bool = false,
            isLoading: Bool = false,
            action: @escaping () -> Void
        ) {
            self.title = title
            accessibilityLabel = nil
            self.variant = variant
            self.size = size
            self.leadingIcon = leadingIcon
            self.trailingIcon = trailingIcon
            self.isFullWidth = isFullWidth
            self.isLoading = isLoading
            self.action = action
        }

        /// Creates a button whose label is a localized string key.
        public init(
            _ titleKey: LocalizedStringKey,
            variant: ButtonVariant = .standard,
            size: ButtonSize = .standard,
            leadingIcon: Image? = nil,
            trailingIcon: Image? = nil,
            isFullWidth: Bool = false,
            isLoading: Bool = false,
            action: @escaping () -> Void
        ) {
            self.init(
                Text(titleKey), variant: variant, size: size, leadingIcon: leadingIcon,
                trailingIcon: trailingIcon, isFullWidth: isFullWidth, isLoading: isLoading, action: action
            )
        }

        /// Creates a button whose label is a string that is shown as it is.
        @_disfavoredOverload
        public init(
            _ title: some StringProtocol,
            variant: ButtonVariant = .standard,
            size: ButtonSize = .standard,
            leadingIcon: Image? = nil,
            trailingIcon: Image? = nil,
            isFullWidth: Bool = false,
            isLoading: Bool = false,
            action: @escaping () -> Void
        ) {
            self.init(
                Text(title), variant: variant, size: size, leadingIcon: leadingIcon,
                trailingIcon: trailingIcon, isFullWidth: isFullWidth, isLoading: isLoading, action: action
            )
        }

        /// Creates a square button that shows only an icon.
        ///
        /// - Parameters:
        ///   - icon: The icon.
        ///   - accessibilityLabel: What the button does, for assistive technology. An icon alone
        ///     has no name.
        public init(
            icon: Image,
            accessibilityLabel: Text,
            variant: ButtonVariant = .standard,
            size: ButtonSize = .standard,
            isLoading: Bool = false,
            action: @escaping () -> Void
        ) {
            title = nil
            self.accessibilityLabel = accessibilityLabel
            self.variant = variant
            self.size = size
            leadingIcon = icon
            trailingIcon = nil
            isFullWidth = false
            self.isLoading = isLoading
            self.action = action
        }

        public var body: some View {
            let style = RaincoatButtonStyle(
                variant: variant, size: size, isFullWidth: isFullWidth,
                isLoading: isLoading, isIconOnly: title == nil
            )
            // A loading button stays enabled so that it keeps focus; it ignores activation instead.
            let button = Button {
                if !isLoading { action() }
            } label: {
                ButtonLabel(
                    title: title, leadingIcon: leadingIcon, trailingIcon: trailingIcon,
                    isLoading: isLoading, size: size
                )
            }
            .buttonStyle(style)
            // iOS has no busy state to set, so assistive technology is told in words, after the
            // name: "Save changes, In progress". A disabled button is not also busy.
            .accessibilityValue(isLoading && isEnabled ? Text("button.loading", bundle: .module) : Text(verbatim: ""))

            if let accessibilityLabel {
                button.accessibilityLabel(accessibilityLabel)
            } else {
                button
            }
        }
    }

    /// The Raincoat button's appearance, for any SwiftUI button.
    ///
    /// Use it to give a `Link`, a `Menu`, or a `NavigationLink` the look of a `RaincoatButton`:
    ///
    ///     Link("Read the guide", destination: url).buttonStyle(.raincoat(variant: .ghost))
    public struct RaincoatButtonStyle: ButtonStyle {
        let variant: ButtonVariant
        let size: ButtonSize
        let isFullWidth: Bool
        let isLoading: Bool
        let isIconOnly: Bool

        public init(variant: ButtonVariant = .standard, size: ButtonSize = .standard, isFullWidth: Bool = false) {
            self.init(variant: variant, size: size, isFullWidth: isFullWidth, isLoading: false, isIconOnly: false)
        }

        init(variant: ButtonVariant, size: ButtonSize, isFullWidth: Bool, isLoading: Bool, isIconOnly: Bool) {
            self.variant = variant
            self.size = size
            self.isFullWidth = isFullWidth
            self.isLoading = isLoading
            self.isIconOnly = isIconOnly
        }

        public func makeBody(configuration: Configuration) -> some View {
            ButtonContainer(style: self, label: configuration.label, isPressed: configuration.isPressed)
        }
    }

    extension ButtonStyle where Self == RaincoatButtonStyle {
        /// The Raincoat button's appearance.
        public static func raincoat(
            variant: ButtonVariant = .standard,
            size: ButtonSize = .standard,
            isFullWidth: Bool = false
        ) -> RaincoatButtonStyle {
            RaincoatButtonStyle(variant: variant, size: size, isFullWidth: isFullWidth)
        }
    }

    /// The container: fill, outline, padding, minimum sizes, and the text style of the label.
    private struct ButtonContainer<Label: View>: View {
        let style: RaincoatButtonStyle
        let label: Label
        let isPressed: Bool

        @Tokens private var tokens
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1
        @State private var isHovered = false

        var body: some View {
            let button = tokens.button
            let interaction = ButtonInteraction(
                isEnabled: isEnabled, isLoading: style.isLoading, isPressed: isPressed, isHovered: isHovered
            )
            let colors = ButtonColors(button, variant: style.variant, interaction: interaction)
            let measurements = ButtonMeasurements(button, size: style.size)
            let text = measurements.label.resolved(scale: textScale)
            let shape = RoundedRectangle(cornerRadius: button.radius, style: .continuous)
            let easing = button.transition.easing

            label
                .font(text.font)
                .tracking(text.tracking)
                .lineSpacing(text.lineSpacing)
                .foregroundStyle(Color(colors.foreground))
                .padding(.horizontal, style.isIconOnly ? 0 : measurements.paddingInline)
                .padding(.vertical, style.isIconOnly ? 0 : measurements.paddingBlock)
                .frame(
                    minWidth: measurements.height,
                    maxWidth: style.isFullWidth ? .infinity : nil,
                    minHeight: measurements.height
                )
                .background {
                    if let fill = colors.fill { shape.fill(Color(fill)) }
                }
                .overlay {
                    if let border = colors.border {
                        shape.strokeBorder(Color(border), lineWidth: button.borderWidth)
                    }
                }
                .onHover { isHovered = $0 }
                // The button's layout size is what it shows. The area that takes touches, and
                // that assistive technology is given, is at least the minimum target.
                .contentShape(TouchTarget(minimum: button.targetMinimum))
                // Color changes ease in. With reduced motion they are immediate.
                .animation(
                    reduceMotion
                        ? nil
                        : .timingCurve(
                            easing.x1, easing.y1, easing.x2, easing.y2, duration: button.transition.duration
                        ),
                    value: interaction
                )
        }
    }

    /// The area of a button that takes touches: the container, and where the container is
    /// smaller than the minimum target, the space around it out to that size.
    struct TouchTarget: Shape {
        let minimum: CGFloat

        func path(in rect: CGRect) -> Path {
            Path(
                rect.insetBy(
                    dx: min(0, (rect.width - minimum) / 2),
                    dy: min(0, (rect.height - minimum) / 2)
                )
            )
        }
    }

    /// The content of a `RaincoatButton`: an optional icon or spinner, the label, an optional icon.
    private struct ButtonLabel: View {
        let title: Text?
        let leadingIcon: Image?
        let trailingIcon: Image?
        let isLoading: Bool
        let size: ButtonSize

        @Tokens private var tokens
        @Environment(\.isEnabled) private var isEnabled
        @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1

        var body: some View {
            let measurements = ButtonMeasurements(tokens.button, size: size)
            let text = measurements.label.resolved(scale: textScale)
            let iconSize = measurements.iconSize * textScale
            // Icons grow with the text. A disabled button is not also busy.
            let isBusy = isLoading && isEnabled

            // The stack follows the layout direction, so in right-to-left layouts the leading
            // icon is on the right.
            HStack(spacing: tokens.button.gap) {
                if isBusy {
                    ButtonSpinner(size: iconSize)
                } else if let leadingIcon {
                    icon(leadingIcon, size: iconSize)
                }
                if let title {
                    title
                        .multilineTextAlignment(.center)
                        // Wrap onto as many lines as it takes; never truncate.
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        // One line is exactly as tall as the token's line height; more lines
                        // keep that rhythm.
                        .padding(.vertical, text.halfLeading)
                        .frame(minHeight: text.lineHeight)
                }
                if let trailingIcon {
                    icon(trailingIcon, size: iconSize)
                }
            }
        }

        private func icon(_ image: Image, size: CGFloat) -> some View {
            image
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }

    /// Shown in place of the leading icon while the button's action is in progress.
    private struct ButtonSpinner: View {
        let size: CGFloat
        @State private var isTurning = false

        var body: some View {
            let lineWidth = size / 8
            ZStack {
                Circle().strokeBorder(lineWidth: lineWidth).opacity(0.25)
                Circle()
                    .inset(by: lineWidth / 2)
                    .trim(from: 0, to: 0.25)
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(isTurning ? 360 : 0))
            }
            .frame(width: size, height: size)
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { isTurning = true }
            }
            // The ring is decoration. The button says that its action is in progress.
            .accessibilityHidden(true)
        }
    }
#endif
