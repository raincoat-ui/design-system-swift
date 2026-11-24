#if canImport(SwiftUI)
    import RaincoatTokens
    import SwiftUI

    #if canImport(UIKit)
        import UIKit
    #endif

    // The Raincoat Dialog, alert dialog, and Sheet. They follow the Raincoat Dialog spec.
    //
    // On iOS a dialog and a sheet are both the system sheet, which is how iOS presents a modal
    // task: from the bottom on iPhone and centered on iPad. It is sized to its content with a
    // presentation detent, and the tokens are inside it: the fill, the title, the description,
    // the spaces, the hairlines, and the footer. The system draws the sheet's corners, its
    // shadow, the dimming behind it, and the drag indicator, closes it on a swipe or VoiceOver's
    // escape gesture, and returns VoiceOver to where it was. An alert dialog is the system alert.

    extension View {
        /// Presents a dialog: a short task that must be finished or abandoned before going on.
        /// It follows the dialog part of the Raincoat Dialog spec.
        ///
        ///     .raincoatDialog(Text("Rename file"), titleLevel: 2, isPresented: $isRenaming) {
        ///         TextField("Name", text: $name)
        ///     } actions: {
        ///         RaincoatButton("Cancel") { isRenaming = false }
        ///         RaincoatButton("Rename", variant: .primary) { rename() }
        ///     }
        ///
        /// It is the system sheet, as tall as its content, with the theme's fill, title, and
        /// spaces. The body scrolls between the header and the footer when it does not fit, and
        /// the whole dialog scrolls when the screen is too short for three lines of the body.
        /// While everything fits, the dialog is one scrolling area that does not move, so that
        /// text that grows is never cut off before the sheet grows with it.
        /// The footer's buttons sit at the trailing edge, the primary action last, and stack,
        /// the primary action first, when they do not fit in a row.
        ///
        /// To start in a field, give the field focus with `focused(_:)` when it appears. To keep
        /// the dialog open while it holds unsaved changes, pass `isDismissDisabled`, which stops
        /// a swipe, and ask before your own buttons set `isPresented` to false.
        ///
        /// - Parameters:
        ///   - title: Names the dialog. It wraps and is never cut short.
        ///   - titleLevel: The title's heading level, from 1 to 6, for VoiceOver's rotor.
        ///   - isPresented: Whether the dialog is shown.
        ///   - description: One sentence under the title.
        ///   - closeLabel: The name of the close button, which is shown only when you give it,
        ///     at the end of the header. Give it when the footer has no Cancel.
        ///   - isDismissDisabled: Whether a swipe is refused, as while there are unsaved changes.
        ///   - onDismiss: Called when the dialog has closed.
        ///   - content: The body.
        ///   - actions: The footer's buttons, Cancel first and the primary action last.
        public func raincoatDialog<Content: View, Actions: View>(
            _ title: Text,
            titleLevel: Int,
            isPresented: Binding<Bool>,
            description: Text? = nil,
            closeLabel: Text? = nil,
            isDismissDisabled: Bool = false,
            onDismiss: (() -> Void)? = nil,
            @ViewBuilder content: @escaping () -> Content,
            @ViewBuilder actions: @escaping () -> Actions
        ) -> some View {
            let heading = DialogHeading(
                title: title, level: titleLevel, description: description, closeLabel: closeLabel
            )
            return sheet(isPresented: isPresented, onDismiss: onDismiss) {
                DialogPresentation(
                    kind: .dialog,
                    heading: heading,
                    isDismissDisabled: isDismissDisabled,
                    close: { isPresented.wrappedValue = false },
                    content: content(),
                    actions: actions()
                )
            }
        }

        /// Presents a dialog with no footer, such as one that only shows information. It has a
        /// close button, named by `closeLabel`, as its way out.
        public func raincoatDialog<Content: View>(
            _ title: Text,
            titleLevel: Int,
            isPresented: Binding<Bool>,
            description: Text? = nil,
            closeLabel: Text,
            isDismissDisabled: Bool = false,
            onDismiss: (() -> Void)? = nil,
            @ViewBuilder content: @escaping () -> Content
        ) -> some View {
            raincoatDialog(
                title, titleLevel: titleLevel, isPresented: isPresented, description: description,
                closeLabel: closeLabel, isDismissDisabled: isDismissDisabled, onDismiss: onDismiss,
                content: content, actions: { EmptyView() }
            )
        }

        /// Presents a sheet: a longer task, or one that keeps the screen behind in view. It
        /// follows the sheet part of the Raincoat Dialog spec.
        ///
        /// It is the system sheet, as a dialog is, with the system's drag indicator: from the
        /// bottom on iPhone and centered on iPad, whichever edge the other platforms use. A
        /// swipe down closes it, and so do the close button or Cancel and VoiceOver's escape
        /// gesture: dragging is never the only way out. The parameters are a dialog's.
        public func raincoatSheet<Content: View, Actions: View>(
            _ title: Text,
            titleLevel: Int,
            isPresented: Binding<Bool>,
            description: Text? = nil,
            closeLabel: Text? = nil,
            isDismissDisabled: Bool = false,
            onDismiss: (() -> Void)? = nil,
            @ViewBuilder content: @escaping () -> Content,
            @ViewBuilder actions: @escaping () -> Actions
        ) -> some View {
            let heading = DialogHeading(
                title: title, level: titleLevel, description: description, closeLabel: closeLabel
            )
            return sheet(isPresented: isPresented, onDismiss: onDismiss) {
                DialogPresentation(
                    kind: .sheet,
                    heading: heading,
                    isDismissDisabled: isDismissDisabled,
                    close: { isPresented.wrappedValue = false },
                    content: content(),
                    actions: actions()
                )
            }
        }

        /// Presents a sheet with no footer. It has a close button, named by `closeLabel`.
        public func raincoatSheet<Content: View>(
            _ title: Text,
            titleLevel: Int,
            isPresented: Binding<Bool>,
            description: Text? = nil,
            closeLabel: Text,
            isDismissDisabled: Bool = false,
            onDismiss: (() -> Void)? = nil,
            @ViewBuilder content: @escaping () -> Content
        ) -> some View {
            raincoatSheet(
                title, titleLevel: titleLevel, isPresented: isPresented, description: description,
                closeLabel: closeLabel, isDismissDisabled: isDismissDisabled, onDismiss: onDismiss,
                content: content, actions: { EmptyView() }
            )
        }

        /// Presents an alert dialog, which asks people to confirm something consequential. It
        /// follows the alert-dialog part of the Raincoat Dialog spec.
        ///
        ///     .raincoatAlertDialog(
        ///         Text("Delete this address?"), isPresented: $isConfirming,
        ///         message: Text("It is removed from your account."),
        ///         actionLabel: Text("Delete address"), destructive: true,
        ///         cancelLabel: Text("Cancel")
        ///     ) { delete() }
        ///
        /// It is the system alert, which follows the person's text size, bold text, and contrast
        /// settings, and is what people on iOS recognize as a request to confirm. The theme does
        /// not reach it. Its Cancel button has the cancel role, so Escape and VoiceOver's escape
        /// gesture mean Cancel, and nothing outside the alert closes it.
        ///
        /// - Parameters:
        ///   - title: Says what will happen, as a question: "Delete this address?".
        ///   - isPresented: Whether the alert dialog is shown.
        ///   - message: One sentence under the title, such as what confirming does.
        ///   - actionLabel: The confirming button. It repeats the verb of the title.
        ///   - destructive: Whether confirming destroys something: the button then has the
        ///     destructive role.
        ///   - cancelLabel: The button that closes the alert dialog without doing anything.
        ///   - onCancel: Called when the alert dialog is cancelled.
        ///   - action: What confirming does.
        public func raincoatAlertDialog(
            _ title: Text,
            isPresented: Binding<Bool>,
            message: Text? = nil,
            actionLabel: Text,
            destructive: Bool = false,
            cancelLabel: Text,
            onCancel: @escaping () -> Void = {},
            action: @escaping () -> Void
        ) -> some View {
            alert(title, isPresented: isPresented) {
                Button(role: .cancel, action: onCancel) { cancelLabel }
                Button(role: destructive ? .destructive : nil, action: action) { actionLabel }
            } message: {
                if let message { message }
            }
        }
    }

    /// The name of the body's scrolling area, which the body's offset is read in.
    private let dialogBodySpace = "raincoat-dialog-body"

    /// How a dialog is presented. On iOS both are the system sheet; a sheet shows the system's
    /// drag indicator, which a dialog, a short task, does without.
    enum DialogKind: Sendable {
        case dialog
        case sheet
    }

    /// What a dialog's header shows.
    struct DialogHeading {
        let title: Text
        let level: Int
        let description: Text?
        let closeLabel: Text?
    }

    /// A dialog or a sheet as presented: the system sheet, sized to the dialog's content, with
    /// the dialog inside it.
    struct DialogPresentation<Content: View, Actions: View>: View {
        let kind: DialogKind
        let heading: DialogHeading
        let isDismissDisabled: Bool
        let close: () -> Void
        let content: Content
        let actions: Actions

        @Tokens private var tokens
        @TextScale(relativeTo: .body) private var textScale
        // The heights of the sections, each with its space, as last laid out.
        @State private var headerHeight: CGFloat = 0
        @State private var bodyHeight: CGFloat = 0
        @State private var footerHeight: CGFloat = 0
        // How far the body is scrolled, and the height of its visible area.
        @State private var offset: CGFloat = 0
        @State private var viewport: CGFloat = 0
        // Where the software keyboard is on the screen, while it shows.
        @State private var keyboard: CGRect?
        #if canImport(UIKit)
            private static var keyboardChanges: NotificationCenter.Publisher {
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            }
            private static var keyboardHides: NotificationCenter.Publisher {
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            }
        #endif

        var body: some View {
            let look = DialogAppearance(tokens)
            let sections = DialogSections(heading: heading, close: close, content: content, actions: actions)
            let ideal = headerHeight + bodyHeight + footerHeight
            // As tall as the content, once it is measured; the system keeps a sheet within the
            // screen, and the dialog scrolls in what it has (DialogScrolling).
            let detent: PresentationDetent = ideal > 0 ? .height(ideal) : .large
            GeometryReader { proxy in
                // A sheet that cannot rise above the keyboard has its bottom covered by it. The
                // dialog keeps to what shows, so that its scrolling area ends above the keyboard,
                // and what is scrolled into view, as the field being edited, stays in view.
                let placed = proxy.frame(in: .global)
                let covered = CGFloat(
                    KeyboardCover(
                        dialogTop: Double(placed.minY), dialogBottom: Double(placed.maxY),
                        keyboardTop: keyboard.map { Double($0.minY) },
                        keyboardBottom: keyboard.map { Double($0.maxY) }
                    ).height
                )
                let shown = max(0, proxy.size.height - covered)
                let scrolling = DialogScrolling(
                    available: Double(shown),
                    header: Double(headerHeight),
                    body: Double(bodyHeight),
                    footer: Double(footerHeight),
                    bodyLine: look.description.lineHeight * look.description.size * Double(textScale),
                    bodySpace: sections.bodySpace(look)
                )
                let wholeScrolls = scrolling == .whole
                // While the body scrolls, the header and the footer stay in place, with a hairline
                // at an edge while content is beneath it. Otherwise they are in the one scrolling
                // area with the body: while everything fits, nothing in it is held to a height, so
                // text that grows before the sheet does goes into it instead of being cut off.
                let dividers =
                    wholeScrolls
                    ? DialogDividers.none
                    : DialogDividers(offset: Double(offset), viewport: Double(viewport), content: Double(bodyHeight))
                // One arrangement for both, in which the body keeps its place: switching between
                // them, as when the keyboard shows at a large text size, keeps the app's content,
                // with its state and its focus, instead of making it anew.
                VStack(spacing: 0) {
                    if !wholeScrolls {
                        sections.headerSection(look, divider: dividers.underHeader)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                    }
                    if sections.hasBody || wholeScrolls {
                        ScrollView {
                            VStack(spacing: 0) {
                                if wholeScrolls {
                                    sections.headerSection(look, divider: false)
                                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                                            headerHeight = $0
                                        }
                                }
                                sections.bodySection(look)
                                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bodyHeight = $0 }
                                    .onGeometryChange(for: CGFloat.self) {
                                        -$0.frame(in: .named(dialogBodySpace)).minY
                                    } action: { offset = $0 }
                                if wholeScrolls {
                                    sections.footerSection(look, divider: false)
                                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                                            footerHeight = $0
                                        }
                                }
                            }
                        }
                        .coordinateSpace(.named(dialogBodySpace))
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewport = $0 }
                        // Content that fits does not move under a drag, which moves the sheet.
                        .scrollBounceBehavior(.basedOnSize)
                    }
                    if !wholeScrolls {
                        sections.footerSection(look, divider: dividers.overFooter)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { footerHeight = $0 }
                    }
                }
                .frame(width: proxy.size.width, height: shown, alignment: .top)
                #if canImport(UIKit)
                    .background { EditedFieldReveal(cover: covered) }
                #endif
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
            .presentationDetents([detent])
            .presentationDragIndicator(kind == .sheet ? .visible : .hidden)
            .presentationBackground(Color(look.background))
            .interactiveDismissDisabled(isDismissDisabled)
            #if canImport(UIKit)
                .onReceive(Self.keyboardChanges) { note in
                    keyboard = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
                }
                .onReceive(Self.keyboardHides) { _ in keyboard = nil }
            #endif
        }
    }

    #if canImport(UIKit)
        /// Brings the field being edited into view in the scrolling area that holds it, each time
        /// the keyboard comes to cover a different part of the dialog. Only then, so that it never
        /// scrolls back from where the person has scrolled to.
        private struct EditedFieldReveal: UIViewRepresentable {
            let cover: CGFloat

            final class Coordinator {
                var cover: CGFloat = 0
            }

            func makeCoordinator() -> Coordinator { Coordinator() }

            func makeUIView(context _: Context) -> UIView {
                let view = UIView()
                view.isUserInteractionEnabled = false
                view.isAccessibilityElement = false
                return view
            }

            func updateUIView(_ view: UIView, context: Context) {
                guard cover != context.coordinator.cover else { return }
                context.coordinator.cover = cover
                guard cover > 0 else { return }
                // Once the dialog has been laid out in what the keyboard leaves.
                Task { @MainActor [weak view] in
                    guard let field = view?.window?.firstResponderInside else { return }
                    var ancestor = field.superview
                    while let current = ancestor, !(current is UIScrollView) {
                        ancestor = current.superview
                    }
                    guard let scrollView = ancestor as? UIScrollView else { return }
                    scrollView.scrollRectToVisible(field.convert(field.bounds, to: scrollView), animated: true)
                }
            }
        }

        extension UIView {
            /// This view or the one in it that is the first responder, as a field being edited is.
            fileprivate var firstResponderInside: UIView? {
                if isFirstResponder { return self }
                for subview in subviews {
                    if let found = subview.firstResponderInside { return found }
                }
                return nil
            }
        }
    #endif

    /// The header, the body, and the footer of a dialog, in its colors and spaces. Each section
    /// keeps the padding at the dialog's edges, and half the gap on its side of the line between
    /// it and the next.
    ///
    /// The header and the footer are always as tall as their content. Offered less, a text in them
    /// would keep only a line's height and be drawn over its neighbours, and the dialog would size
    /// its sheet from that height. When they do not fit with room for the body, the whole dialog
    /// scrolls instead (see DialogScrolling).
    struct DialogSections<Content: View, Actions: View> {
        let heading: DialogHeading
        let close: () -> Void
        let content: Content
        let actions: Actions

        var hasBody: Bool { Content.self != EmptyView.self }
        var hasFooter: Bool { Actions.self != EmptyView.self }

        /// The space above and below the body's content.
        func bodySpace(_ look: DialogAppearance) -> Double {
            hasBody ? look.halfGap + (hasFooter ? look.halfGap : look.padding) : 0
        }

        @MainActor
        func headerSection(_ look: DialogAppearance, divider: Bool) -> some View {
            DialogHeader(heading: heading, look: look, isLast: !hasBody && !hasFooter, close: close)
                .fixedSize(horizontal: false, vertical: true)
                .overlay(alignment: .bottom) { DialogDivider(look: look, isShown: divider) }
        }

        @MainActor
        @ViewBuilder
        func bodySection(_ look: DialogAppearance) -> some View {
            if hasBody {
                DialogBody(look: look, isLast: !hasFooter, content: content)
            }
        }

        @MainActor
        @ViewBuilder
        func footerSection(_ look: DialogAppearance, divider: Bool) -> some View {
            if hasFooter {
                DialogFooter(look: look, actions: actions)
                    .fixedSize(horizontal: false, vertical: true)
                    .overlay(alignment: .top) { DialogDivider(look: look, isShown: divider) }
            }
        }
    }

    /// The hairline under the header or over the footer. It keeps its place when hidden, so that
    /// nothing moves when it shows.
    private struct DialogDivider: View {
        let look: DialogAppearance
        let isShown: Bool

        var body: some View {
            Rectangle()
                .fill(Color(look.divider))
                .frame(height: look.dividerWidth)
                .opacity(isShown ? 1 : 0)
                .accessibilityHidden(true)
        }
    }

    /// The title, the description under it, and the close button at the trailing end.
    private struct DialogHeader: View {
        let heading: DialogHeading
        let look: DialogAppearance
        let isLast: Bool
        let close: () -> Void

        var body: some View {
            HStack(alignment: .top, spacing: look.gap) {
                VStack(alignment: .leading, spacing: look.titleGap) {
                    // The title is a heading in heading-md, at the level the app gives it.
                    heading.title.raincoatHeading(level: heading.level, variant: .headingMd)
                    if let description = heading.description {
                        description.raincoatText(.bodyMd)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let closeLabel = heading.closeLabel {
                    RaincoatButton(
                        icon: Image(systemName: "xmark"), accessibilityLabel: closeLabel,
                        variant: .ghost, size: .sm, action: close
                    )
                    // Escape on a hardware keyboard closes the dialog, as the button does.
                    .keyboardShortcut(.cancelAction)
                }
            }
            .padding(.horizontal, look.padding)
            .padding(.top, look.padding)
            .padding(.bottom, isLast ? look.padding : look.halfGap)
        }
    }

    /// The body: the app's content, with text set like the description unless it says otherwise,
    /// at the description's line height: a line of it is as tall as a line of Text, as on the web
    /// and Android.
    private struct DialogBody<Content: View>: View {
        let look: DialogAppearance
        let isLast: Bool
        let content: Content

        @TextScale(relativeTo: .body) private var textScale

        var body: some View {
            let text = look.description.resolved(scale: textScale)
            content
                .font(text.font)
                .tracking(text.tracking)
                .lineSpacing(text.lineSpacing)
                .foregroundStyle(Color(look.foreground))
                .multilineTextAlignment(.leading)
                // Line spacing sets the distance between lines; this puts the rest of the line
                // height above the first line and below the last, as Text does.
                .padding(.vertical, text.halfLeading)
                .frame(maxWidth: .infinity, minHeight: text.lineHeight, alignment: .leading)
                .padding(.horizontal, look.padding)
                .padding(.top, look.halfGap)
                .padding(.bottom, isLast ? look.padding : look.halfGap)
        }
    }

    /// The footer: the buttons in a row at the trailing edge, or stacked when they do not fit.
    private struct DialogFooter<Actions: View>: View {
        let look: DialogAppearance
        let actions: Actions

        var body: some View {
            DialogFooterLayout(spacing: look.footerGap) { actions }
                // Each button takes the width it is offered, so that stacked buttons are as wide
                // as the footer.
                .environment(\.raincoatButtonFillsWidth, true)
                .padding(.horizontal, look.padding)
                .padding(.top, look.halfGap)
                .padding(.bottom, look.padding)
        }
    }

    /// Lays the footer's buttons out as FooterArrangement says: in a row at the trailing edge,
    /// the primary action last, while they fit, and otherwise stacked, the primary action first.
    /// A right-to-left layout mirrors the row, so the buttons sit at the left.
    struct DialogFooterLayout: Layout {
        let spacing: CGFloat

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
            let arrangement = arrange(width: proposal.width, subviews: subviews)
            return CGSize(width: CGFloat(arrangement.width), height: CGFloat(arrangement.height))
        }

        func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
            let arrangement = arrange(width: bounds.width, subviews: subviews)
            for (subview, frame) in zip(subviews, arrangement.frames) {
                subview.place(
                    at: CGPoint(x: bounds.minX + CGFloat(frame.x), y: bounds.minY + CGFloat(frame.y)),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: CGFloat(frame.width), height: CGFloat(frame.height))
                )
            }
        }

        private func arrange(width: CGFloat?, subviews: Subviews) -> FooterArrangement {
            let sizes: [(width: Double, height: Double)] = subviews.map { subview in
                let size = subview.sizeThatFits(.unspecified)
                return (width: Double(size.width), height: Double(size.height))
            }
            let available = width.flatMap { $0.isFinite ? Double($0) : nil }
            return FooterArrangement(sizes: sizes, available: available, spacing: Double(spacing)) { index, width in
                Double(subviews[index].sizeThatFits(ProposedViewSize(width: CGFloat(width), height: nil)).height)
            }
        }
    }

    /// A dialog drawn as it is laid out in its sheet when nothing scrolls, on its fill. The
    /// pixel tests and the snapshots draw it.
    struct DialogPanel<Content: View, Actions: View>: View {
        let heading: DialogHeading
        let content: Content
        let actions: Actions

        @Tokens private var tokens

        init(heading: DialogHeading, content: Content, actions: Actions) {
            self.heading = heading
            self.content = content
            self.actions = actions
        }

        var body: some View {
            let look = DialogAppearance(tokens)
            let sections = DialogSections(heading: heading, close: {}, content: content, actions: actions)
            VStack(spacing: 0) {
                sections.headerSection(look, divider: false)
                sections.bodySection(look)
                sections.footerSection(look, divider: false)
            }
            .background(Color(look.background))
        }
    }
#endif
