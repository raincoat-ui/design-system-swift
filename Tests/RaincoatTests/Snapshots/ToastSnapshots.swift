#if os(iOS)
    import Raincoat
    import SwiftUI
    import Testing

    // The toast itself, standing still, as a toast host shows it: without the host's timer,
    // position, or motion. Drawn on its own, a toast is not announced and does not close.

    extension VisualSnapshots {
        @MainActor
        @Test("Toast", arguments: allThemes, allSnapshots)
        func toast(theme: RaincoatTheme, snapshot: VisualSnapshot) throws {
            try expectSnapshot(of: "toast", examples: toastExamples, theme: theme, snapshot: snapshot) { toast, text in
                toast.action
                    ? RaincoatToast(
                        text("message"),
                        action: RaincoatToast.Action(text("action-label"), perform: {}),
                        closeLabel: text("close-label")
                    )
                    : RaincoatToast(text("message"))
            }
        }
    }
#endif
