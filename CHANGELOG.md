# @raincoat-ui/swift

## 0.1.0-next.5

### Minor Changes

- 9035080: Card: a surface that groups content about one subject, on every platform.
  - A card has a title, which is a heading in `heading-sm` at the level you give, and optionally
    media at the top, edge to edge, a body, and Buttons in a footer at the end. Its outline, fill,
    and shadow come from the theme. It fills the width it is given and grows with its content.
  - A card is static, a container that can hold links and buttons, or interactive: the whole card
    is one link or one button, named by its title, and holds no other controls. An interactive
    card's outline steps to the strong border color under a pointer, its fill changes while it is
    pressed, and keyboard focus draws the focus ring around the whole card.
  - **React:** `Card`, `CardMedia`, `CardTitle`, `CardBody`, and `CardFooter`. A `CardLink` or a
    `CardButton` in the title makes the card interactive. A static card and a link card render in
    a Server Component.
  - **SwiftUI:** `RaincoatCard`, with `.media { }` and `.footer { }`. A `Button` or
    `NavigationLink` whose label is a `RaincoatCard`, with `.buttonStyle(.raincoatCard)`, is an
    interactive card, read by VoiceOver as one element, title first.
  - **Compose:** `RaincoatCard`, on Compose Foundation. With `onClick` it is interactive: one
    button whose semantics merge the card's content.
  - The shadow is drawn from `card.shadow`; the base theme's is none.
- 6de19ce: Dialog, alert dialog, and Sheet: the modal surfaces, on every platform.
  - **Dialog**: a panel centered over the screen, `sm`, `md` (the default), or `lg` wide, and
    across the window less a margin on a narrower one. It closes on Escape, the scrim, the close
    button or Cancel, and the back gesture on Android.
  - **Alert dialog**: confirms something consequential. Focus starts on Cancel; Escape and back
    mean Cancel; the scrim does nothing. Mark the confirming action `destructive` when it destroys
    something.
  - **Sheet**: rises from the `bottom` edge (the default) or slides in from the `end` edge, which
    becomes the bottom on a window less than twice the sheet's width. On iOS and Android a bottom
    sheet also closes when dragged down.
  - Every one has a title, which names it and wraps, an optional description, a body that scrolls
    between a fixed header and footer (with a hairline while content is beneath them, and the
    whole surface scrolling instead in a very short window), and a footer whose buttons stack,
    the primary first, when they do not fit. The close button is shown only when you give it a
    name. Focus moves to the title on open, or to a target you name, and back to the control that
    opened the dialog on close.
  - **React:** `Dialog`, `AlertDialog`, and `Sheet`, each with a trigger, content, header, title,
    description, body, and footer, on Radix. The dialog renders at the end of the page's body: set
    `data-theme` and `dir` on the root element, or pass `container`.
  - **SwiftUI:** `.raincoatDialog`, `.raincoatSheet`, and `.raincoatAlertDialog`. Dialogs and
    sheets are the system sheet, sized to their content; an alert dialog is the system alert.
  - **Compose:** `RaincoatDialog`, `RaincoatAlertDialog`, and `RaincoatSheet`, in a dialog window
    on Compose Foundation alone.

  For spec authors: when a part of a spec has the component's own name, the generated type of any
  part of an example is named `<Component>PartExampleProperties`.
- 1b0c94b: The Input: a text field with its label, an optional description, and an error message, in one
  line or several. It follows `specs/components/input/spec.yaml`.
  - **React.** `<Input label="Email" type="email" />`, on a native `<input>`, or a `<textarea>`
    with `multiline`. The field is described by its description and then its error, and sets
    `aria-invalid` and `required`. While a Vietnamese or CJK input method composes, the field
    keeps the error state it had, and Enter that commits the composition does not submit the
    form. Email, phone, and web address fields stay left-to-right in a right-to-left layout.
    Japanese breaks into lines by the strict rules, and Korean between whole words, in the field
    and in its label, description, and error. The Input is a Client Component that a Server
    Component can render.
  - **SwiftUI.** `RaincoatInput("Email", text: $email, type: .email)`, on `TextField` and
    `SecureField`. VoiceOver reads the description as the hint and, since iOS has no invalid
    state, an invalid field's error after its label. `.textFieldStyle(.raincoat())` gives any text
    field the look of the field alone.
  - **Compose.** `RaincoatInput(value, onValueChange, label = "Email", type = InputType.Email)`, on
    Compose Foundation's `BasicTextField`. An invalid field carries Compose's error semantics with
    its message, and the description is part of the field's semantics after its name. Its texts
    break into lines as every Raincoat text style does: Korean only between whole words.

  Every size is as tall as the Button of the same size. A field shorter than the minimum touch
  target still takes touches across that target, without taking more room than it shows. As the
  person's text size grows, the value, the label, and the leading icon grow with it, and the space
  above and below the value stays as it is, so the field grows taller, as the Button does. The
  generated `InputSize` and `InputType` types are exported on every platform.
- 2fda7f2: Tabs: a row of tabs that switches between panels of related content in one view.
  - **React.** `Tabs`, `TabsList`, `TabsTrigger`, and `TabsContent`, also from
    `@raincoat-ui/react/tabs`. The arrow keys select the tab they reach, or only move focus with
    `activationMode="manual"`; the tabs follow the page's direction; `keepMounted` keeps a panel's
    content while its tab is not selected. When the tabs do not fit, the list scrolls sideways, with
    previous and next buttons for a mouse.
  - **SwiftUI.** `RaincoatTabs` and `RaincoatTab`. VoiceOver is told the row is a tab bar, and the
    selected tab carries the selected trait.
  - **Compose.** `RaincoatTabs` and `RaincoatTab`: a selectable group of tabs with the tab role.
    Enter or Space selects.

  Selection is controlled by the app or kept by the tabs. Labels stay on one line and are never
  truncated. There are no disabled tabs.
- 9caed42: The Toast: a short message near the bottom of the screen that says something has happened, such
  as "Message archived", optionally with one action such as Undo.
  - **React.** Put `ToastProvider` around the app, with a `label` for the region that holds the
    toasts, such as "Notifications". `useToast().show({ message })` shows a toast from anywhere
    inside it; `show({ message, action: { label, onClick }, closeLabel })` shows one with an action.
    F8 moves focus to the toast and back. `bottomInset` keeps the toasts above a bar of your own.
    `Toast` draws a toast standing still, for documentation and tests.
  - **SwiftUI.** `raincoatToastHost()` puts a host on a screen, and the `showRaincoatToast`
    environment action shows a `RaincoatToast` from anywhere inside it.
    `raincoatShadow(_:in:fill:)` fills a shape behind a view and draws a token shadow with it.
  - **Compose.** `RaincoatToastHost` shows the toasts of a `RaincoatToastHostState`, whose `show`
    suspends until the toast closes and says how. `RaincoatToast` draws a toast on its own.
    `Modifier.raincoatShadow(shadow, shape, fill)` fills a shape and draws a token shadow with it.

  On every platform one toast is shown at a time, and others wait in order. A toast never takes
  focus, and its message is announced politely. Without an action, a toast closes after 6 seconds;
  the time stops while a pointer is over it, while it has focus, and while the app is in the
  background, and on Android the person's accessibility timeout replaces it when longer. A toast
  with an action stays until the action is used or the toast is closed, so it must have a named
  close button. A swipe down closes a toast. The packages ship no text for it: every word comes
  from the app.
- 9e8e1d7: Typography: Text, for running text and labels, and Heading, for headings, on every platform.
  - **Text** sets text in a body, label, or caption style (`body-lg`, `body-md`, `body-sm`,
    `label-lg`, `label-md`, `label-sm`, `caption`) and the `default`, `muted`, or `danger` text
    color. With `max-lines` it ends in an ellipsis after that many lines; assistive technology
    still reads all of it.
  - **Heading** takes a required `level`, from 1 to 6, which places it in the outline of the
    screen. Its look follows the level (1 `heading-xl`, 2 `heading-lg`, 3 `heading-md`, 4 to 6
    `heading-sm`) unless `variant` says otherwise. Its color is `default` or `muted`. It wraps and
    is never cut short.
  - **React:** `<Text>` renders a `p`, or a `span`, `div`, or `label` with `as`. `<Heading>`
    renders `h1` to `h6`. Both render in a Server Component.
  - **SwiftUI:** `.raincoatText(_:color:maxLines:)` on any `Text`, `Label`, or `TextField`, and
    `.raincoatHeading(level:variant:color:)`, which adds the header trait and the heading level.
    Each style grows with Dynamic Type relative to the system text style nearest its role.
  - **Compose:** `RaincoatText` and `RaincoatHeading`, on Compose Foundation's `BasicText`.
    `RaincoatHeading` sets heading semantics; Android has no heading levels.

  For spec authors: a component spec can have parts, each with properties of its own, and a
  property can be a whole number with a range. A default can follow another property.
- eb11244: The tokens of the v1 components: Typography, Input, Card, Dialog and Sheet, Tabs, and Toast.
  - **Text styles.** `type.heading.xl`, `.lg`, `.md`, and `.sm` (32, 24, 20, and 16px),
    `type.body.lg` (18px), and `type.caption` (12px).
  - **Color roles.** `color.bg.raised` for cards, dialogs, sheets, and toasts; `color.bg.scrim`, the
    translucent veil behind a dialog; `color.border.control` for the outline of a text field;
    `color.border.danger` for a field in error; and `color.border.selected` for the selected tab.
    In the base, a raised surface is the color of the page.
  - **Shadows.** `shadow.raised` and `shadow.overlay`. Both are `shadow.none` in the base, which
    draws nothing. On iOS and Android a shadow is a `TokenShadow`; draw its `visibleLayers`.
  - **Sizes.** `size.panel.sm`, `.md`, and `.lg` (400, 560, and 800px), the widths of dialogs,
    sheets, and toasts.
  - **Component tokens** for `input`, `card`, `dialog`, `sheet`, `tabs`, and `toast`.

  Text and outline colors that were checked against the page are now also checked against
  `color.bg.raised`, and `color.fg.muted` against the fill of a neutral control at rest and hovered.

  For theme authors: a theme may now give `shadow.raised` and `shadow.overlay` a value, composed of
  primitive tokens, and may override `card.border.default`. The token build refuses a text style
  smaller than `font.size.12`.

### Patch Changes

- 0c21bea: The Button keeps its padding at large text sizes, and breaks Japanese and Korean labels by
  their rules.
  - **Web.** At a larger text size, the space above and below the label is what it is at the
    default size, so the button grows taller. Before, the padding shrank as the text grew, and at
    twice the default size the label touched the top and bottom of the button. Icons and the
    spinner now grow with the text, as on iOS and Android.
  - **Web.** Lines of a label break by the strict rules, so no line of Japanese starts with a
    small kana or a prolonged sound mark. A Korean label breaks only between words.
  - **Android.** The label breaks by the strict rules too.
  - **All platforms.** A button that shows only an icon keeps the space around its icon at a
    larger text size, so it grows and stays square. Before, on iOS and Android, the button kept
    its size until the icon filled it.
- 0d14042: On iOS, a dialog or a sheet that the keyboard covers the bottom of now keeps to what shows above
  it. Its scrolling area ends above the keyboard, so the field being edited and the footer's
  buttons scroll into view and stay there, and the field being edited is brought into view when
  the keyboard comes up. Before, at the largest text sizes, the dialog went on under the keyboard,
  and what was scrolled into view slid back behind it.
- 0d14042: On iOS, the text of every component grows with the person's text size setting as much as the
  system font of the text style it follows. Before, the scale came from SwiftUI's scaled metric,
  which grows by a factor of its own: at the largest accessibility size, body-sized text was 3
  times its default size instead of 3.12 times.
- cbd29ad: Typography fixes.
  - **SwiftUI:** a heading is no longer drawn smaller than the heading one level below it at the
    largest text sizes. iOS enlarges its large title less than its smaller titles, so at the
    largest accessibility size `headingXl` was smaller than `headingLg`. Each heading now grows to
    at least the size of the look below it.
  - **Compose:** text set in a Raincoat text style breaks by the rules of the person's language,
    in every component, the Button's label included: by the strict rules, and Korean only between
    whole words, from Android 13. Korean headings and labels broke in the middle of a word.
    Japanese breaks as before.
  - **Every platform:** the guidelines now say what each platform does with a name inside a
    sentence. A paragraph takes its direction from its first strong character, but a name in
    another script takes the punctuation and numbers beside it into its own run, as in "Message
    from 2 ,مريم الحسيني minutes ago". Isolate the name: in a `Text` span with `dir="auto"` on the
    web, and between U+2068 and U+2069 on iOS and Android.

## 0.1.0-next.4

No changes in this release.

## 0.1.0-next.3

### Minor Changes

- 2e9c446: A second theme, Ink: black and white only, with red kept for danger. The primary button is a
  black block with a white label, and white with a black label at night, on a pure black canvas.
  Every corner is square, and labels are set in Archivo at medium weight. It ships as
  `@raincoat-ui/theme-ink`, `io.github.raincoat-ui:theme-ink`, and the Swift product
  `RaincoatThemeInk`.
- 5f46e98: Themes are directories, and the token build is published.

  A theme is `themes/<id>/`: a `theme.json`, a `brand.md`, and files that give new values to the
  tokens the base marks overridable. The token build checks each theme with every rule of the base,
  checks its contrast in every mode, and generates its packages on every platform:
  `@raincoat-ui/theme-<id>` on npm, `io.github.raincoat-ui:theme-<id>` in the Maven repository, and
  the Swift product `RaincoatTheme<Id>`. Each installs on its own, with only the token types.

  `@raincoat-ui/tokens` is now published, with its command line `raincoat-tokens`. Run in a
  repository of your own, it builds the themes there into a theme pack: an npm package per theme, a
  Swift package, and a Gradle build, each depending on Raincoat's packages of the same version. Use
  it for brands that must not be public.

## 0.1.0-next.2

### Minor Changes

- ad13995: The base theme is quieter and sharper: neutral greys lose their blue cast, every radius is 2px,
  button labels are semibold, and secondary buttons have an ink outline. Brand themes that set
  their own radii, label weights, neutrals, or `color.border.strong` look the same as before.

## 0.1.0-next.1

### Patch Changes

- 4a293c8: A loading Button tells VoiceOver that it is in progress.

  On iOS a loading button was read as its label alone. It now has the accessibility value "In
  progress", so it is read as "Save changes, In progress". The words are translated into English,
  Vietnamese, Simplified and Traditional Chinese, Japanese, and Korean, and are in English for any
  other language. iOS uses a package's translation only for a language the app supports, or when
  the app sets `CFBundleAllowMixedLocalizations`.

  The Swift package now has resources and a default localization.
- 12311ca: A Button takes the room it shows on iOS and Android.

  The minimum touch target (44pt on iOS, 48dp on Android) was part of the layout size, so a small
  button took more room than it showed. Now the layout size is the visible size, and the area
  that takes touches reaches past a smaller button without taking room, as it already did on the
  web. Layouts that relied on the extra room around a small or, on Android, medium button will
  move: leave 8px or more between small buttons.

  On Android a mouse now has to be on the button itself, and a touch between two buttons goes to
  the nearer one.

## 0.1.0-next.0

### Minor Changes

- 7b10fa2: The first prerelease. It contains the base theme in four color modes and two densities, and
  the Button for React, SwiftUI, and Jetpack Compose, all three built from one token source and
  one component spec.
