# Raincoat for SwiftUI

Raincoat components for iOS 17 and later, written in SwiftUI. Every color, size, and text style
they use comes from a Raincoat theme.

Prereleases are tagged in `https://github.com/raincoat-ui/design-system-swift`. The
[releases page](https://github.com/raincoat-ui/design-system/releases) says which registries each
version has reached.

## Products

| Product             | Contains                                                  |
| ------------------- | --------------------------------------------------------- |
| `Raincoat`          | The components and the SwiftUI environment                |
| `RaincoatTheme<Id>` | One per theme, such as `RaincoatThemeBase`                |
| `RaincoatTokens`    | The token types. Foundation only; it also builds on Linux |

## Use

Each theme is a product of its own, so an app links only its own. The
[themes page](https://raincoat-ui.github.io/design-system/foundations/themes/) lists them. Apply
the theme once, near the root of the app:

```swift
import Raincoat
import RaincoatThemeBase

ContentView().raincoatTheme(.base)
```

Components follow the system's light or dark appearance and its Increase Contrast setting. Use
`raincoatDensity(.compact)` for smaller controls.

## Button

```swift
RaincoatButton("Save changes", variant: .primary) { save() }
RaincoatButton("Save changes", isLoading: isSaving) { save() }
RaincoatButton("Next", trailingIcon: Image(systemName: "arrow.right")) { next() }
RaincoatButton(icon: Image(systemName: "trash"), accessibilityLabel: Text("Delete page"), variant: .danger) {
    delete()
}
RaincoatButton("Save changes") { save() }.disabled(!canSave)
```

| Parameter      | Type            | Default      | Notes                                                                        |
| -------------- | --------------- | ------------ | ---------------------------------------------------------------------------- |
| `variant`      | `ButtonVariant` | `.secondary` | `.primary`, `.secondary`, `.ghost`, `.danger`. At most one primary in a view |
| `size`         | `ButtonSize`    | `.md`        | `.sm`, `.md`, `.lg`                                                          |
| `leadingIcon`  | `Image?`        | `nil`        | Decoration; hidden from assistive technology                                 |
| `trailingIcon` | `Image?`        | `nil`        |                                                                              |
| `isFullWidth`  | `Bool`          | `false`      | Stretches to the container                                                   |
| `isLoading`    | `Bool`          | `false`      | Shows a spinner, keeps the label and focus, ignores activation               |

- The title is a `LocalizedStringKey`, a `String`, or a `Text`.
- Long labels wrap. The button grows taller; the label is never truncated.
- The button takes the room it shows. The area that takes touches is at least 44 points across,
  so around a small button it reaches past the edges. Leave 8 points or more between small
  buttons.
- The label and icons grow with the person's text size setting.
- In right-to-left layouts the leading icon is on the right.
- A loading button tells assistive technology that it is in progress, after its name: "Save
  changes, In progress".

### Languages

The words a component says to assistive technology are translated into English, Vietnamese,
Simplified Chinese, Traditional Chinese, Japanese, and Korean; other languages get English.
iOS uses a package's translation only for a language your app supports. If your app is in fewer
languages than its users, set `CFBundleAllowMixedLocalizations` to `YES` in its `Info.plist`.
Everything a person reads on screen comes from your app.

To give another control the same look, use the style:

```swift
Link("Read the guide", destination: url).buttonStyle(.raincoat(variant: .ghost))
```

The Button follows the
[Button spec](https://github.com/raincoat-ui/design-system/blob/main/specs/components/button/spec.yaml),
which the React and Compose Buttons follow too.

## Toast

Put a toast host on a screen once, then show toasts from anywhere inside it:

```swift
InboxView().raincoatToastHost()

@Environment(\.showRaincoatToast) private var showToast

showToast(RaincoatToast("Message archived"))
showToast(RaincoatToast("Message archived", action: .init("Undo") { undo() }, closeLabel: "Close"))
```

- The message, the action's label, and the close button's name are `String`s in your app's
  language. A toast with an action must have a named close button.
- One toast is shown at a time, at the bottom center of the host; others wait, in order.
- A toast never takes focus. VoiceOver says its message after whatever it is saying.
- Without an action, a toast closes after 6 seconds. The time stops while a pointer is over it,
  while VoiceOver or the keyboard is on it, and while the app is in the background. A toast with
  an action stays until the action is used or the toast is closed.
- A swipe down closes a toast, and so does Escape while the keyboard is on one of its buttons.
  VoiceOver's escape gesture closes it too.
- A toast sits above the on-screen keyboard. Declare a bar of your own at the bottom of the
  screen with `safeAreaInset(edge: .bottom)` outside the host, and the toast sits above it too:
  `InboxView().raincoatToastHost().safeAreaInset(edge: .bottom) { ActionBar() }`. A bar declared
  inside the host is hidden from it.
- Outside a host, `showRaincoatToast` does nothing. A `RaincoatToast` drawn on its own stands
  still, for previews and tests.

`raincoatShadow(_:in:fill:)` fills a shape behind a view and draws a token shadow, such as
`tokens.toast.shadow`, with it, as CSS draws a `box-shadow`. Use it in place of a background.

The Toast follows the
[Toast spec](https://github.com/raincoat-ui/design-system/blob/main/specs/components/toast/spec.yaml).

## Text and headings

```swift
Text("Settings").raincoatHeading(level: 1)
Text("Recent files").raincoatHeading(level: 3, variant: .headingSm)
Text("Your files are kept on this device and in the cloud.").raincoatText()
Text("Synced 2 minutes ago").raincoatText(.caption, color: .muted)
Label("Shared with you", systemImage: "person.2").raincoatText(.labelMd)
Text(message.preview).raincoatText(maxLines: 2)
```

`.raincoatText(_:color:maxLines:)` sets any `Text`, `Label`, or `TextField` in a text style:

| Parameter  | Type          | Default    | Notes                                                                           |
| ---------- | ------------- | ---------- | ------------------------------------------------------------------------------- |
| `variant`  | `TextVariant` | `.bodyMd`  | `.bodyLg`, `.bodyMd`, `.bodySm`, `.labelLg`, `.labelMd`, `.labelSm`, `.caption` |
| `color`    | `TextColor`   | `.default` | `.default`, `.muted`, `.danger`                                                 |
| `maxLines` | `Int?`        | `nil`      | Ends the text in an ellipsis after that many lines                              |

`.raincoatHeading(level:variant:color:)` makes a view a heading:

| Parameter | Type              | Default           | Notes                                                               |
| --------- | ----------------- | ----------------- | ------------------------------------------------------------------- |
| `level`   | `Int`             | Required          | 1 to 6. VoiceOver is told the view is a header, at this level       |
| `variant` | `HeadingVariant?` | Follows the level | 1 `.headingXl`, 2 `.headingLg`, 3 `.headingMd`, 4 to 6 `.headingSm` |
| `color`   | `HeadingColor`    | `.default`        | `.default`, `.muted`                                                |

- **The look is not the level.** People move through a screen from heading to heading with the
  VoiceOver rotor, by level. Choose the level for the heading's place in the outline, then set
  `variant` if the default look does not fit.
- **Text size.** Each style grows with Dynamic Type, with the system text style nearest its
  role: headings with `.largeTitle`, `.title2`, `.title3`, and `.headline`, body and label
  styles with `.body`, and captions with `.caption`. Large headings grow less than body text, as
  the system's own do, but a heading always grows to at least the size of the heading one level
  below it: at the largest sizes the large title grows less than title 2.
- **Long text wraps**, and the view grows taller. A heading is never cut short, even inside a
  `lineLimit`. Text cut short by `maxLines` is still read in full by VoiceOver.
- **Direction.** Text aligns to the leading edge: the right in right-to-left layouts. A
  paragraph takes its direction from its first strong character. A name or a message inside a
  sentence must be isolated, or the punctuation and numbers beside it join it:
  `Text("Message from \u{2068}\(name)\u{2069}, 2 minutes ago")`.

Text and headings follow the
[Typography spec](https://github.com/raincoat-ui/design-system/blob/main/specs/components/typography/spec.yaml),
which the React and Compose versions follow too.

## Dialogs, alert dialogs, and sheets

```swift
.raincoatDialog(Text("Rename file"), titleLevel: 2, isPresented: $isRenaming,
                description: Text("Everyone the file is shared with sees the new name.")) {
    TextField("Name", text: $name)
} actions: {
    RaincoatButton("Cancel") { isRenaming = false }
    RaincoatButton("Rename", variant: .primary) { rename() }
}

.raincoatSheet(Text("Filters"), titleLevel: 2, isPresented: $isFiltering, closeLabel: Text("Close")) {
    FilterList()
}

.raincoatAlertDialog(Text("Delete this address?"), isPresented: $isConfirming,
                     message: Text("It is removed from your account."),
                     actionLabel: Text("Delete address"), destructive: true,
                     cancelLabel: Text("Cancel")) { delete() }
```

| Parameter            | Type    | Default  | Notes                                                                        |
| -------------------- | ------- | -------- | ---------------------------------------------------------------------------- |
| `titleLevel`         | `Int`   | Required | The title's heading level, 1 to 6. The title is set in `.headingMd`          |
| `description`        | `Text?` | `nil`    | One sentence under the title                                                 |
| `closeLabel`         | `Text?` | `nil`    | Shows the close button, with this name. Required when there are no `actions` |
| `isDismissDisabled`  | `Bool`  | `false`  | Refuses a swipe, as while there are unsaved changes                          |
| `content`, `actions` | views   |          | The body, and the footer's buttons: Cancel first, the primary action last    |

- **The system sheet.** A dialog and a sheet are the system sheet, which is how iOS presents a
  modal task: from the bottom on iPhone and centered on iPad. It is as tall as its content, and
  the theme's fill, title, spaces, and buttons are inside it; its corners, shadow, and dimming
  are the system's. A sheet shows the system's drag indicator. So the web's sizes and edges do
  not apply on iOS.
- **The system alert.** An alert dialog is the system alert, which follows the person's text
  size, bold text, and contrast settings. The theme does not reach it. Cancel has the cancel
  role, and the confirming button the destructive role when `destructive` is true.
- **Closing.** A swipe down, VoiceOver's escape gesture, the close button, and Escape on a
  hardware keyboard close a dialog or a sheet. With `isDismissDisabled`, ask before your own
  buttons set `isPresented` to false.
- **Focus.** VoiceOver starts at the title and returns to where it was on close. To start in a
  field, focus it with `focused(_:)` when it appears.
- **Scrolling.** The body scrolls between the header and the footer, with a hairline while
  content is beneath them. When the screen is too short for three lines of it, as at the
  largest text sizes, the whole dialog scrolls.
- **The footer's buttons** sit at the trailing edge and stack, the primary action on top, when
  they do not fit in a row.

They follow the
[Dialog spec](https://github.com/raincoat-ui/design-system/blob/main/specs/components/dialog/spec.yaml),
which the React and Compose versions follow too.

## Card

```swift
// Static: a container, which can hold links and buttons.
RaincoatCard("Storage", level: 3) {
    Text("4.2 GB of 15 GB used").raincoatText(color: .muted)
}
.footer { RaincoatButton("Manage storage") { manageStorage() } }

// Interactive: the whole card is one link or one button.
NavigationLink(value: order) {
    RaincoatCard("Order 1042", level: 3) {
        Text("Delivered on Monday").raincoatText(color: .muted)
    }
    .media {
        Image("parcel").resizable().scaledToFill().frame(height: 120)
            .accessibilityLabel("A parcel at a front door")
    }
}
.buttonStyle(.raincoatCard)
```

| API                              | Notes                                                                                           |
| -------------------------------- | ----------------------------------------------------------------------------------------------- |
| `RaincoatCard(_:level:content:)` | The title, as `Text`, a localized key, or a string, and the body. The body is optional          |
| `.media { }`                     | An image at the top, edge to edge, with the card's top corners. Give it a height                |
| `.footer { }`                    | Buttons at the trailing edge of a static card. They wrap onto more rows when they do not fit    |
| `.buttonStyle(.raincoatCard)`    | On a `Button`, `NavigationLink`, or `Link` whose label is a `RaincoatCard`: an interactive card |

- **The title is a heading** at `level`, from 1 to 6, in the `headingSm` look. It wraps and is
  never cut short.
- **One action per interactive card.** In the card style, the card is the label of one button
  or link. VoiceOver reads it as one element, title first, so put no other controls in it. A
  card that needs Buttons stays static.
- **States.** An interactive card's outline steps to the strong border color under a pointer,
  and its fill changes while it is pressed. With Full Keyboard Access the system draws its own
  focus indicator, which follows the person's settings.
- **Media** is drawn at the top, and VoiceOver reads it after the title. Give it an accessibility
  label that says what it shows, or none when it only decorates.
- **Width.** A card fills the width it is offered and grows with its content. The stack or grid
  around it is the app's.

The Card follows the
[Card spec](https://github.com/raincoat-ui/design-system/blob/main/specs/components/card/spec.yaml),
which the React and Compose Cards follow too.

## Tabs

```swift
RaincoatTabs(selection: $section, tabs: [
    RaincoatTab("Details", value: Section.details),
    RaincoatTab("Photos", value: .photos, icon: Image(systemName: "photo")),
    RaincoatTab(icon: Image(systemName: "list.bullet"), accessibilityLabel: Text("List"), value: .list),
]) { section in
    SectionView(section)
}

RaincoatTabs(tabs: tabs) { section in SectionView(section) } // keeps its own selection
```

- The row runs across the full width over a hairline. When the tabs do not fit, it scrolls
  sideways, and the selected tab is scrolled into view. Labels stay on one line.
- Only the selected tab's panel is shown. There are no disabled tabs: leave out a tab that leads
  nowhere.
- VoiceOver is told the row is a tab bar, and the selected tab carries the selected trait. A
  tab with only an icon needs an accessibility label.
- A keyboard moves focus between the tabs as Full Keyboard Access does for any control, and
  Space selects.
- Each tab's touch area is at least 44 points tall.

The Tabs follow the
[Tabs spec](https://github.com/raincoat-ui/design-system/blob/main/specs/components/tabs/spec.yaml),
which the React and Compose Tabs follow too.

## Input

```swift
RaincoatInput("Full name", text: $name)
RaincoatInput("Email", text: $email, type: .email, description: Text("We send the receipt here."))
RaincoatInput("Email", text: $email, type: .email, isInvalid: !isValid, error: Text("Enter an email address"))
RaincoatInput("Search", text: $query, type: .search, isLabelHidden: true, leadingIcon: Image(systemName: "magnifyingglass"))
RaincoatInput("Message", text: $message, isMultiline: true)
RaincoatInput("Account number", text: $account, isReadOnly: true)
```

| Parameter       | Type        | Default | Notes                                                                   |
| --------------- | ----------- | ------- | ----------------------------------------------------------------------- |
| `type`          | `InputType` | `.text` | `.text`, `.email`, `.password`, `.search`, `.tel`, `.url`               |
| `size`          | `InputSize` | `.md`   | `.sm`, `.md`, `.lg`: the heights of the Button's sizes                  |
| `description`   | `Text?`     | `nil`   | Between the label and the field. VoiceOver reads it as the hint         |
| `prompt`        | `Text?`     | `nil`   | An example of the format, shown while the field is empty                |
| `isInvalid`     | `Bool`      | `false` | Shows the error below the field, and tells VoiceOver                    |
| `error`         | `Text?`     | `nil`   | What to do to make the value acceptable. An invalid field must have one |
| `isMultiline`   | `Bool`      | `false` | Starts `rows` lines tall (3) and grows with its content                 |
| `isReadOnly`    | `Bool`      | `false` | The value can be selected and copied, not changed                       |
| `isLabelHidden` | `Bool`      | `false` | Hides the label from view. It is still the field's name                 |
| `leadingIcon`   | `Image?`    | `nil`   | Decoration; hidden from assistive technology                            |

- The label is a `LocalizedStringKey`, a `String`, or a `Text`.
- Disable a field with `disabled(_:)`, and move focus to it with `focused(_:equals:)`: on
  submit, move focus to the first field in error.
- iOS has no invalid state, so VoiceOver reads an invalid field's error after its label: "Email,
  Enter an email address". It has no required state either: mark the fields that are optional
  in their label, "Phone (optional)".
- `type` sets the keyboard and the text content type that autofill uses. Email, phone, and web
  address fields are not capitalized or corrected, and stay left-to-right in a right-to-left
  layout, their icon included.
- The label, the description, and the error wrap; they are never truncated. Everything grows
  with the person's text size setting.
- The field takes the room it shows. Where it is shorter than 44 points, the text field inside
  reaches past its top and bottom, so touches there place the caret.
- The system draws the focus indicator and the caret.

To give any `TextField` or `SecureField` the look of the field alone, use the style:

```swift
TextField("Search", text: $query).textFieldStyle(.raincoat(size: .sm))
```

The Input follows the
[Input spec](https://github.com/raincoat-ui/design-system/blob/main/specs/components/input/spec.yaml),
which the React and Compose Inputs follow too.

## Working on this package

```sh
swift test --package-path packages/ios
```

`Sources/*/Generated/` is written by `pnpm tokens:build`. Component code may not name a color or
write a size as a number; `pnpm test` checks.

## License

Apache-2.0.
