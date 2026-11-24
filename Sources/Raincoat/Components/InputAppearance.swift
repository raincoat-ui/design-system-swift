import RaincoatTokens

// What an Input looks like for a size and a state, taken from the Input tokens. This file uses
// no SwiftUI, so its tests also run on Linux.

/// The colors of a field.
struct InputColors: Hashable, Sendable {
    /// Fill of the field.
    let fill: TokenColor
    /// Outline of the field.
    let border: TokenColor
    /// Color of the value and the leading icon.
    let foreground: TokenColor
    /// Color of the prompt, an example of the format shown while the field is empty.
    let placeholder: TokenColor

    /// Disabled wins over everything else. A read-only field has its own fill, and its hairline
    /// outline unless it is invalid: an invalid field always has the danger outline.
    init(_ tokens: RaincoatTokenSet.InputTokens, isEnabled: Bool, isInvalid: Bool, isReadOnly: Bool) {
        if !isEnabled {
            fill = tokens.bg.disabled
            border = tokens.border.disabled
            foreground = tokens.fg.disabled
            placeholder = tokens.fg.disabled
            return
        }
        fill = isReadOnly ? tokens.bg.readOnly : tokens.bg.default
        border =
            isInvalid ? tokens.border.invalid : isReadOnly ? tokens.border.readOnly : tokens.border.default
        foreground = tokens.fg.default
        placeholder = tokens.placeholder
    }
}

/// The measurements of a field of one size.
struct InputMeasurements: Hashable, Sendable {
    /// Height of the field when its value is one line.
    let height: Double
    let paddingInline: Double
    let iconSize: Double
    let label: TokenTextStyle
    let value: TokenTextStyle

    init(_ tokens: RaincoatTokenSet.InputTokens, size: InputSize) {
        // The switch is exhaustive on purpose: a size added to the spec does not compile until
        // it is given measurements here.
        switch size {
        case .sm:
            height = tokens.height.sm
            paddingInline = tokens.paddingInline.sm
            iconSize = tokens.iconSize.sm
            label = tokens.label.sm
            value = tokens.value.sm
        case .md:
            height = tokens.height.md
            paddingInline = tokens.paddingInline.md
            iconSize = tokens.iconSize.md
            label = tokens.label.md
            value = tokens.value.md
        case .lg:
            height = tokens.height.lg
            paddingInline = tokens.paddingInline.lg
            iconSize = tokens.iconSize.lg
            label = tokens.label.lg
            value = tokens.value.lg
        }
    }

    /// Space above and below the value that centers one line in `height`. It stays the same
    /// when the text is enlarged or a multi-line field grows, so the field grows instead.
    var paddingBlock: Double {
        max(0, (height - value.lineHeight * value.size) / 2)
    }
}

/// What the keyboard and autofill offer for each type. Plain values, so that the mapping is
/// tested on Linux too; the view turns them into the platform's types.
struct InputKeyboard: Hashable, Sendable {
    enum Keys: Hashable, Sendable { case standard, email, phone, url, search }
    enum Content: Hashable, Sendable { case unspecified, email, password, phone, url }

    let keys: Keys
    let content: Content
    /// Whether what is typed is hidden, as in a password field.
    let isSecure: Bool
    /// Whether the system may capitalize and correct what is typed.
    let corrects: Bool
    /// Whether the value is left-to-right whatever the language, as an address or a number is.
    let isLeftToRight: Bool

    private init(_ keys: Keys, _ content: Content, isSecure: Bool, corrects: Bool, isLeftToRight: Bool) {
        self.keys = keys
        self.content = content
        self.isSecure = isSecure
        self.corrects = corrects
        self.isLeftToRight = isLeftToRight
    }

    init(_ type: InputType) {
        switch type {
        case .text:
            self.init(.standard, .unspecified, isSecure: false, corrects: true, isLeftToRight: false)
        case .email:
            self.init(.email, .email, isSecure: false, corrects: false, isLeftToRight: true)
        case .password:
            self.init(.standard, .password, isSecure: true, corrects: false, isLeftToRight: false)
        case .search:
            self.init(.search, .unspecified, isSecure: false, corrects: true, isLeftToRight: false)
        case .tel:
            self.init(.phone, .phone, isSecure: false, corrects: false, isLeftToRight: true)
        case .url:
            self.init(.url, .url, isSecure: false, corrects: false, isLeftToRight: true)
        }
    }
}
