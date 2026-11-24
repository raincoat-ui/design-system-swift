#if canImport(SwiftUI)
    import RaincoatTokens
    import SwiftUI

    /// One tab of a `RaincoatTabs`: its label, an optional leading icon, and the value that
    /// selects it.
    ///
    ///     RaincoatTab("Reviews", value: Section.reviews)
    ///     RaincoatTab("Photos", value: Section.photos, icon: Image(systemName: "photo"))
    ///     RaincoatTab(icon: Image(systemName: "list.bullet"), accessibilityLabel: Text("List"), value: Layout.list)
    public struct RaincoatTab<Value: Hashable>: Identifiable {
        /// The value the tab selects. It identifies the tab, so each tab's must differ.
        public let value: Value
        let title: Text?
        let icon: Image?
        let accessibilityLabel: Text?

        public var id: Value { value }

        /// Creates a tab with a label.
        ///
        /// - Parameters:
        ///   - title: The label: one or two words, in sentence case. It stays on one line and is
        ///     never truncated.
        ///   - value: The value the tab selects.
        ///   - icon: An icon before the label. It is decoration: the label carries the meaning.
        public init(_ title: Text, value: Value, icon: Image? = nil) {
            self.title = title
            self.value = value
            self.icon = icon
            accessibilityLabel = nil
        }

        /// Creates a tab whose label is a localized string key.
        public init(_ titleKey: LocalizedStringKey, value: Value, icon: Image? = nil) {
            self.init(Text(titleKey), value: value, icon: icon)
        }

        /// Creates a tab whose label is a string that is shown as it is.
        @_disfavoredOverload
        public init(_ title: some StringProtocol, value: Value, icon: Image? = nil) {
            self.init(Text(title), value: value, icon: icon)
        }

        /// Creates a tab that shows only an icon.
        ///
        /// - Parameters:
        ///   - icon: The icon.
        ///   - accessibilityLabel: What the tab's panel holds, for assistive technology. An icon
        ///     alone has no name.
        ///   - value: The value the tab selects.
        public init(icon: Image, accessibilityLabel: Text, value: Value) {
            title = nil
            self.value = value
            self.icon = icon
            self.accessibilityLabel = accessibilityLabel
        }
    }

    /// A row of tabs that switches between panels of related content in one view. It follows the
    /// Raincoat Tabs spec.
    ///
    ///     RaincoatTabs(selection: $section, tabs: [
    ///         RaincoatTab("Details", value: .details),
    ///         RaincoatTab("Reviews", value: .reviews),
    ///     ]) { section in
    ///         switch section {
    ///         case .details: DetailsView()
    ///         case .reviews: ReviewsView()
    ///         }
    ///     }
    ///
    /// The row runs across the full width over a hairline. When the tabs do not fit, it scrolls
    /// sideways, and the selected tab is scrolled into view. Only the selected tab's panel is
    /// shown. A tab has no disabled state: leave out a tab that leads nowhere.
    ///
    /// VoiceOver is told the row is a tab bar, so it reads each tab's position, and the selected
    /// tab carries the selected trait. A keyboard moves focus between the tabs as for any
    /// control, and Space selects. Colors, sizes, and text styles come from the theme in the
    /// environment; see `View.raincoatTheme(_:)`.
    public struct RaincoatTabs<Value: Hashable, Panel: View>: View {
        private let tabs: [RaincoatTab<Value>]
        private let selection: Binding<Value>?
        @State private var ownSelection: Value
        private let panel: (Value) -> Panel

        /// Creates tabs whose selection the app controls.
        ///
        /// - Parameters:
        ///   - selection: The value of the selected tab.
        ///   - tabs: The tabs, in order. Two to seven is the range the guidelines give.
        ///   - panel: The content of the selected tab.
        public init(
            selection: Binding<Value>,
            tabs: [RaincoatTab<Value>],
            @ViewBuilder panel: @escaping (Value) -> Panel
        ) {
            self.tabs = tabs
            self.selection = selection
            _ownSelection = State(initialValue: selection.wrappedValue)
            self.panel = panel
        }

        /// Creates tabs that keep their own selection.
        ///
        /// - Parameters:
        ///   - tabs: The tabs, in order. There must be at least one.
        ///   - initialSelection: The value of the tab selected first. The first tab, if nil.
        ///   - panel: The content of the selected tab.
        public init(
            tabs: [RaincoatTab<Value>],
            initialSelection: Value? = nil,
            @ViewBuilder panel: @escaping (Value) -> Panel
        ) {
            precondition(initialSelection != nil || !tabs.isEmpty, "RaincoatTabs needs at least one tab")
            self.tabs = tabs
            selection = nil
            _ownSelection = State(initialValue: initialSelection ?? tabs[0].value)
            self.panel = panel
        }

        public var body: some View {
            let selected = selection?.wrappedValue ?? ownSelection
            VStack(alignment: .leading, spacing: 0) {
                TabRow(tabs: tabs, selected: selected) { value in
                    if let selection {
                        selection.wrappedValue = value
                    } else {
                        ownSelection = value
                    }
                }
                panel(selected)
            }
        }
    }

    /// What VoiceOver is told of the row and of each tab, besides each tab being a button.
    enum TabsAccessibility {
        /// The row is a tab bar, so that VoiceOver reads each tab's position, such as "2 of 3".
        static var row: AccessibilityTraits { .isTabBar }

        /// The selected tab carries the selected trait.
        static func tab(isSelected: Bool) -> AccessibilityTraits {
            isSelected ? .isSelected : []
        }
    }

    /// The row: the tabs in a list that scrolls sideways, over a hairline across the full width.
    private struct TabRow<Value: Hashable>: View {
        let tabs: [RaincoatTab<Value>]
        let selected: Value
        let select: (Value) -> Void

        @Tokens private var tokens
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            let measurements = TabMeasurements(tokens.tabs)
            let divider = tokens.tabs.divider
            let easing = tokens.tabs.transition.easing
            let scroll: Animation? =
                reduceMotion
                ? nil
                : .timingCurve(
                    easing.x1, easing.y1, easing.x2, easing.y2, duration: tokens.tabs.transition.duration
                )

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    TabStrip(tabs: tabs, selected: selected, select: select)
                        // Room above and below a tab shorter than the minimum target, for its
                        // touch area: the scrolling list takes touches only inside its edges.
                        .padding(.vertical, measurements.targetReach)
                }
                .scrollIndicators(.hidden)
                .onAppear { proxy.scrollTo(selected) }
                .onChange(of: selected) { _, value in
                    withAnimation(scroll) { proxy.scrollTo(value) }
                }
            }
            // The room for touches takes no layout space: the row is as tall as its tabs.
            .padding(.vertical, -measurements.targetReach)
            // The hairline is behind the tabs, so the indicator covers it under the selected one.
            .background(alignment: .bottom) {
                Rectangle()
                    .fill(Color(divider.color))
                    .frame(height: divider.width)
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(TabsAccessibility.row)
        }
    }

    /// The tabs side by side, each as wide as its content.
    struct TabStrip<Value: Hashable>: View {
        let tabs: [RaincoatTab<Value>]
        let selected: Value
        let select: (Value) -> Void

        var body: some View {
            // The stack follows the layout direction: in right-to-left layouts the first tab is
            // on the right.
            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    TabButton(tab: tab, isSelected: tab.value == selected) { select(tab.value) }
                        .id(tab.value)
                }
            }
        }
    }

    /// One tab: a button with the tab's look, and the selected trait when it is selected.
    private struct TabButton<Value: Hashable>: View {
        let tab: RaincoatTab<Value>
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            let button = Button(action: action) {
                TabLabel(title: tab.title, icon: tab.icon)
            }
            .buttonStyle(TabButtonStyle(isSelected: isSelected))
            .accessibilityAddTraits(TabsAccessibility.tab(isSelected: isSelected))

            if let accessibilityLabel = tab.accessibilityLabel {
                button.accessibilityLabel(accessibilityLabel)
            } else {
                button
            }
        }
    }

    /// The look of a tab, from the Tabs tokens.
    private struct TabButtonStyle: ButtonStyle {
        let isSelected: Bool

        func makeBody(configuration: Configuration) -> some View {
            TabContainer(label: configuration.label, isSelected: isSelected, isPressed: configuration.isPressed)
        }
    }

    /// The tab itself: fill, padding, height, indicator, and the text style of the label.
    private struct TabContainer<Label: View>: View {
        let label: Label
        let isSelected: Bool
        let isPressed: Bool

        @Tokens private var tokens
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @TextScale(relativeTo: .body) private var textScale
        @State private var isHovered = false

        var body: some View {
            let tabs = tokens.tabs
            let interaction = TabInteraction(isPressed: isPressed, isHovered: isHovered)
            let colors = TabColors(tabs, isSelected: isSelected, interaction: interaction)
            let measurements = TabMeasurements(tabs)
            let text = measurements.label.resolved(scale: textScale)
            let easing = tabs.transition.easing

            label
                .font(text.font)
                .tracking(text.tracking)
                .lineSpacing(text.lineSpacing)
                .foregroundStyle(Color(colors.foreground))
                .padding(.horizontal, measurements.paddingInline)
                .padding(.vertical, measurements.paddingBlock)
                .frame(minHeight: measurements.height)
                .background {
                    if let fill = colors.fill { Rectangle().fill(Color(fill)) }
                }
                .overlay(alignment: .bottom) {
                    if let indicator = colors.indicator {
                        Rectangle()
                            .fill(Color(indicator))
                            .frame(height: tabs.indicator.width)
                    }
                }
                .onHover { isHovered = $0 }
                // The tab's layout size is what it shows. The area that takes touches, and that
                // assistive technology is given, is at least the minimum target.
                .contentShape(TouchTarget(minimum: measurements.targetMinimum))
                // Color changes ease in. With reduced motion they are immediate.
                .animation(
                    reduceMotion
                        ? nil
                        : .timingCurve(easing.x1, easing.y1, easing.x2, easing.y2, duration: tabs.transition.duration),
                    value: colors
                )
        }
    }

    /// The content of a tab: an optional icon, and the label on one line.
    private struct TabLabel: View {
        let title: Text?
        let icon: Image?

        @Tokens private var tokens
        @TextScale(relativeTo: .body) private var textScale

        var body: some View {
            let measurements = TabMeasurements(tokens.tabs)
            let text = measurements.label.resolved(scale: textScale)
            // Icons grow with the text.
            let iconSize = measurements.iconSize * textScale

            // The stack follows the layout direction, so in right-to-left layouts the icon is on
            // the right of the label.
            HStack(spacing: measurements.gap) {
                if let icon {
                    icon
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        .accessibilityHidden(true)
                }
                if let title {
                    title
                        // One line, at its full width: never wrapped and never truncated. The row
                        // scrolls instead.
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.vertical, text.halfLeading)
                        .frame(minHeight: text.lineHeight)
                }
            }
        }
    }
#endif
