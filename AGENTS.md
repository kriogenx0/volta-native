# AGENTS.md — Volta-Native

Volta-Native is the shared native UI library for macOS apps written in Swift or C. It has no third-party dependencies.

## Commands

- `make` / `make gallery`: build and open the Swift component gallery.
- `make c-gallery`: build `libVoltaNativeC.dylib` and run the C gallery.
- `make test`: `swift test`.
- `make tokens`: regenerate `Sources/VoltaNative/Tokens.swift` and `include/volta_tokens.h` from `tokens/tokens.json`.

## Layout

- `tokens/tokens.json`: the single source of design values. Never edit the generated token files by hand.
- `Sources/VoltaNative/`: SwiftUI components. Everything an app uses is `public`.
- `Sources/VoltaNativeC/CAPI.swift` + `include/volta_native.h`: the C API. Every `@_cdecl` name must match a header declaration, and a test checks this.
- `Sources/VoltaGallery/` and `Examples/CGallery/`: apps that show every component.
- `juce/`: header-only JUCE `LookAndFeel` (`volta::juce` CMake target) using the same generated tokens. Its light and dark `Palette` mirrors the AppKit system colours the Swift side uses; change both together.

## Conventions

- Every new component gets a section in the Swift gallery. If C apps need it, add it to the C API and the C gallery too.
- Components read the accent from `@Environment(\.voltaAccent)`, never a hard-coded color, so apps can override it.
- Follow the [design principles](docs/design-principles.md) for all UI work.

## After changing code

1. `make test`
2. `make gallery` (and `make c-gallery` if the C API changed)
3. Propose a short, one-line commit message for the user's approval before committing.
