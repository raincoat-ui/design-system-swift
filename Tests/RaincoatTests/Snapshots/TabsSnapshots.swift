#if os(iOS)
    import Raincoat
    import SwiftUI
    import Testing

    // An example of the Tabs is a row of tabs: its text gives one line per tab. Each instance is
    // told which example it draws, because the examples differ in their content, not their
    // properties. The row is the real scrolling row: a row that does not fit selects its last
    // tab, which it scrolls into view as it appears, as on the web.

    extension VisualSnapshots {
        @MainActor
        @Test("Tabs", arguments: allThemes, allSnapshots)
        func tabs(theme: RaincoatTheme, snapshot: VisualSnapshot) throws {
            try expectSnapshot(
                of: "tabs", examples: withExampleIDs(tabsExamples), theme: theme, snapshot: snapshot
            ) { instance, text in
                TabsInstanceView(
                    example: instance.example,
                    lines: text(instance.example == "icon-only" ? "accessible-name" : "label")
                        .split(separator: "\n").map(String.init),
                    panel: text.optional("panel")
                )
            }
        }
    }

    /// A row of tabs, with the panel of the first tab in the example that has one. The icons are
    /// the system's, as the reference app uses.
    private struct TabsInstanceView: View {
        let example: String
        let lines: [String]
        let panel: String?

        private static let icons = ["photo", "video", "doc"]
        private static let iconsOnly = ["list.bullet", "square.grid.2x2"]

        var body: some View {
            let selected = example == "overflow" ? lines.count - 1 : 0
            RaincoatTabs(tabs: tabs, initialSelection: selected) { _ in
                if let panel {
                    Text(verbatim: panel)
                        .raincoatText()
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }

        private var tabs: [RaincoatTab<Int>] {
            lines.indices.map { (index: Int) -> RaincoatTab<Int> in
                let line = lines[index]
                if example == "icon-only" {
                    let icon = Image(systemName: Self.iconsOnly[index % Self.iconsOnly.count])
                    return RaincoatTab(icon: icon, accessibilityLabel: Text(verbatim: line), value: index)
                }
                if example == "icons" {
                    let icon = Image(systemName: Self.icons[index % Self.icons.count])
                    return RaincoatTab(line, value: index, icon: icon)
                }
                return RaincoatTab(line, value: index)
            }
        }
    }
#endif
