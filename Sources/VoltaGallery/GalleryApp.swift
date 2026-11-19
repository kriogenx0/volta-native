import SwiftUI
import AppKit
import VoltaNative

/// A small app that shows every Volta-Native component, so changes can be checked by eye in light and dark mode.
@main
struct GalleryApp: App {
    init() {
        // Launched with `swift run`, the process is not an app bundle, so make it a regular app with a Dock icon.
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async { NSApplication.shared.activate() }
    }

    var body: some Scene {
        WindowGroup("Volta Gallery") {
            GalleryView().frame(minWidth: 760, minHeight: 520)
        }
        .commands { FormatCommands() }
    }
}

enum GallerySection: String, CaseIterable, Identifiable {
    case tokens = "Tokens"
    case buttons = "Buttons"
    case checkboxes = "Checkboxes"
    case fields = "Fields"
    case knobs = "Knobs and panels"
    case display = "Avatars and chips"
    case empty = "Empty state"
    case richText = "Rich text"
    case html = "Safe HTML"

    var id: Self { self }
    var symbol: String {
        switch self {
        case .tokens: return "swatchpalette"
        case .buttons: return "button.horizontal"
        case .checkboxes: return "checkmark.square"
        case .fields: return "character.cursor.ibeam"
        case .knobs: return "dial.medium"
        case .display: return "person.crop.circle"
        case .empty: return "tray"
        case .richText: return "textformat"
        case .html: return "doc.richtext"
        }
    }
}

enum Accent: String, CaseIterable, Identifiable {
    case volta = "Volta", blue = "Blue", green = "Green", purple = "Purple"
    var id: Self { self }
    var color: Color {
        switch self {
        case .volta: return .voltaAccent
        case .blue: return .blue
        case .green: return .green
        case .purple: return .purple
        }
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    var id: Self { self }
    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct GalleryView: View {
    @State private var section: GallerySection? = .tokens
    @State private var accent: Accent = .volta
    @State private var appearance: Appearance = .system

    var body: some View {
        NavigationSplitView {
            List(GallerySection.allCases, selection: $section) { item in
                Label(item.rawValue, systemImage: item.symbol).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Text(section?.rawValue ?? "").font(.title2.weight(.semibold))
                    Spacer()
                    Picker("Accent", selection: $accent) {
                        ForEach(Accent.allCases) { Text($0.rawValue).tag($0) }
                    }.fixedSize()
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).fixedSize()
                }
                .padding(.horizontal, 24).padding(.vertical, 14)
                VoltaDivider()
                Group {
                    switch section ?? .tokens {
                    case .tokens: ScrollView { TokensDemo().padding(24) }
                    case .buttons: ScrollView { ButtonsDemo().padding(24) }
                    case .checkboxes: ScrollView { CheckboxesDemo().padding(24) }
                    case .fields: ScrollView { FieldsDemo().padding(24) }
                    case .knobs: ScrollView { KnobsDemo().padding(24) }
                    case .display: ScrollView { DisplayDemo().padding(24) }
                    case .empty: VoltaEmptyState(icon: "tray", title: "Nothing here yet", subtitle: "Views with no content show this instead of a blank pane.")
                    case .richText: RichTextDemo()
                    case .html: HTMLDemo()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .voltaControls()
        }
        .voltaAccent(accent.color)
        .preferredColorScheme(appearance.scheme)
        .background(WindowChrome())
    }
}

/// A titled group of examples.
struct DemoGroup<Content: View>: View {
    let title: String
    let note: String
    @ViewBuilder let content: Content

    init(_ title: String, note: String = "", @ViewBuilder content: () -> Content) {
        self.title = title
        self.note = note
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            if !note.isEmpty { Text(note).font(.callout).foregroundStyle(.secondary) }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 20)
    }
}

struct TokensDemo: View {
    @Environment(\.voltaAccent) private var accent
    private let rows: [(String, String)] = [
        ("Corner radius", "\(Int(VoltaTokens.radiusControl)) pt"),
        ("Checkbox radius", "\(Int(VoltaTokens.radiusCheckbox)) pt"),
        ("Field height", "\(Int(VoltaTokens.sizeFieldHeight)) pt"),
        ("Checkbox size", "\(Int(VoltaTokens.sizeCheckbox)) pt"),
        ("Animation", "\(Int(VoltaTokens.motionDuration * 1000)) ms ease-out"),
        ("Boundary opacity", "\(VoltaTokens.opacityBoundary)"),
        ("Hover opacity", "\(VoltaTokens.opacityHover)"),
        ("Divider opacity", "\(VoltaTokens.opacityDivider)"),
        ("Disabled opacity", "\(VoltaTokens.opacityDisabled)"),
    ]

    var body: some View {
        DemoGroup("Accent", note: "The default comes from tokens.json. Apps and views can override it with .voltaAccent(_:), as the picker above does.") {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius).fill(accent).frame(width: 64, height: 40)
                RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius).fill(Color.voltaAccent).frame(width: 64, height: 40)
                    .overlay(Text("Default").font(.caption2).foregroundStyle(.white))
            }
        }
        DemoGroup("Values", note: "Shared with C apps through include/volta_tokens.h.") {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                ForEach(rows, id: \.0) { row in
                    GridRow {
                        Text(row.0).foregroundStyle(.secondary)
                        Text(row.1).monospacedDigit()
                    }
                }
            }
        }
    }
}

struct ButtonsDemo: View {
    @State private var clicks = 0

    var body: some View {
        DemoGroup("Text buttons", note: "Hover and press change color only, never size or position.") {
            HStack(spacing: 10) {
                Button("Standard") { clicks += 1 }.buttonStyle(.volta)
                Button("Prominent") { clicks += 1 }.buttonStyle(.voltaProminent)
                Button("Link") { clicks += 1 }.buttonStyle(.voltaLink)
            }
            Text("Clicked \(clicks) times").font(.callout).foregroundStyle(.secondary).monospacedDigit()
        }
        DemoGroup("Destructive") {
            HStack(spacing: 10) {
                Button("Delete", role: .destructive) {}.buttonStyle(.volta)
                Button("Delete", role: .destructive) {}.buttonStyle(.voltaProminent)
                Button("Delete", role: .destructive) {}.buttonStyle(.voltaLink)
            }
        }
        DemoGroup("Disabled") {
            HStack(spacing: 10) {
                Button("Standard") {}.buttonStyle(.volta)
                Button("Prominent") {}.buttonStyle(.voltaProminent)
                Button("Link") {}.buttonStyle(.voltaLink)
            }.disabled(true)
        }
        DemoGroup("Icon buttons", note: "VoltaHoverButtonStyle: no bezel, an outline on hover.") {
            HStack(spacing: 4) {
                ForEach(["archivebox", "trash", "flag", "arrowshape.turn.up.left"], id: \.self) { symbol in
                    Button {} label: { Image(systemName: symbol).frame(width: 20, height: 20).padding(4) }
                        .buttonStyle(.voltaHover).help(symbol).accessibilityLabel(symbol)
                }
            }
        }
    }
}

struct CheckboxesDemo: View {
    @State private var first = true
    @State private var second = false

    var body: some View {
        DemoGroup("Checkboxes", note: "The whole row is the click target and gets a hover background.") {
            Toggle("Show unread count", isOn: $first)
            Toggle("Load remote images", isOn: $second)
            Toggle("Disabled option", isOn: .constant(true)).disabled(true)
        }
        DemoGroup("Without label") {
            Toggle("Select", isOn: $second).toggleStyle(VoltaCheckboxStyle(showsLabel: false))
        }
    }
}

struct FieldsDemo: View {
    @State private var name = ""
    @State private var email = "ada@example.com"
    @State private var password = ""
    @State private var search = ""

    var body: some View {
        DemoGroup("Text fields", note: "The border is the click mask. Hover outlines it and focus colors it with the accent.") {
            VStack(alignment: .leading, spacing: 10) {
                VoltaTextField("Name", text: $name)
                VoltaTextField("Email", text: $email)
                SecureField("Password", text: $password, prompt: Text("Password")).voltaField()
                VoltaTextField("Disabled", text: .constant("Can't edit this")).disabled(true)
            }.frame(maxWidth: 360)
        }
        DemoGroup("Search field", note: "The clear button appears once there is text.") {
            VoltaSearchField("Search", text: $search).frame(maxWidth: 360)
        }
    }
}

struct KnobsDemo: View {
    @State private var mix = 0.5
    @State private var pitch = 0.0
    @State private var cutoff = 1_000.0
    @State private var gate = 75.0

    private let mixSpec = KnobSpec(range: 0...1, defaultValue: 1, step: 0.01, displayScale: 100, unitSuffix: "%")
    private let pitchSpec = KnobSpec(range: -24...24, defaultValue: 0, step: 1, unitSuffix: " st", showsSign: true)
    private let cutoffSpec = KnobSpec(range: 20...20_000, defaultValue: 1_000, step: 1, unitSuffix: " Hz", isLogarithmic: true)
    private let gateSpec = KnobSpec(range: 0...100, defaultValue: 100, step: 1, unitSuffix: "%")

    var body: some View {
        DemoGroup("Knobs", note: "Drag up or down (Option for fine), scroll, or use the arrow keys. Double-click resets. Click the value to type one.") {
            HStack(spacing: 12) {
                VoltaKnob("Mix", spec: mixSpec, value: $mix)
                VoltaKnob("Pitch", spec: pitchSpec, value: $pitch)
                VoltaKnob("Cutoff", spec: cutoffSpec, value: $cutoff)
                VoltaKnob("Gate", spec: gateSpec, value: $gate).disabled(true)
            }
        }
        DemoGroup("Panel", note: "Groups a plugin section: hairline border, faint fill, no shadow.") {
            VStack(alignment: .leading, spacing: 10) {
                VoltaSectionLabel("Replay")
                HStack(spacing: 12) {
                    VoltaKnob("Mix", spec: mixSpec, value: $mix)
                    VoltaKnob("Pitch", spec: pitchSpec, value: $pitch)
                }
                Button("Replay Now") {}.buttonStyle(.voltaProminent)
            }
            .voltaPanel()
            .fixedSize()
        }
    }
}

struct DisplayDemo: View {
    @Environment(\.voltaAccent) private var accent
    private let names = ["Ada Lovelace", "Grace Hopper", "Alan Turing", "Margaret Hamilton", "Linus", ""]
    private let chips: [(String, String, Color)] = [
        ("Work", "briefcase", .blue), ("Family", "house", .green), ("Receipts", "receipt", .orange),
        ("Travel", "airplane", .purple), ("Important", "exclamationmark.circle", .red), ("Later", "clock", .pink),
    ]
    @State private var width: CGFloat = 320

    var body: some View {
        DemoGroup("Avatars", note: "The tint is picked from the name, so a person always gets the same color.") {
            HStack(spacing: 10) {
                ForEach(names, id: \.self) { VoltaAvatar(name: $0) }
                VoltaAvatar(name: "Big Avatar", size: 56)
            }
        }
        DemoGroup("Chips") {
            HStack(spacing: 7) {
                VoltaChip("Applied", symbol: "tag", color: accent)
                VoltaChip("Not applied", symbol: "tag", isApplied: false)
                VoltaChip("No icon", color: .teal)
            }
        }
        DemoGroup("Flow layout", note: "Drag the slider to see chips wrap instead of being cut off.") {
            Slider(value: $width, in: 120...560) { Text("Width") }.frame(maxWidth: 360)
            VoltaFlowLayout {
                ForEach(chips, id: \.0) { VoltaChip($0.0, symbol: $0.1, color: $0.2) }
            }
            .frame(width: width, alignment: .leading)
            .padding(8)
            .overlay(RoundedRectangle(cornerRadius: VoltaDesign.cornerRadius).strokeBorder(Color.secondary.opacity(VoltaDesign.boundaryOpacity)))
        }
    }
}

struct RichTextDemo: View {
    @StateObject private var controller = RichTextController()
    @State private var html: String?

    var body: some View {
        VStack(spacing: 0) {
            FormattingBar(controller: controller)
            VoltaDivider()
            RichTextEditor(controller: controller, initial: Self.sample) { _, _, html in self.html = html }
                .focusedObject(controller)
            VoltaDivider()
            ScrollView {
                Text(html ?? "Type in the editor to see its HTML. Plain text gives no HTML.")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            }.frame(height: 140)
        }
    }

    static let sample: NSAttributedString = {
        let text = NSMutableAttributedString(string: "Notes-style rich text\n", attributes: RichText.baseAttributes())
        text.addAttribute(.font, value: RichText.font(.title), range: NSRange(location: 0, length: text.length - 1))
        text.addAttribute(.voltaStyle, value: RichStyle.title.rawValue, range: NSRange(location: 0, length: text.length - 1))
        text.append(NSAttributedString(string: "Use the bar above or the Format menu. Lists continue when you press Return.", attributes: RichText.baseAttributes()))
        return text
    }()
}

struct HTMLDemo: View {
    @State private var query = ""
    @State private var images = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VoltaSearchField("Highlight text", text: $query).frame(maxWidth: 260)
                Toggle("Load remote images", isOn: $images)
                Spacer()
            }.padding(.horizontal, 24).padding(.vertical, 10)
            VoltaDivider()
            SafeHTMLView(html: Self.sample, query: query, allowRemoteImages: images)
        }
    }

    static let sample = """
    <h2>Untrusted HTML, shown safely</h2>
    <p>Scripts never run, nothing is stored, and the page can't reach the network unless you allow remote images.</p>
    <p>Links like <a href="https://example.com">example.com</a> open in your browser.</p>
    <script>document.body.innerHTML = "If you can read this, scripts ran."</script>
    <ul><li>No JavaScript</li><li>Strict content security policy</li><li>Non-persistent storage</li></ul>
    """
}
