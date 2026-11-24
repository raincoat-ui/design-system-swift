#if os(iOS)
    import Foundation
    import Raincoat
    import SwiftUI
    import Testing

    extension VisualSnapshots {
        @MainActor
        @Test("Typography", arguments: allThemes, allSnapshots)
        func typography(theme: RaincoatTheme, snapshot: VisualSnapshot) throws {
            try expectSnapshot(
                of: "typography", examples: typographySnapshotExamples, theme: theme, snapshot: snapshot
            ) { instance, text in
                TypographyInstanceView(part: instance.part, text: typographyText(of: instance, text))
            }
        }
    }

    /// An instance of the Typography examples, and whether its text is decomposed.
    private struct TypographyInstance: Sendable {
        let part: TypographyExampleProperties
        let decomposed: Bool
    }

    // The long heading is drawn twice: composed (NFC), as strings.yaml has it, and decomposed
    // (NFD), as some input methods write Vietnamese. The two must look the same, and stacked
    // diacritics on its second line must not touch the first.
    private let typographySnapshotExamples: [SpecExample<TypographyInstance>] = typographyExamples.map { example in
        SpecExample(
            id: example.id,
            instances: example.instances.flatMap { part in
                example.id == "long-heading"
                    ? [TypographyInstance(part: part, decomposed: false), TypographyInstance(part: part, decomposed: true)]
                    : [TypographyInstance(part: part, decomposed: false)]
            },
            text: example.text
        )
    }

    /// The text of an instance. In person-name, the name goes where {name} marks it.
    ///
    /// The name is isolated, between U+2068 FIRST STRONG ISOLATE and U+2069 POP DIRECTIONAL
    /// ISOLATE, so that it takes its direction from its own first strong character, as the web
    /// snapshot isolates it with dir="auto". Without them, iOS draws the comma and the number after
    /// an Arabic name in English as part of the name's right-to-left run: "Message from 2 ,<name>
    /// minutes ago".
    private func typographyText(of instance: TypographyInstance, _ text: SnapshotText) -> String {
        let value = instance.decomposed ? text("text").decomposedStringWithCanonicalMapping : text("text")
        guard let open = value.firstIndex(of: "{"), let close = value[open...].firstIndex(of: "}") else {
            return value
        }
        let name = "\u{2068}" + text("name") + "\u{2069}"
        return String(value[..<open]) + name + String(value[value.index(after: close)...])
    }

    /// One Text or Heading, as an app writes it.
    private struct TypographyInstanceView: View {
        let part: TypographyExampleProperties
        let text: String

        var body: some View {
            switch part {
            case .text(let properties):
                Text(verbatim: text)
                    .raincoatText(properties.variant, color: properties.color, maxLines: properties.maxLines)
            case .heading(let properties):
                Text(verbatim: text)
                    .raincoatHeading(level: properties.level, variant: properties.variant, color: properties.color)
            }
        }
    }
#endif
