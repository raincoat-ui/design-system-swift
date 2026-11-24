#if os(iOS)
    import Raincoat
    import SwiftUI
    import Testing

    extension VisualSnapshots {
        @MainActor
        @Test("Button", arguments: allThemes, allSnapshots)
        func button(theme: RaincoatTheme, snapshot: VisualSnapshot) throws {
            try expectSnapshot(of: "button", examples: buttonExamples, theme: theme, snapshot: snapshot) { button, text in
                RaincoatButton(
                    text("label"),
                    variant: button.variant,
                    size: button.size,
                    isFullWidth: button.fullWidth,
                    isLoading: button.loading
                ) {}
                .disabled(button.disabled)
            }
        }
    }
#endif
