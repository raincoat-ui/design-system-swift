#if os(iOS)
    @testable import Raincoat
    import SwiftUI
    import Testing

    // A dialog and a sheet are drawn as they are laid out inside the system sheet that presents
    // them, on their fill (DialogPanel): the sheet itself, its corners, and the dimming behind it
    // are the system's. On iOS a sheet comes from the bottom whatever its edge, so the sheet's two
    // instances look the same.
    //
    // The alert dialog is left out. On iOS it is the system alert, which the platform draws, not
    // Raincoat, and the theme does not reach it.

    extension VisualSnapshots {
        @MainActor
        @Test("Dialog", arguments: allThemes, allSnapshots)
        func dialog(theme: RaincoatTheme, snapshot: VisualSnapshot) throws {
            try expectSnapshot(
                of: "dialog", examples: dialogSnapshotExamples, theme: theme, snapshot: snapshot
            ) { _, text in
                DialogInstanceView(text: text)
            }
        }
    }

    /// The examples of the Dialog spec without the alert dialog's instances.
    private let dialogSnapshotExamples: [SpecExample<DialogPartExampleProperties>] = dialogExamples.compactMap {
        (example: SpecExample<DialogPartExampleProperties>) -> SpecExample<DialogPartExampleProperties>? in
        let instances = example.instances.filter { (instance: DialogPartExampleProperties) -> Bool in
            if case .alertDialog = instance { return false }
            return true
        }
        return instances.isEmpty ? nil : SpecExample(id: example.id, instances: instances, text: example.text)
    }

    /// One dialog or sheet, with what its example has: a description, a close button, a body, and
    /// a footer with Cancel, where the example has it, and the primary action.
    private struct DialogInstanceView: View {
        let text: SnapshotText

        var body: some View {
            let heading = DialogHeading(
                title: Text(verbatim: text("title")),
                level: 2,
                description: text.optional("description").map { Text(verbatim: $0) },
                closeLabel: text.optional("close-label").map { Text(verbatim: $0) }
            )
            if let bodyText = text.optional("body") {
                if let action = text.optional("action-label") {
                    DialogPanel(heading: heading, content: Text(verbatim: bodyText), actions: actions(action))
                } else {
                    DialogPanel(heading: heading, content: Text(verbatim: bodyText), actions: EmptyView())
                }
            } else if let action = text.optional("action-label") {
                DialogPanel(heading: heading, content: EmptyView(), actions: actions(action))
            } else {
                DialogPanel(heading: heading, content: EmptyView(), actions: EmptyView())
            }
        }

        /// The footer's buttons: Cancel first, where the example has it, and the primary action.
        private func actions(_ action: String) -> some View {
            Group {
                if let cancel = text.optional("cancel-label") {
                    RaincoatButton(cancel) {}
                }
                RaincoatButton(action, variant: .primary) {}
            }
        }
    }
#endif
