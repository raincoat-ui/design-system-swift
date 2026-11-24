// The order of the toasts and the timer of the one on the screen, for the toast host. This file
// uses no SwiftUI, so its tests also run on Linux. Times are in seconds, read from any clock that
// only moves forward; the host reads the system's, and the tests bring a clock of their own.

/// How long a toast without an action stays, in seconds, while nothing pauses it (RFC 0008).
let toastDuration: Double = 6

/// Why the timer of the toast on the screen is stopped.
enum ToastPause: Hashable, CaseIterable, Sendable {
    /// A pointer is over the toast.
    case hover
    /// Focus is in the toast: VoiceOver's, or the keyboard's.
    case focus
    /// The app is in the background.
    case background
}

/// The toasts of one host: the one on the screen, and those waiting after it, in order.
///
/// One toast is shown at a time. A toast without an action closes when its time is up; the time
/// stops while any pause holds, and goes on from where it stopped. A toast with an action stays
/// until it is closed. When a toast closes, the next one waits until it has left the screen.
struct ToastQueue<Item> {
    struct Entry {
        let id: Int
        let item: Item
        /// What the toast says, for the announcement.
        let message: String
        /// Whether the toast stays until it is closed, as a toast with an action does.
        let staysUntilClosed: Bool
    }

    /// How long a toast without an action stays, while nothing pauses it.
    let duration: Double
    /// The toast on the screen.
    private(set) var shown: Entry?
    /// The toasts after it, in the order they were added.
    private(set) var waiting: [Entry] = []
    /// Whether a toast that closed is still leaving the screen.
    private(set) var isLeaving = false
    /// What stops the timer now.
    private(set) var pauses: Set<ToastPause> = []

    /// The time the shown toast has left, as of `runningSince`, or as of the pause.
    private var remaining: Double = 0
    /// When the timer last started, or nil while it is stopped.
    private var runningSince: Double?
    private var lastID = 0

    init(duration: Double) {
        self.duration = duration
    }

    /// When the toast on the screen closes, or nil while it has no timer or the timer is stopped.
    var deadline: Double? {
        guard let shown, !shown.staysUntilClosed, let runningSince else { return nil }
        return runningSince + remaining
    }

    /// Adds a toast after those already waiting.
    ///
    /// - Returns: The toast, if it is shown at once, so that the host can announce it.
    @discardableResult
    mutating func add(_ item: Item, message: String, staysUntilClosed: Bool, now: Double) -> Entry? {
        lastID += 1
        waiting.append(Entry(id: lastID, item: item, message: message, staysUntilClosed: staysUntilClosed))
        guard shown == nil, !isLeaving else { return nil }
        return showNext(now: now)
    }

    /// Closes the toast on the screen, if it is the one with this id.
    ///
    /// - Returns: Whether it closed.
    @discardableResult
    mutating func close(_ id: Int) -> Bool {
        guard shown?.id == id else { return false }
        shown = nil
        runningSince = nil
        isLeaving = true
        return true
    }

    /// Closes the toast on the screen if its time is up.
    ///
    /// - Returns: Whether it closed.
    @discardableResult
    mutating func expire(now: Double) -> Bool {
        guard let deadline, now >= deadline, let shown else { return false }
        return close(shown.id)
    }

    /// The toast that closed has left the screen. The next one, if any, is shown now.
    ///
    /// - Returns: The toast shown now, so that the host can announce it.
    @discardableResult
    mutating func finishLeaving(now: Double) -> Entry? {
        isLeaving = false
        guard shown == nil, !waiting.isEmpty else { return nil }
        return showNext(now: now)
    }

    /// Starts or stops one reason for the timer to stop.
    mutating func setPaused(_ reason: ToastPause, _ paused: Bool, now: Double) {
        if paused {
            guard !pauses.contains(reason) else { return }
            if let runningSince {
                remaining -= now - runningSince
                self.runningSince = nil
            }
            pauses.insert(reason)
        } else {
            guard pauses.remove(reason) != nil else { return }
            if pauses.isEmpty, shown != nil {
                runningSince = now
            }
        }
    }

    private mutating func showNext(now: Double) -> Entry? {
        guard !waiting.isEmpty else { return nil }
        let next = waiting.removeFirst()
        shown = next
        remaining = duration
        // A pointer or focus was on the toast that left. The app's being in the background
        // still holds.
        pauses.remove(.hover)
        pauses.remove(.focus)
        runningSince = pauses.isEmpty ? now : nil
        return next
    }
}
