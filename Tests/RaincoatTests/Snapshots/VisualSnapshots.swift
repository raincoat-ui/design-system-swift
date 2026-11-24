#if os(iOS)
    import CoreGraphics
    import Foundation
    import Raincoat
    import SwiftUI
    import Testing
    import UIKit

    // The visual snapshots of the SwiftUI components: each snapshot of specs/snapshots.yaml, in
    // every theme. A snapshot draws every example of the component's spec together, as a
    // specimen, in the snapshot's color mode, layout direction, language, and Dynamic Type size.
    // The examples and their text in each locale are generated from the spec and its
    // strings.yaml (Generated/Snapshots.swift). See docs/adr/0019-visual-snapshots.md.
    //
    // To add a component, write Snapshots/<Component>Snapshots.swift beside this file: a test in
    // this suite that passes the generated examples to expectSnapshot, with a function that draws
    // one instance of them. ButtonSnapshots.swift is the model.
    //
    // The snapshots are drawn by iOS, in a simulator: SwiftUI on macOS does not enlarge text for
    // a larger Dynamic Type size. A specimen is shown in a window of its own and the window's
    // layers are drawn, so that the views UIKit provides, such as a text field and a scroll view,
    // are drawn too; ImageRenderer leaves them out. They run only when
    // RAINCOAT_SNAPSHOTS is set, which xcodebuild passes to the tests from
    // TEST_RUNNER_RAINCOAT_SNAPSHOTS. From packages/ios:
    //
    //     TEST_RUNNER_RAINCOAT_SNAPSHOTS=1 xcodebuild test -scheme Raincoat-Package \
    //       -destination 'platform=iOS Simulator,name=iPhone 17' \
    //       -only-testing:RaincoatTests/VisualSnapshots
    //
    // A simulator reads and writes the Mac's files, so the tests find the baselines and write
    // what they drew in this checkout, by the path of this file. In CI (CI set, through
    // TEST_RUNNER_CI) each drawing is compared with its baseline, packages/ios/__screenshots__/
    // <theme>/<component>/<snapshot>.png. A missing or different baseline fails the test, and
    // what was drawn is written to packages/ios/test-results/snapshots/actual/, with the
    // difference in .../diff/; CI uploads both. Anywhere else nothing is compared and no baseline
    // is ever written: the images go to test-results/snapshots/local/, to look at. Baselines are
    // recorded in CI only; CONTRIBUTING.md says how to accept them.

    @Suite(.enabled(if: SnapshotRun.current != nil, "RAINCOAT_SNAPSHOTS=1 draws the snapshots"))
    struct VisualSnapshots {}

    /// What a run does with the snapshots it draws.
    enum SnapshotRun: Sendable {
        /// Compares each with its baseline: in CI.
        case compare
        /// Only saves it, to look at: anywhere else.
        case draw

        static let current: SnapshotRun? = {
            let environment = ProcessInfo.processInfo.environment
            guard let value = environment["RAINCOAT_SNAPSHOTS"], !value.isEmpty, value != "0" else { return nil }
            return (environment["CI"] ?? "").isEmpty ? .draw : .compare
        }()
    }

    /// Pixels per point: one, so a specimen is 480 pixels wide, as on the web and on Android. That
    /// shows every change of layout, color, text, and direction, at a quarter of the weight of two.
    let snapshotScale: CGFloat = 1

    /// A drawn pixel matches its baseline when each of its channels is within this many steps
    /// (of 255) of the baseline's, about 3%. One pixel that does not match fails the snapshot.
    let snapshotTolerance = 8

    /// The folders and files of the snapshots.
    enum SnapshotFiles {
        /// This folder, where each component's snapshot test is.
        static let tests = URL(filePath: #filePath).deletingLastPathComponent()
        /// packages/ios
        static let swiftPackage = tests.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        static let repository = swiftPackage.deletingLastPathComponent().deletingLastPathComponent()
        static let baselines = swiftPackage.appending(path: "__screenshots__")
        static let results = swiftPackage.appending(path: "test-results/snapshots")

        /// The components whose spec names a SwiftUI implementation, by id, in order.
        static func componentsWithSwiftUIImplementations() throws -> [String] {
            let specs = repository.appending(path: "specs/components")
            return try FileManager.default.contentsOfDirectory(atPath: specs.path(percentEncoded: false))
                .sorted()
                .filter { id in
                    let spec = specs.appending(path: "\(id)/spec.yaml")
                    guard let yaml = try? String(contentsOf: spec, encoding: .utf8) else { return false }
                    return namesSwiftUIImplementation(yaml)
                }
        }

        /// Whether a spec's top-level `implementations` map has an `ios` entry. Specs are checked
        /// against their schema (`pnpm tokens:lint`), so reading the lines is enough.
        static func namesSwiftUIImplementation(_ yaml: String) -> Bool {
            var inImplementations = false
            var entryIndent: Int?
            for line in yaml.split(separator: "\n") {
                let text = line.drop { $0 == " " }
                if text.isEmpty || text.hasPrefix("#") { continue }
                let indent = line.count - text.count
                if indent == 0 {
                    inImplementations = text.hasPrefix("implementations:")
                    entryIndent = nil
                } else if inImplementations {
                    if entryIndent == nil { entryIndent = indent }
                    if indent == entryIndent, text.hasPrefix("ios:") { return true }
                }
            }
            return false
        }

        /// The names of the files in a folder, without hidden ones; none when it does not exist.
        static func contents(of folder: URL) -> [String] {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
            return names.filter { !$0.hasPrefix(".") }.sorted()
        }
    }

    /// "date-picker" → "DatePicker"
    private func pascalCase(_ id: String) -> String {
        id.split(separator: "-").map { String($0.prefix(1)).uppercased() + String($0.dropFirst()) }.joined()
    }

    /// "date-picker" → "datePicker"
    private func camelCase(_ id: String) -> String {
        let name = pascalCase(id)
        return String(name.prefix(1)).lowercased() + String(name.dropFirst())
    }

    /// Draws the examples of a component in one theme and snapshot, and, in CI, compares the
    /// drawing with its baseline.
    ///
    /// - Parameters:
    ///   - component: The id of the component's spec, which names its baselines.
    ///   - examples: The examples generated from the spec, such as `buttonExamples`.
    ///   - draw: Draws one instance of the examples, given its properties and the text of its
    ///     content in the snapshot's locale: `text("label")`, or `text.optional("error")` for
    ///     content that only some examples have.
    @MainActor
    func expectSnapshot<Properties: Sendable, Instance: View>(
        of component: String,
        examples: [SpecExample<Properties>],
        theme: RaincoatTheme,
        snapshot: VisualSnapshot,
        draw: @escaping (_ instance: Properties, _ text: SnapshotText) -> Instance
    ) throws {
        let reading = TextScaleProbe.Reading()
        var windowCategory = UIContentSizeCategory.unspecified
        let drawing = try Bitmap(
            drawSpecimen(
                Specimen(examples: examples, locale: snapshot.locale, draw: draw),
                theme: theme, snapshot: snapshot, reading: reading
            ) { windowCategory = $0 }
        )

        // The window was drawn: its top left corner is the specimen's canvas.
        let canvas = theme.tokens(mode: snapshot.mode, density: .comfortable).color.bg.canvas
        let corner = [canvas.red, canvas.green, canvas.blue].map { Int(($0 * 255).rounded()) }
        #expect(
            zip(drawing.pixel(1, 1).prefix(3), corner).allSatisfy { abs($0 - $1) <= snapshotTolerance },
            "the specimen's canvas was not drawn"
        )

        // The snapshot's text size is in effect: SwiftUI and the window are given it, and body
        // text grows as much as the system's body text there, within 1%: at the largest size,
        // 3.12 times as large (53 points instead of 17).
        let scale = try #require(reading.scale, "the text size was not read")
        let size = snapshot.textSize.dynamicTypeSize
        let category = contentSizeCategory(size)
        #expect(
            reading.dynamicTypeSize == size,
            "SwiftUI's text size is \(reading.dynamicTypeSize.map { "\($0)" } ?? "unknown"), not \(size)"
        )
        #expect(windowCategory == category, "the window's text size is \(windowCategory.rawValue), not \(category.rawValue)")
        let expected = bodyTextScale(at: category)
        #expect(
            abs(scale / expected - 1) < 0.01,
            "body text is drawn \(scale) times as large, where the system's is \(expected) times as large at \(category.rawValue)"
        )
        if size != .large {
            print(
                """
                \(theme.id)/\(component)/\(snapshot.id): body text is drawn \(scale) times as large; \
                the system draws it \(expected) times as large at \(category.rawValue).
                """
            )
        }

        let name = "\(theme.id)/\(component)/\(snapshot.id).png"
        switch SnapshotRun.current {
        case .compare?:
            guard let baseline = try Bitmap.read(SnapshotFiles.baselines.appending(path: name)) else {
                try drawing.write(to: SnapshotFiles.results.appending(path: "actual/\(name)"))
                Issue.record(
                    "\(name) has no baseline. CI uploaded what it drew as the ios-snapshots artifact; CONTRIBUTING.md says how to accept it."
                )
                return
            }
            let differences = drawing.differences(from: baseline, tolerance: snapshotTolerance)
            if differences.count > 0 {
                try drawing.write(to: SnapshotFiles.results.appending(path: "actual/\(name)"))
                try differences.image.write(to: SnapshotFiles.results.appending(path: "diff/\(name)"))
                Issue.record(
                    """
                    \(name) differs from its baseline in \(differences.count) pixels \
                    (\(drawing.width)×\(drawing.height) drawn, \(baseline.width)×\(baseline.height) \
                    in the baseline). CI uploaded what it drew, and the difference in red, as the \
                    ios-snapshots artifact; CONTRIBUTING.md says how to accept it.
                    """
                )
            }
        case .draw?, nil:
            try drawing.write(to: SnapshotFiles.results.appending(path: "local/\(name)"))
        }
    }

    /// An instance of an example that knows which example it belongs to, for a component whose
    /// examples differ in what they show rather than in their properties.
    struct ExampleInstance<Properties: Sendable>: Sendable {
        let example: String
        let properties: Properties
    }

    /// The examples, with each instance told which example it belongs to.
    func withExampleIDs<Properties: Sendable>(
        _ examples: [SpecExample<Properties>]
    ) -> [SpecExample<ExampleInstance<Properties>>] {
        examples.map { example in
            SpecExample(
                id: example.id,
                instances: example.instances.map { ExampleInstance(example: example.id, properties: $0) },
                text: example.text
            )
        }
    }

    /// The text of an example in the snapshot's locale, by the content it fills.
    struct SnapshotText: Sendable {
        let example: String
        let locale: String
        let values: [String: String]

        /// The text of content the example has: `text("label")`. Text that is missing fails the
        /// snapshot.
        func callAsFunction(_ content: String) -> String {
            guard let value = values[content] else {
                Issue.record("\(example): no \(content) in \(locale)")
                return ""
            }
            return value
        }

        /// The text of content that only some examples have, such as an error, or nil.
        func optional(_ content: String) -> String? {
            values[content]
        }
    }

    /// Draws a specimen as the snapshot asks, in a theme: shown in a window of its own, with the
    /// snapshot's appearance set as the system sets it, UIKit's views included.
    @MainActor
    ///
    /// - Parameter shown: Given the text size of the window's traits, while it is shown.
    private func drawSpecimen(
        _ specimen: some View, theme: RaincoatTheme, snapshot: VisualSnapshot, reading: TextScaleProbe.Reading,
        shown: (UIContentSizeCategory) -> Void
    ) throws -> CGImage {
        // SwiftUI lets a test set the color scheme but not the contrast setting, so a theme that
        // answers every request with the tokens of the snapshot's color mode draws it, as in
        // ButtonRenderingTests. The window's traits say the same, for UIKit's views.
        let mode = snapshot.mode
        let isDark = mode == .dark || mode == .darkHighContrast
        let isHighContrast = mode == .lightHighContrast || mode == .darkHighContrast
        let fixed = RaincoatTheme(id: "\(theme.id)-\(mode.rawValue)") { _, density in
            theme.tokens(mode: mode, density: density)
        }
        let canvas = theme.tokens(mode: mode, density: .comfortable).color.bg.canvas
        let scheme: ColorScheme = isDark ? .dark : .light
        let root =
            specimen
            .background { TextScaleProbe(reading: reading) }
            .raincoatTheme(fixed)
            .environment(\.colorScheme, scheme)
            .environment(\.layoutDirection, snapshot.layoutDirection)
            .environment(\.locale, Locale(identifier: snapshot.locale))
            // Text is set as on a device whose language is the snapshot's, so that line
            // height, line breaks, and spacing follow its script.
            .typesettingLanguage(Locale.Language(identifier: snapshot.locale))
            .dynamicTypeSize(snapshot.textSize.dynamicTypeSize)
            // A snapshot shows views at rest: nothing animates, so a spinner is drawn where it
            // starts, in every run.
            .transaction { transaction in
                transaction.disablesAnimations = true
                transaction.animation = nil
            }

        let controller = UIHostingController(rootView: root)
        controller.overrideUserInterfaceStyle = isDark ? .dark : .light
        controller.traitOverrides.accessibilityContrast = isHighContrast ? .high : .normal
        controller.traitOverrides.preferredContentSizeCategory = contentSizeCategory(
            snapshot.textSize.dynamicTypeSize
        )
        controller.traitOverrides.layoutDirection = snapshot.rightToLeft ? .rightToLeft : .leftToRight
        controller.view.semanticContentAttribute = snapshot.rightToLeft ? .forceRightToLeft : .forceLeftToRight
        controller.view.backgroundColor = UIColor(
            red: canvas.red, green: canvas.green, blue: canvas.blue, alpha: canvas.alpha
        )
        return try drawInWindow(controller) { shown($0.view.traitCollection.preferredContentSizeCategory) }
    }

    /// Shows a hosting controller's view in a window of its own, `specimenWidth` wide and as tall
    /// as the view, and draws the window's layers at `snapshotScale`.
    ///
    /// Each view is a Core Animation layer, those UIKit provides included, so the layers draw a
    /// text field's text and a scroll view's content where it is scrolled to. ImageRenderer draws
    /// only what SwiftUI draws itself. `drawHierarchy(in:afterScreenUpdates:)`, which draws a
    /// window as the screen shows it, draws nothing here: a package's tests have no window scene
    /// to show a window in. Drawing the layers leaves out Core Animation's filters, such as the
    /// blur of a material: a view that uses one would be drawn without it.
    @MainActor
    ///
    /// - Parameter shown: Given the controller while its view is shown, before it is drawn.
    func drawInWindow<Content: View>(
        _ controller: UIHostingController<Content>,
        shown: (UIHostingController<Content>) -> Void = { _ in }
    ) throws -> CGImage {
        // UIKit's views do not animate either.
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(true) }
        controller.safeAreaRegions = []
        // The view is laid out on the pixels of the drawing.
        controller.traitOverrides.displayScale = snapshotScale

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: specimenWidth, height: specimenWidth))
        window.rootViewController = controller
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        let size = controller.sizeThatFits(in: CGSize(width: specimenWidth, height: .greatestFiniteMagnitude))
        let height = (size.height * snapshotScale).rounded(.up) / snapshotScale
        window.frame = CGRect(x: 0, y: 0, width: specimenWidth, height: height)
        // Let the window finish what views do as they appear, such as scrolling a selected tab
        // into view.
        for _ in 0..<3 {
            window.layoutIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        window.layoutIfNeeded()
        // Every layer has drawn its content before the layers are drawn.
        CATransaction.flush()
        shown(controller)

        let format = UIGraphicsImageRendererFormat()
        format.scale = snapshotScale
        format.opaque = true
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
        return try #require(image.cgImage, "the window could not be drawn")
    }

    /// How many times as large the system draws body text at a text size as at the default size.
    @MainActor
    private func bodyTextScale(at category: UIContentSizeCategory) -> CGFloat {
        textScale(of: .body, at: category)
    }

    /// How many times as large the system draws a text style at a text size as at the default.
    @MainActor
    private func textScale(of textStyle: UIFont.TextStyle, at category: UIContentSizeCategory) -> CGFloat {
        let size = { (category: UIContentSizeCategory) in
            UIFont.preferredFont(
                forTextStyle: textStyle, compatibleWith: UITraitCollection(preferredContentSizeCategory: category)
            ).pointSize
        }
        return size(category) / size(.large)
    }

    /// The system text styles the components' text follows, in SwiftUI and in UIKit.
    enum FollowedTextStyle: String, CaseIterable, Sendable {
        case largeTitle, title2, title3, headline, body, caption

        var swiftUI: Font.TextStyle {
            switch self {
            case .largeTitle: .largeTitle
            case .title2: .title2
            case .title3: .title3
            case .headline: .headline
            case .body: .body
            case .caption: .caption
            }
        }

        var uiKit: UIFont.TextStyle {
            switch self {
            case .largeTitle: .largeTitle
            case .title2: .title2
            case .title3: .title3
            case .headline: .headline
            case .body: .body
            case .caption: .caption1
            }
        }
    }

    /// The UIKit text size of a Dynamic Type size.
    private func contentSizeCategory(_ size: DynamicTypeSize) -> UIContentSizeCategory {
        switch size {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        case .xxxLarge: return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .large
        }
    }

    extension VisualSnapshots {
        /// At every Dynamic Type size, the components' text grows as much as the system's body
        /// text, within 1%: at the largest, 3.12 times as large (53 points instead of 17), not
        /// the rounded 3 that a scaled metric of 1 gives. It runs here because only iOS scales
        /// text by the Dynamic Type size.
        @MainActor
        @Test(arguments: DynamicTypeSize.allCases)
        func bodyTextGrowsAsTheSystemsDoes(size: DynamicTypeSize) throws {
            let reading = TextScaleProbe.Reading()
            let category = contentSizeCategory(size)
            let controller = UIHostingController(
                rootView: TextScaleProbe(reading: reading)
                    .frame(width: 10, height: 10)
                    .dynamicTypeSize(size)
            )
            controller.traitOverrides.preferredContentSizeCategory = category
            _ = try drawInWindow(controller)
            let scale = try #require(reading.scale, "the text size was not read")
            let expected = bodyTextScale(at: category)
            #expect(abs(scale / expected - 1) < 0.01, "\(size): \(scale) times as large, where the system's is \(expected)")
        }

        /// Each system text style the components follow grows as the system grows it, within 1%,
        /// at every Dynamic Type size: headings follow the title styles, captions the caption.
        @MainActor
        @Test(arguments: FollowedTextStyle.allCases, DynamicTypeSize.allCases)
        func eachTextStyleGrowsAsTheSystemsDoes(style: FollowedTextStyle, size: DynamicTypeSize) throws {
            let reading = TextScaleProbe.Reading()
            let category = contentSizeCategory(size)
            let controller = UIHostingController(
                rootView: TextScaleProbe(reading: reading, textStyle: style.swiftUI)
                    .frame(width: 10, height: 10)
                    .dynamicTypeSize(size)
            )
            controller.traitOverrides.preferredContentSizeCategory = category
            _ = try drawInWindow(controller)
            let scale = try #require(reading.scale, "the text size was not read")
            let expected = textScale(of: style.uiKit, at: category)
            #expect(
                abs(scale / expected - 1) < 0.01,
                "\(style) at \(size): \(scale) times as large, where the system's is \(expected)"
            )
        }

        /// The window draws the text of a text field, which UIKit provides: an Input shows one.
        @MainActor
        @Test func theWindowDrawsATextFieldsText() throws {
            let drawing = try Bitmap(drawInWindow(UIHostingController(rootView: TextFieldCheck())))
            // White, but for the field's text, which is black: hundreds of pixels at any scale.
            let ink = stride(from: 0, to: drawing.pixels.count, by: 4).filter { drawing.pixels[$0] < 128 }
            #expect(CGFloat(ink.count) > 100 * snapshotScale * snapshotScale, "the text field's text was not drawn")
        }

        /// The window draws a scroll view's content where it is scrolled to as it appears, which
        /// UIKit provides: a row of tabs that does not fit scrolls the selected tab into view.
        @MainActor
        @Test func theWindowDrawsAScrollViewWhereItIsScrolledTo() throws {
            let drawing = try Bitmap(drawInWindow(UIHostingController(rootView: ScrollCheck())))
            let middle = drawing.height / 2
            // Blue, the end of the row, from one edge to the other; red where it is not scrolled.
            for x in [2, drawing.width / 2, drawing.width - 3] {
                let pixel = drawing.pixel(x, middle)
                #expect(pixel[0] < 16 && pixel[1] < 16 && pixel[2] > 239, "at \(x): \(pixel)")
            }
        }

        /// Each component whose spec names a SwiftUI implementation has a snapshot test,
        /// Snapshots/<Component>Snapshots.swift, which draws the examples generated from its spec.
        @Test func everyComponentWithASwiftUIImplementationHasSnapshots() throws {
            let components = try SnapshotFiles.componentsWithSwiftUIImplementations()
            #expect(components.contains("button"), "the specs were not found")
            for component in components {
                let file = "\(pascalCase(component))Snapshots.swift"
                guard
                    let source = try? String(contentsOf: SnapshotFiles.tests.appending(path: file), encoding: .utf8)
                else {
                    Issue.record(
                        "specs/components/\(component) has no snapshot test: add Tests/RaincoatTests/Snapshots/\(file)"
                    )
                    continue
                }
                #expect(
                    source.contains("\(camelCase(component))Examples"),
                    "Snapshots/\(file) does not draw \(camelCase(component))Examples"
                )
            }
        }

        /// Every baseline belongs to a theme, a component, and a snapshot that are still drawn.
        /// A baseline that is missing fails the snapshot itself.
        @Test func everyBaselineBelongsToASnapshot() throws {
            let themes = Set(allThemes.map(\.id))
            let components = try Set(SnapshotFiles.componentsWithSwiftUIImplementations())
            let snapshots = Set(allSnapshots.map { "\($0.id).png" })
            let baselines = SnapshotFiles.baselines
            for theme in SnapshotFiles.contents(of: baselines) {
                guard themes.contains(theme) else {
                    Issue.record("\(theme)/ holds the baselines of no theme; delete it")
                    continue
                }
                for component in SnapshotFiles.contents(of: baselines.appending(path: theme)) {
                    for file in SnapshotFiles.contents(of: baselines.appending(path: "\(theme)/\(component)"))
                    where !components.contains(component) || !snapshots.contains(file) {
                        Issue.record("\(theme)/\(component)/\(file) is the baseline of no snapshot; delete it")
                    }
                }
            }
        }
    }
#endif
