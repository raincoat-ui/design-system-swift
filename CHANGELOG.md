# @raincoat-ui/swift

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
