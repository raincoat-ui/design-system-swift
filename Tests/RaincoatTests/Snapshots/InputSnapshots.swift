#if os(iOS)
    import Raincoat
    import SwiftUI
    import Testing

    // Each field shows the content its example has: a value, a description, a prompt (the web's
    // placeholder), and an error. iOS has no required state, so required is not drawn.

    extension VisualSnapshots {
        @MainActor
        @Test("Input", arguments: allThemes, allSnapshots)
        func input(theme: RaincoatTheme, snapshot: VisualSnapshot) throws {
            try expectSnapshot(of: "input", examples: inputExamples, theme: theme, snapshot: snapshot) { input, text in
                RaincoatInput(
                    text("label"),
                    text: .constant(text.optional("value") ?? ""),
                    type: input.type,
                    size: input.size,
                    description: text.optional("description").map { Text(verbatim: $0) },
                    prompt: text.optional("placeholder").map { Text(verbatim: $0) },
                    isInvalid: input.invalid,
                    error: text.optional("error").map { Text(verbatim: $0) },
                    isMultiline: input.multiline,
                    isReadOnly: input.readOnly
                )
                .disabled(input.disabled)
            }
        }
    }
#endif
