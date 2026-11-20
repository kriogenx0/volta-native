# Theme

Lets apps and plugins built on Volta-Native follow the system light or dark mode, or let a person choose an appearance and colours.

## What it does

- **Appearance.** System (default), Light or Dark. System follows macOS light and dark mode. The JUCE look reads the system setting on macOS and Windows; elsewhere it uses dark.
- **Colours.** An accent, and optional background (canvas), surface (fields, knob discs, menus) and text colours. Unset colours keep the appearance's own. A custom text colour also sets the secondary colour: the text at 60% over the background.
- **Saving.** One JSON shape on both sides: `{"appearance":"dark","accent":{"red":…,"green":…,"blue":…},"canvas":{…},"surface":{…},"text":{…}}`. Missing or unknown values fall back to the defaults.

## Swift

- `VoltaTheme` (`Sources/VoltaNative/Theme.swift`): the model. `load(from:key:)` and `save(to:key:)` use UserDefaults (key `VoltaTheme`).
- `.voltaTheme(_:)`: sets `\.voltaTheme`, `\.voltaPalette`, the accent, the tint, the foreground style and the colour scheme for a view tree. Apps add `.preferredColorScheme(theme.colorScheme)` so the window chrome matches.
- `VoltaPalette`: the resolved colours. With the System appearance and no custom colours it holds AppKit's dynamic colours.
- `VoltaThemePicker` (`ThemePicker.swift`): segmented appearance control, colour pickers and Reset.
- `VoltaCanvas`: fills with the theme background.
- Every component draws from `\.voltaPalette` instead of `Color.primary`/`Color.secondary`.
- Gallery: the Theme section, and the header's appearance control, edit one saved theme.

## JUCE

- `volta::Theme` (`juce/include/volta/VoltaLookAndFeel.h`): the same model, with `toJSON()`/`fromJSON()`.
- `VoltaLookAndFeel::setTheme()`/`getTheme()`, and a constructor that takes a theme. `setAccent()` and `setDarkMode()` now edit the theme. `setTheme` refreshes every desktop component and calls `onAppearanceChanged`.
- `volta::ThemeEditor` (`juce/include/volta/VoltaThemeEditor.h`): System/Light/Dark buttons, colour swatches that open a `ColourSelector` in a callout, and Reset. Needs `juce_gui_extra`.

## Tests

`Tests/VoltaNativeTests/ThemeTests.swift`: hex and Codable round trips, tolerant decoding, UserDefaults save and load, and palette resolution (system, forced, custom text).

## Known limits

- Plugins don't save or show a theme yet; each needs its own setting (AU state or app preferences) and a place for the picker.
- A theme isn't shared between apps automatically; each app saves its own unless they agree on a UserDefaults suite.

## History

- Implemented 2026-11-20; also applied to the switch, segmented control, radio, tag, progress bar and spinner. Not verified: no Swift toolchain was available, so the Swift code and tests were not built or run, and the gallery wasn't opened. The JUCE headers passed `clang++ -fsyntax-only -Wall -Wextra -Wshadow` against JUCE 8.0.15 (Linux). Not released; plugins still use the default theme.
