# Volta-Native

Shared native UI for macOS apps, so Swift and C apps look and behave the same. macOS 14 or later, no third-party dependencies.

```sh
make            # open the Swift gallery, which shows every component
make c-gallery  # the same controls driven from plain C
make test
```

## What's inside

| Component | Swift | C |
| --- | --- | --- |
| Design tokens (accent, radius, sizes, opacities, 150ms motion) | `VoltaTokens`, `VoltaDesign` | `volta_tokens.h` |
| Buttons: standard, prominent, link, destructive | `.buttonStyle(.volta)`, `.voltaProminent`, `.voltaLink` | `volta_button_create` |
| Icon button with hover outline | `.buttonStyle(.voltaHover)` | |
| Checkbox | `.toggleStyle(.voltaCheckbox)` | `volta_checkbox_create` |
| Text and search fields | `VoltaTextField`, `.voltaField()`, `VoltaSearchField` | `volta_text_field_create`, `volta_search_field_create` |
| Avatar, chip, flow layout, divider, empty state | `VoltaAvatar`, `VoltaChip`, `VoltaFlowLayout`, `VoltaDivider`, `VoltaEmptyState` | avatar, chip, divider |
| Notes-style rich text editor with HTML export | `RichTextEditor`, `FormattingBar`, `FormatCommands` | |
| Safe HTML viewer (no JS, strict CSP) | `SafeHTMLView` | |
| Window behaviour fixes | `WindowChrome` | built into `volta_window_create` |
| Knob (drag, scroll, arrow keys, double-click reset, typed values) | `VoltaKnob`, `KnobSpec` | |
| Panel and section label for plugin sections | `.voltaPanel()`, `VoltaSectionLabel` | |
| Theme: light, dark or system, accent and custom colours, saved as JSON | `VoltaTheme`, `.voltaTheme(_:)`, `VoltaThemePicker`, `VoltaCanvas` | |
| JUCE look (knobs, sliders, buttons, checkboxes, menus, fields; follows light and dark) | | `juce/include/volta/VoltaLookAndFeel.h` |
| JUCE theme editor | | `juce/include/volta/VoltaThemeEditor.h` |

`.voltaControls()` applies the Volta button and checkbox styles to a whole view tree.

## Using it from Swift

```swift
// Package.swift
.package(url: "https://github.com/<owner>/volta-native", branch: "main")
// target dependency: .product(name: "VoltaNative", package: "volta-native")

import VoltaNative

struct SettingsView: View {
    @State private var name = ""
    @State private var sync = true
    var body: some View {
        VStack(alignment: .leading) {
            VoltaTextField("Name", text: $name)
            Toggle("Sync", isOn: $sync)
            Button("Save") {}.buttonStyle(.voltaProminent)
        }
        .voltaControls()
        .voltaAccent(.blue) // optional: per-app or per-view accent
    }
}
```

## Themes

Everything follows macOS light and dark mode by default. Where the system appearance can't be read (the JUCE look on Linux), Volta uses dark.

A `VoltaTheme` lets a person choose instead: System, Light or Dark, an accent, and optionally the background, surface and text colours. Unset colours keep the appearance's own, and a custom text colour also sets the secondary text (the text at 60% over the background). The theme saves as JSON, and Swift and JUCE read the same format, so an app and its plugin can share one.

```swift
@State private var theme = VoltaTheme.load()          // UserDefaults, falls back to .standard

var body: some View {
    ContentView()
        .background(VoltaCanvas())                    // the theme's background
        .voltaTheme(theme)                            // sets appearance, accent and palette
        .preferredColorScheme(theme.colorScheme)      // so the window chrome matches too
        .onChange(of: theme) { _, t in t.save() }
}

// In settings:
VoltaThemePicker(theme: $theme)
```

Components draw from `@Environment(\.voltaPalette)` (canvas, surface, text, secondary). With the system appearance and no custom colours it holds AppKit's dynamic colours, so nothing changes from a plain macOS app. `.voltaAccent(_:)` still overrides just the accent.

## Using it from C

Build the library with `make c-lib`, then compile against `include/` and link `libVoltaNativeC.dylib`. See `Examples/CGallery/main.c` for a full app.

```c
#include "volta_native.h"

static void save(void *ctx) { /* ... */ }

int main(void) {
    volta_app_init("My App");
    volta_view page = volta_stack_create(true, 12);
    volta_view field = volta_text_field_create("Name", 300, NULL, NULL);
    volta_stack_add(page, field);
    volta_view button = volta_button_create("Save", VOLTA_BUTTON_PROMINENT, save, NULL);
    volta_stack_add(page, button);
    volta_view_release(button);

    volta_window window = volta_window_create("My App", 480, 320);
    volta_window_set_content(window, page);
    volta_window_show(window);
    volta_app_run();
}
```

The C controls are the same SwiftUI components, hosted in `NSView`s, so C and Swift apps can't drift apart. Call the API on the main thread. `@_cdecl` is an officially unsupported Swift attribute, but it's widely used and stable in practice.

## Using it from JUCE

The `juce/` folder is a header-only `LookAndFeel_V4` for JUCE plugins, built from the same tokens (`include/volta_tokens.h`). It follows the system light and dark mode on macOS and Windows and is dark elsewhere.

```cmake
FetchContent_Declare(VoltaNative GIT_REPOSITORY https://github.com/kriogenx0/volta-native.git GIT_TAG main)
FetchContent_MakeAvailable(VoltaNative)   # after JUCE is available
target_link_libraries(MyPlugin PRIVATE volta::juce)
```

```cpp
#include <volta/VoltaLookAndFeel.h>

// In the editor: declare `volta::VoltaLookAndFeel lnf;` before the child components.
MyEditor::MyEditor (MyProcessor& p) : AudioProcessorEditor (&p)
{
    setLookAndFeel (&lnf);
    lnf.onAppearanceChanged = [this] { sendLookAndFeelChange(); };
    volta::VoltaLookAndFeel::makeProminent (triggerButton); // the one primary action
}
MyEditor::~MyEditor() { setLookAndFeel (nullptr); }
```

Rotary sliders draw as Volta knobs (bipolar ranges fill from the centre), `ToggleButton`s as Volta checkboxes, and `TextButton`s as Volta buttons. `lnf.drawPanel()` and `lnf.drawSectionLabel()` draw plugin sections. JUCE has no implicit animation, so hover changes are immediate rather than the 150 ms fade.

To theme it, pass a `volta::Theme` (same fields and JSON as `VoltaTheme`):

```cpp
lnf.setTheme (volta::Theme::fromJSON (state.getProperty ("theme").toString()));

#include <volta/VoltaThemeEditor.h>          // needs juce_gui_extra
volta::ThemeEditor themeEditor { lnf };      // System/Light/Dark, colour swatches, Reset
themeEditor.onThemeChanged = [this] (const volta::Theme& t) { state.setProperty ("theme", t.toJSON(), nullptr); };
```

`setTheme` refreshes every window and calls `onAppearanceChanged`.

## Design tokens

`tokens/tokens.json` is the source of truth. After editing it, run `make tokens` to regenerate `Sources/VoltaNative/Tokens.swift` and `include/volta_tokens.h`, and commit both. A test fails if they're out of date. Toolkits other than AppKit (for example GTK or Win32 apps) can read the same JSON.

## Design principles

All components follow the shared [design principles](docs/rules/design-principles.md): consistent native controls, hover feedback only on clickable things, 150ms animations, no size change on hover, no selectable text in controls, and click masks that follow borders.

## Agent rules

`AGENTS.md` loads the shared rules from [kriogenx0/agent-rules](https://github.com/kriogenx0/agent-rules), synced into `docs/rules/` by `make rules` (set `AGENT_RULES` if your checkout isn't at `~/Sites/agent-rules`). This repo's own settings and facts are in `docs/project/`.

## Origin

Extracted from FireMail. Rich text attributes are namespaced `Volta.style`, `Volta.list` and `Volta.quote` instead of FireMail's `FireMail.*`. If FireMail switches to this package, drafts it saved earlier need their attribute keys migrated.
