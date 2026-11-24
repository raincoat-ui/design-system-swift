#if canImport(SwiftUI)
    import Accessibility
    import RaincoatTokens
    import SwiftUI

    /// A toast: a short message near the bottom of the screen that says something has happened,
    /// such as "Message archived", optionally with one action such as Undo. It follows the
    /// Raincoat Toast spec.
    ///
    /// Put a toast host on a screen once, and show toasts from anywhere inside it:
    ///
    ///     InboxView().raincoatToastHost()
    ///
    ///     @Environment(\.showRaincoatToast) private var showToast
    ///     showToast(RaincoatToast("Message archived"))
    ///     showToast(RaincoatToast("Message archived", action: .init("Undo") { undo() }, closeLabel: "Close"))
    ///
    /// The host shows one toast at a time, in order. A toast never takes focus; VoiceOver says
    /// its message after whatever it is saying. Without an action, a toast closes after 6
    /// seconds, and the time stops while a pointer is over it, while VoiceOver or the keyboard
    /// is on it, and while the app is in the background. A toast with an action stays until the
    /// action is used or the toast is closed, so it always has a close button. A swipe down
    /// closes a toast too, and so does Escape while the keyboard is on one of its buttons.
    ///
    /// Drawn on its own, outside a host, a toast stands still: it is not announced and does not
    /// close. That is for previews, documentation, and tests.
    public struct RaincoatToast: View {
        /// The one action a toast can offer.
        public struct Action {
            let label: String
            let perform: () -> Void

            /// - Parameters:
            ///   - label: One or two words, such as "Undo" or "View".
            ///   - perform: What the action does. The toast closes after it.
            public init(_ label: String, perform: @escaping () -> Void) {
                self.label = label
                self.perform = perform
            }
        }

        let message: String
        let action: Action?
        let closeLabel: String?

        @Tokens private var tokens
        @Environment(\.raincoatToastControl) private var control
        @TextScale(relativeTo: .body) private var textScale
        @AccessibilityFocusState private var voiceOverFocus: ToastPart?
        @FocusState private var keyboardFocus: ToastPart?
        @State private var swipe: CGFloat = 0

        /// Creates a toast without an action.
        ///
        /// - Parameters:
        ///   - message: What happened, in one short sentence, such as "Address deleted", in the
        ///     app's language. It wraps and is never truncated.
        ///   - closeLabel: The name of a close button, such as "Close". Without it, there is no
        ///     close button.
        public init(_ message: String, closeLabel: String? = nil) {
            self.message = message
            action = nil
            self.closeLabel = closeLabel
        }

        /// Creates a toast with an action and a close button. It stays until one is used.
        ///
        /// - Parameters:
        ///   - message: What happened, in one short sentence, in the app's language.
        ///   - action: One action, such as Undo.
        ///   - closeLabel: The name of the close button, such as "Close", read by assistive
        ///     technology. The button shows only a cross.
        public init(_ message: String, action: Action, closeLabel: String) {
            self.message = message
            self.action = action
            self.closeLabel = closeLabel
        }

        public var body: some View {
            let toast = tokens.toast
            let shape = RoundedRectangle(cornerRadius: toast.radius, style: .continuous)

            HStack(alignment: .top, spacing: toast.gap) {
                // The message and the action share a line while they fit. When they do not, the
                // action moves below the message, at the end.
                MessageAndAction(spacing: toast.gap) {
                    messageText
                    actionButton
                }
                closeButton
            }
            // The outline is drawn inside the padding, so the content keeps its distance from it.
            .padding(.horizontal, toast.paddingInline + toast.border.width)
            .padding(.vertical, toast.paddingBlock + toast.border.width)
            .foregroundStyle(Color(toast.fg))
            .raincoatShadow(toast.shadow, in: shape, fill: Color(toast.bg))
            .overlay { shape.strokeBorder(Color(toast.border.color), lineWidth: toast.border.width) }
            .contentShape(shape)
            .onHover { hovering in control?.setPaused(.hover, hovering) }
            .onChange(of: voiceOverFocus != nil || keyboardFocus != nil) { _, focused in
                control?.setPaused(.focus, focused)
            }
            .offset(y: swipe)
            .simultaneousGesture(swipeDown)
            // Escape closes the toast while the keyboard is on one of its buttons, and VoiceOver's
            // escape gesture while VoiceOver is in it.
            .onKeyPress(.escape) {
                guard let control else { return .ignored }
                control.close()
                return .handled
            }
            .accessibilityElement(children: .contain)
            .accessibilityAction(.escape) { control?.close() }
            // Exactly as tall as its content, whatever height it is offered.
            .fixedSize(horizontal: false, vertical: true)
            // At most the panel width; the toast itself is as wide as its content.
            .frame(maxWidth: toast.maxWidth)
        }

        /// The message, with its first line centered on the small buttons beside it.
        private var messageText: some View {
            Self.message(message, tokens: tokens, scale: textScale)
                .accessibilityFocused($voiceOverFocus, equals: .message)
        }

        /// The text of a message, as a toast draws it: its first line centered on a small Button.
        static func message(_ message: String, tokens: RaincoatTokenSet, scale: CGFloat) -> some View {
            let text = tokens.toast.message.resolved(scale: scale)
            let inset = max(0, (tokens.button.height.sm - text.lineHeight) / 2)
            return Text(verbatim: message)
                .font(text.font)
                .tracking(text.tracking)
                .lineSpacing(text.lineSpacing)
                // Wrap onto as many lines as it takes; never truncate.
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, text.halfLeading)
                .frame(minHeight: text.lineHeight)
                .padding(.vertical, inset)
        }

        @ViewBuilder private var actionButton: some View {
            if let action {
                RaincoatButton(Text(verbatim: action.label), variant: .ghost, size: .sm) {
                    action.perform()
                    control?.close()
                }
                .focused($keyboardFocus, equals: .action)
                .accessibilityFocused($voiceOverFocus, equals: .action)
            }
        }

        /// A small icon-only ghost Button, with a cross drawn here rather than taken from an icon
        /// set.
        @ViewBuilder private var closeButton: some View {
            if let closeLabel {
                Button {
                    control?.close()
                } label: {
                    ToastCross(size: tokens.button.iconSize.sm * textScale)
                }
                .buttonStyle(
                    RaincoatButtonStyle(
                        variant: .ghost, size: .sm, isFullWidth: false, isLoading: false, isIconOnly: true
                    )
                )
                .accessibilityLabel(Text(verbatim: closeLabel))
                .focused($keyboardFocus, equals: .close)
                .accessibilityFocused($voiceOverFocus, equals: .close)
            }
        }

        /// Follows a swipe down, and closes the toast once the swipe is as long as a touch
        /// target. A shorter one lets the toast go back.
        private var swipeDown: some Gesture {
            DragGesture()
                .onChanged { drag in swipe = max(0, drag.translation.height) }
                .onEnded { drag in
                    if drag.translation.height >= tokens.button.targetMinimum, let control {
                        control.close()
                    } else {
                        swipe = 0
                    }
                }
        }
    }

    /// The message, and the action after it while the two fit on one line. When they do not, the
    /// message takes the whole width and wraps, and the action moves below it, at the end.
    private struct MessageAndAction: Layout {
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

        /// Where the message and the action go in a given width, or in their ideal width when
        /// there is no limit.
        private func arrangement(width: CGFloat?, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
            guard let message = subviews.first else { return (.zero, []) }
            let available = width ?? .infinity
            let line = message.sizeThatFits(.unspecified)
            guard subviews.count > 1 else {
                let size =
                    line.width <= available
                    ? line : message.sizeThatFits(ProposedViewSize(width: available, height: nil))
                return (size, [CGRect(origin: .zero, size: size)])
            }
            let action = subviews[1].sizeThatFits(.unspecified)
            if line.width + spacing + action.width <= available {
                let size = CGSize(width: line.width + spacing + action.width, height: max(line.height, action.height))
                return (
                    size,
                    [
                        CGRect(origin: .zero, size: line),
                        CGRect(x: line.width + spacing, y: 0, width: action.width, height: action.height),
                    ]
                )
            }
            let wrapped = message.sizeThatFits(ProposedViewSize(width: available, height: nil))
            let width = max(available, action.width)
            return (
                CGSize(width: width, height: wrapped.height + spacing + action.height),
                [
                    CGRect(x: 0, y: 0, width: width, height: wrapped.height),
                    CGRect(
                        x: width - action.width, y: wrapped.height + spacing, width: action.width,
                        height: action.height
                    ),
                ]
            )
        }
    }

    /// The parts of a toast that VoiceOver or the keyboard can be on.
    private enum ToastPart: Hashable {
        case message
        case action
        case close
    }

    /// The cross of the close button, in the button's color, with the stroke of its spinner.
    private struct ToastCross: View {
        let size: CGFloat

        var body: some View {
            CrossShape()
                .stroke(style: StrokeStyle(lineWidth: size / 8, lineCap: .round))
                .frame(width: size, height: size)
                // The button is named by the app; the cross is decoration.
                .accessibilityHidden(true)
        }
    }

    /// Two strokes from corner to corner of the middle half of the square.
    private struct CrossShape: Shape {
        func path(in rect: CGRect) -> Path {
            let inset = rect.width / 4
            var path = Path()
            path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + inset))
            path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset))
            path.move(to: CGPoint(x: rect.maxX - inset, y: rect.minY + inset))
            path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY - inset))
            return path
        }
    }

    // MARK: - Showing toasts

    /// Shows a toast in the nearest toast host. Read it from the environment, then call it:
    ///
    ///     @Environment(\.showRaincoatToast) private var showToast
    ///     showToast(RaincoatToast("Link copied"))
    public struct ShowRaincoatToastAction: Sendable {
        let show: @MainActor @Sendable (RaincoatToast) -> Void

        /// Shows the toast now, or after the toasts already waiting.
        @MainActor
        public func callAsFunction(_ toast: RaincoatToast) {
            show(toast)
        }
    }

    extension EnvironmentValues {
        /// Shows a toast in the nearest toast host above this view: see
        /// `View.raincoatToastHost()`. Outside a toast host it does nothing.
        @Entry public var showRaincoatToast: ShowRaincoatToastAction = ShowRaincoatToastAction(show: { _ in })

        /// How a toast shown by a host tells the host it closed, or that its timer should stop.
        /// Nil for a toast drawn on its own.
        @Entry var raincoatToastControl: ToastControl? = nil
    }

    /// What a toast on the screen can ask of its host.
    struct ToastControl: Sendable {
        let close: @MainActor @Sendable () -> Void
        let setPaused: @MainActor @Sendable (ToastPause, Bool) -> Void
    }

    extension View {
        /// Puts a toast host on this view, usually a screen: toasts shown from inside it with
        /// `showRaincoatToast` appear at its bottom center, one at a time, in order.
        ///
        /// A toast sits above the on-screen keyboard and the safe area. To keep it above a bar of
        /// your own at the bottom of the screen, declare the bar with
        /// `safeAreaInset(edge: .bottom)` outside the host, or put the host inside the tab of a
        /// `TabView`. The host cannot see a bar declared inside it:
        ///
        ///     InboxView()
        ///         .raincoatToastHost()
        ///         .safeAreaInset(edge: .bottom) { ActionBar() }
        public func raincoatToastHost() -> some View {
            modifier(RaincoatToastHost())
        }
    }

    /// The toast host: the queue, the toast on the screen, and its timer.
    private struct RaincoatToastHost: ViewModifier {
        @State private var model = ToastHostModel()
        @Tokens private var tokens
        @Environment(\.scenePhase) private var scenePhase
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        func body(content: Content) -> some View {
            let model = self.model
            let toast = tokens.toast
            content
                .environment(\.showRaincoatToast, ShowRaincoatToastAction(show: { model.show($0) }))
                .overlay(alignment: .bottom) {
                    ZStack {
                        if let shown = model.queue.shown {
                            let id = shown.id
                            shown.item
                                .environment(
                                    \.raincoatToastControl,
                                    ToastControl(
                                        close: { model.close(id) },
                                        setPaused: { reason, paused in model.setPaused(reason, paused) }
                                    )
                                )
                                .id(id)
                                .transition(transition(toast))
                        }
                    }
                    .padding(toast.margin)
                }
                .onChange(of: scenePhase, initial: true) { _, phase in
                    model.setPaused(.background, phase != .active)
                }
                .onChange(of: toast.exit.duration, initial: true) { _, duration in
                    model.exitDuration = duration
                }
        }

        /// Entering, the toast slides up from as far below as its margin while it fades in, and
        /// leaving, the reverse. With Reduce Motion it only fades.
        private func transition(_ toast: RaincoatTokenSet.ToastTokens) -> AnyTransition {
            let enter = toast.enter.easing
            let exit = toast.exit.easing
            let change: AnyTransition =
                reduceMotion ? .opacity : .opacity.combined(with: .offset(y: toast.margin))
            return .asymmetric(
                insertion: change.animation(
                    .timingCurve(enter.x1, enter.y1, enter.x2, enter.y2, duration: toast.enter.duration)
                ),
                removal: change.animation(
                    .timingCurve(exit.x1, exit.y1, exit.x2, exit.y2, duration: toast.exit.duration)
                )
            )
        }
    }

    /// The state of a toast host, on the main actor: the queue, and the tasks that wait for a
    /// toast's time to be up and for a closed toast to leave the screen.
    @MainActor @Observable
    final class ToastHostModel {
        private(set) var queue = ToastQueue<RaincoatToast>(duration: toastDuration)
        /// How long a closed toast takes to leave the screen.
        @ObservationIgnored var exitDuration: Double = 0
        @ObservationIgnored private var timer: Task<Void, Never>?
        @ObservationIgnored private let now: @MainActor () -> Double
        @ObservationIgnored private let announce: @MainActor (String) -> Void

        /// - Parameters:
        ///   - now: The time, in seconds, on a clock that only moves forward.
        ///   - announce: Says a toast's message to VoiceOver.
        init(
            now: @escaping @MainActor () -> Double = { ProcessInfo.processInfo.systemUptime },
            announce: @escaping @MainActor (String) -> Void = postToastAnnouncement
        ) {
            self.now = now
            self.announce = announce
        }

        func show(_ toast: RaincoatToast) {
            let shown = queue.add(
                toast, message: toast.message, staysUntilClosed: toast.action != nil, now: now()
            )
            if let shown { announce(shown.message) }
            scheduleTimer()
        }

        func close(_ id: Int) {
            guard queue.close(id) else { return }
            leave()
        }

        func setPaused(_ reason: ToastPause, _ paused: Bool) {
            queue.setPaused(reason, paused, now: now())
            scheduleTimer()
        }

        /// A toast closed: wait until it has left the screen, then show the next one.
        private func leave() {
            scheduleTimer()
            let leaving = exitDuration
            guard leaving > 0 else { return showNext() }
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(leaving))
                self?.showNext()
            }
        }

        /// Shows the next toast, if one is waiting, now that the last one has left the screen.
        private func showNext() {
            if let shown = queue.finishLeaving(now: now()) { announce(shown.message) }
            scheduleTimer()
        }

        /// Waits until the toast on the screen is due to close, if it has a timer that runs.
        private func scheduleTimer() {
            timer?.cancel()
            timer = nil
            guard let deadline = queue.deadline else { return }
            let delay = max(0, deadline - now())
            timer = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, let self else { return }
                if queue.expire(now: now()) { leave() }
            }
        }
    }

    /// The announcement of a toast's message, with low priority: VoiceOver says it after
    /// whatever it is saying, without interrupting.
    func toastAnnouncement(_ message: String) -> AttributedString {
        var announcement = AttributedString(message)
        announcement.accessibilitySpeechAnnouncementPriority = .low
        return announcement
    }

    /// Asks VoiceOver to say a toast's message.
    @MainActor
    func postToastAnnouncement(_ message: String) {
        AccessibilityNotification.Announcement(toastAnnouncement(message)).post()
    }
#endif
