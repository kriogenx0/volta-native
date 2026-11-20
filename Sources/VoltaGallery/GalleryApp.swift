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
    case theme = "Theme"
    case buttons = "Buttons"
    case checkboxes = "Checkboxes"
    case fields = "Fields"
    case choices = "Switches and choices"
    case status = "Status and progress"
    case knobs = "Knobs and panels"
    case display = "Avatars and chips"
    case empty = "Empty state"
    case richText = "Rich text"
    case html = "Safe HTML"

    var id: Self { self }
    var symbol: String {
        switch self {
        case .tokens: return "swatchpalette"
        case .theme: return "paintpalette"
        case .buttons: return "button.horizontal"
        case .checkboxes: return "checkmark.square"
        case .fields: return "character.cursor.ibeam"
        case .choices: return "switch.2"
        case .status: return "gauge.with.dots.needle.33percent"
        case .knobs: return "dial.medium"
        case .display: return "person.crop.circle"
        case .empty: return "tray"
        case .richText: return "textformat"
        case .html: return "doc.richtext"
        }
    }
}

struct GalleryView: View {
    @State private var section: GallerySection? = .tokens
    @State private var theme = VoltaTheme.load()

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
                    Picker("Appearance", selection: $theme.appearance) {
                        ForEach(VoltaTheme.Appearance.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).fixedSize()
                }
                .padding(.horizontal, 24).padding(.vertical, 14)
                VoltaDivider()
                Group {
                    switch section ?? .tokens {
                    case .tokens: ScrollView { TokensDemo().padding(24) }
                    case .theme: ScrollView { ThemeDemo(theme: $theme).padding(24) }
                    case .buttons: ScrollView { ButtonsDemo().padding(24) }
                    case .checkboxes: ScrollView { CheckboxesDemo().padding(24) }
                    case .fields: ScrollView { FieldsDemo().padding(24) }
                    case .choices: ScrollView { ChoicesDemo().padding(24) }
                    case .status: ScrollView { StatusDemo().padding(24) }
                    case .knobs: ScrollView { KnobsDemo().padding(24) }
                    case .display: ScrollView { DisplayDemo().padding(24) }
                    case .empty: VoltaEmptyState(icon: "tray", title: "Nothing here yet", subtitle: "Views with no content show this instead of a blank pane.")
                    case .richText: RichTextDemo()
                    case .html: HTMLDemo()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(VoltaCanvas())
            .voltaControls()
        }
        .voltaTheme(theme)
        .preferredColorScheme(theme.colorScheme)
        .onChange(of: theme) { _, newTheme in newTheme.save() }
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

struct ThemeDemo: View {
    @Binding var theme: VoltaTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
        DemoGroup("Theme", note: "System follows macOS light and dark mode. Pick colors to override the appearance's own; the gallery saves the theme with VoltaTheme.save().") {
            VoltaThemePicker(theme: $theme).frame(maxWidth: 360)
        }
        DemoGroup("Preview") {
            HStack(spacing: 16) {
                Button("Standard") {}
                Button("Prominent") {}.buttonStyle(VoltaProminentButtonStyle())
                Toggle("Checkbox", isOn: .constant(true))
                VoltaChip("Chip")
            }
            .voltaPanel()
        }
        }
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
        DemoGroup("Accent", note: "The default comes from tokens.json. Apps and views can override it with .voltaAccent(_:), as the Theme section does.") {
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
    @State private var notes = ""

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
        DemoGroup("Text area", note: "Same chrome as a text field, for multi-line input.") {
            VoltaTextArea("Notes", text: $notes, prompt: "Add a note").frame(maxWidth: 360)
        }
    }
}

enum Density: String, CaseIterable { case compact = "Compact", regular = "Regular", spacious = "Spacious" }

struct ChoicesDemo: View {
    @State private var notifications = true
    @State private var sounds = false
    @State private var view = "list"
    @State private var density = Density.regular
    @State private var sort = "date"

    private let views = [VoltaOption("List", value: "list", symbol: "list.bullet"),
                         VoltaOption("Grid", value: "grid", symbol: "square.grid.2x2"),
                         VoltaOption("Columns", value: "columns", symbol: "rectangle.split.3x1")]
    private let sorts = [VoltaOption("Date", value: "date"), VoltaOption("Name", value: "name"),
                         VoltaOption("Size", value: "size"), VoltaOption("Kind", value: "kind")]

    var body: some View {
        DemoGroup("Switches", note: "For settings that apply at once. The whole row is the click target.") {
            VStack(alignment: .leading, spacing: 2) {
                Toggle("Notifications", isOn: $notifications).toggleStyle(.voltaSwitch)
                Toggle("Play sounds", isOn: $sounds).toggleStyle(.voltaSwitch)
                Toggle("Disabled", isOn: .constant(true)).toggleStyle(.voltaSwitch).disabled(true)
            }.frame(maxWidth: 320)
        }
        DemoGroup("Segmented control", note: "The selected segment is raised; the others darken on hover.") {
            VoltaSegmentedControl("View", options: views, selection: $view)
            VoltaSegmentedControl("Density", options: Density.allCases.map { VoltaOption($0.rawValue, value: $0) }, selection: $density)
            VoltaSegmentedControl("Disabled", options: views, selection: .constant("grid")).disabled(true)
        }
        DemoGroup("Radio group") {
            VoltaRadioGroup("Density", options: Density.allCases.map { VoltaOption($0.rawValue, value: $0) }, selection: $density)
        }
        DemoGroup("Select", note: "Opens a native menu with the current choice over the control.") {
            VoltaSelect("Sort by", options: sorts, selection: $sort).frame(maxWidth: 220)
            VoltaSelect("Disabled", options: sorts, selection: .constant("name")).frame(maxWidth: 220).disabled(true)
        }
    }
}

struct StatusDemo: View {
    @State private var progress = 0.35

    var body: some View {
        DemoGroup("Badges", note: "Info follows the accent. The others keep their meaning in every app.") {
            HStack(spacing: 8) {
                VoltaBadge("Draft")
                VoltaBadge("New", tone: .info)
                VoltaBadge("Paid", tone: .success)
                VoltaBadge("Due soon", tone: .warning)
                VoltaBadge("Overdue", tone: .danger)
            }
        }
        DemoGroup("Status dots") {
            HStack(spacing: 18) {
                VoltaStatusDot(.neutral, label: "Idle")
                VoltaStatusDot(.info, label: "Syncing")
                VoltaStatusDot(.success, label: "Online")
                VoltaStatusDot(.warning, label: "Degraded")
                VoltaStatusDot(.danger, label: "Offline")
            }
        }
        DemoGroup("Messages") {
            VStack(spacing: 8) {
                VoltaMessage("Your changes were saved.", tone: .success)
                VoltaMessage("Remote images are blocked for this message.", tone: .info)
                VoltaMessage("Storage is almost full.", tone: .warning)
                VoltaMessage("Couldn't reach the server. Check your connection and try again.", tone: .danger)
            }.frame(maxWidth: 440)
        }
        DemoGroup("Progress", note: "Pass nil while the amount of work is unknown.") {
            VStack(alignment: .leading, spacing: 12) {
                VoltaProgressBar(value: progress)
                Slider(value: $progress, in: 0...1) { Text("Progress") }
                VoltaProgressBar(value: nil)
            }.frame(maxWidth: 360)
        }
        DemoGroup("Spinners") {
            HStack(spacing: 20) {
                VoltaSpinner(size: 14)
                VoltaSpinner()
                VoltaSpinner(size: 32)
            }
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
    @State private var tags = ["design", "swift", "audio", "macOS"]

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
        DemoGroup("Tags", note: "Values the user added. The remove button darkens on hover.") {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    VoltaTag(tag) { withAnimation(VoltaDesign.animation) { tags.removeAll { $0 == tag } } }
                }
                VoltaTag("Read-only")
                if tags.count < 4 {
                    Button("Reset") { tags = ["design", "swift", "audio", "macOS"] }.buttonStyle(.voltaLink)
                }
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
