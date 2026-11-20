// The C API declared in include/volta_native.h. Keep the two in sync: every @_cdecl name here
// must match a declaration there, with the same parameter types.

import AppKit
import SwiftUI
import VoltaNative

public typealias ActionFn = @convention(c) (UnsafeMutableRawPointer?) -> Void
public typealias ToggleFn = @convention(c) (UnsafeMutableRawPointer?, Bool) -> Void
public typealias TextFn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> Void
public typealias IndexFn = @convention(c) (UnsafeMutableRawPointer?, Int) -> Void

// MARK: Plumbing

/// Carries values across `MainActor.assumeIsolated`, which needs Sendable results.
private struct Unchecked<T>: @unchecked Sendable { let value: T }

/// C callers are not actor-aware, so every entry point checks it is on the main thread and then runs as main-actor code.
private func onMain<T>(_ body: @MainActor () -> T) -> T {
    precondition(Thread.isMainThread, "Volta-Native: call the C API on the main thread")
    return MainActor.assumeIsolated { Unchecked(value: body()) }.value
}

/// State a hosted control shares with C: enabled, text, on/off, selected index and progress.
@MainActor
final class HostModel: ObservableObject {
    @Published var enabled = true
    @Published var text = ""
    @Published var isOn = false
    @Published var index = 0
    var count = 0
    @Published var progress: Double? = nil
}

@MainActor
private enum Bridge {
    static var accent = Color.voltaAccent
    static let delegate = AppDelegate()
    static var modelKey = 0
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

private func string(_ pointer: UnsafePointer<CChar>?) -> String { pointer.map { String(cString: $0) } ?? "" }

private func strings(_ pointer: UnsafePointer<UnsafePointer<CChar>?>?, _ count: Int) -> [String] {
    guard let pointer, count > 0 else { return [] }
    return (0..<count).map { string(pointer[$0]) }
}

private func voltaTone(_ value: Int32) -> VoltaTone { VoltaTone(rawValue: Int(value)) ?? .neutral }

private func retained(_ object: AnyObject) -> UnsafeMutableRawPointer { Unmanaged.passRetained(object).toOpaque() }

private func view(_ pointer: UnsafeMutableRawPointer?) -> NSView? {
    pointer.map { Unmanaged<NSView>.fromOpaque($0).takeUnretainedValue() }
}

@MainActor
private func model(of pointer: UnsafeMutableRawPointer?) -> HostModel? {
    guard let view = view(pointer) else { return nil }
    return objc_getAssociatedObject(view, &Bridge.modelKey) as? HostModel
}

/// Wraps a SwiftUI view for C: applies the accent and enabled state, and attaches the model for later calls.
@MainActor
private func host<Content: View>(_ model: HostModel, @ViewBuilder _ content: @escaping () -> Content) -> UnsafeMutableRawPointer {
    let root = HostedRoot(model: model, accent: Bridge.accent, content: content)
    let hosting = NSHostingView(rootView: root)
    hosting.translatesAutoresizingMaskIntoConstraints = false
    objc_setAssociatedObject(hosting, &Bridge.modelKey, model, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    return retained(hosting)
}

private struct HostedRoot<Content: View>: View {
    @ObservedObject var model: HostModel
    let accent: Color
    let content: () -> Content
    var body: some View {
        content().disabled(!model.enabled).voltaAccent(accent).voltaControls().fixedSize(horizontal: false, vertical: true)
    }
}

/// Lets C callers keep a raw context pointer in SwiftUI closures.
private struct Callback: @unchecked Sendable {
    let context: UnsafeMutableRawPointer?
}

// MARK: App

@_cdecl("volta_app_init")
public func volta_app_init(_ name: UnsafePointer<CChar>?) {
    onMain {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.delegate = Bridge.delegate
        let appName = string(name).isEmpty ? ProcessInfo.processInfo.processName : string(name)

        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        app.mainMenu = main
    }
}

@_cdecl("volta_app_run")
public func volta_app_run() {
    onMain {
        NSApplication.shared.activate()
        NSApplication.shared.run()
    }
}

@_cdecl("volta_set_accent")
public func volta_set_accent(_ red: Double, _ green: Double, _ blue: Double) {
    onMain { Bridge.accent = Color(red: red, green: green, blue: blue) }
}

// MARK: Windows

@_cdecl("volta_window_create")
public func volta_window_create(_ title: UnsafePointer<CChar>?, _ width: Double, _ height: Double) -> UnsafeMutableRawPointer? {
    onMain {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = string(title)
        window.isReleasedWhenClosed = false
        window.center()
        return retained(window)
    }
}

@_cdecl("volta_window_set_content")
public func volta_window_set_content(_ window: UnsafeMutableRawPointer?, _ content: UnsafeMutableRawPointer?) {
    onMain {
        guard let window = window.map({ Unmanaged<NSWindow>.fromOpaque($0).takeUnretainedValue() }),
              let content = view(content) else { return }
        let container = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        let inset: CGFloat = 20
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: inset),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            content.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -inset),
            content.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -inset),
        ])
        window.contentView = container
    }
}

@_cdecl("volta_window_show")
public func volta_window_show(_ window: UnsafeMutableRawPointer?) {
    onMain { window.map { Unmanaged<NSWindow>.fromOpaque($0).takeUnretainedValue() }?.makeKeyAndOrderFront(nil) }
}

@_cdecl("volta_window_release")
public func volta_window_release(_ window: UnsafeMutableRawPointer?) {
    onMain { window.map { Unmanaged<NSWindow>.fromOpaque($0).release() } }
}

// MARK: Layout

@_cdecl("volta_stack_create")
public func volta_stack_create(_ vertical: Bool, _ spacing: Double) -> UnsafeMutableRawPointer? {
    onMain {
        let stack = NSStackView()
        stack.orientation = vertical ? .vertical : .horizontal
        stack.alignment = vertical ? .leading : .centerY
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        let model = HostModel()
        objc_setAssociatedObject(stack, &Bridge.modelKey, model, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return retained(stack)
    }
}

@_cdecl("volta_stack_add")
public func volta_stack_add(_ stack: UnsafeMutableRawPointer?, _ child: UnsafeMutableRawPointer?) {
    onMain {
        guard let stack = view(stack) as? NSStackView, let child = view(child) else { return }
        stack.addArrangedSubview(child)
    }
}

@_cdecl("volta_divider_create")
public func volta_divider_create() -> UnsafeMutableRawPointer? {
    onMain { host(HostModel()) { VoltaDivider().frame(minWidth: 200) } }
}

// MARK: Controls

@_cdecl("volta_label_create")
public func volta_label_create(_ text: UnsafePointer<CChar>?, _ style: Int32) -> UnsafeMutableRawPointer? {
    let text = string(text)
    return onMain {
        host(HostModel()) {
            switch style {
            case 1: Text(text).font(.title.weight(.semibold))
            case 2: Text(text).font(.headline)
            case 3: Text(text).font(.callout).foregroundStyle(.secondary)
            default: Text(text)
            }
        }
    }
}

@_cdecl("volta_button_create")
public func volta_button_create(_ title: UnsafePointer<CChar>?, _ kind: Int32, _ onClick: ActionFn?, _ context: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    let title = string(title)
    let callback = Callback(context: context)
    return onMain {
        host(HostModel()) {
            let button = Button(title, role: kind == 3 ? .destructive : nil) { onClick?(callback.context) }
            switch kind {
            case 1: button.buttonStyle(.voltaProminent)
            case 2: button.buttonStyle(.voltaLink)
            default: button.buttonStyle(.volta)
            }
        }
    }
}

@_cdecl("volta_checkbox_create")
public func volta_checkbox_create(_ label: UnsafePointer<CChar>?, _ isOn: Bool, _ onChange: ToggleFn?, _ context: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    let label = string(label)
    let callback = Callback(context: context)
    return onMain {
        let model = HostModel()
        model.isOn = isOn
        return host(model) {
            Toggle(label, isOn: Binding(get: { model.isOn }, set: { model.isOn = $0; onChange?(callback.context, $0) }))
                .toggleStyle(.voltaCheckbox)
        }
    }
}

@_cdecl("volta_switch_create")
public func volta_switch_create(_ label: UnsafePointer<CChar>?, _ isOn: Bool, _ onChange: ToggleFn?, _ context: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    let label = string(label)
    let callback = Callback(context: context)
    return onMain {
        let model = HostModel()
        model.isOn = isOn
        return host(model) {
            Toggle(label, isOn: Binding(get: { model.isOn }, set: { model.isOn = $0; onChange?(callback.context, $0) }))
                .toggleStyle(.voltaSwitch)
        }
    }
}

@_cdecl("volta_checkbox_is_on")
public func volta_checkbox_is_on(_ checkbox: UnsafeMutableRawPointer?) -> Bool {
    onMain { model(of: checkbox)?.isOn ?? false }
}

@MainActor
private func textBinding(_ model: HostModel, _ onChange: TextFn?, _ callback: Callback) -> Binding<String> {
    Binding(get: { model.text }, set: { value in
        guard value != model.text else { return }
        model.text = value
        value.withCString { onChange?(callback.context, $0) }
    })
}

@_cdecl("volta_text_field_create")
public func volta_text_field_create(_ placeholder: UnsafePointer<CChar>?, _ width: Double, _ onChange: TextFn?, _ context: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    let placeholder = string(placeholder)
    let callback = Callback(context: context)
    return onMain {
        let model = HostModel()
        return host(model) {
            VoltaTextField(placeholder, text: textBinding(model, onChange, callback)).frame(width: width)
        }
    }
}

@_cdecl("volta_search_field_create")
public func volta_search_field_create(_ placeholder: UnsafePointer<CChar>?, _ width: Double, _ onChange: TextFn?, _ context: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    let placeholder = string(placeholder)
    let callback = Callback(context: context)
    return onMain {
        let model = HostModel()
        return host(model) {
            VoltaSearchField(placeholder.isEmpty ? "Search" : placeholder, text: textBinding(model, onChange, callback)).frame(width: width)
        }
    }
}

@_cdecl("volta_text_area_create")
public func volta_text_area_create(_ placeholder: UnsafePointer<CChar>?, _ width: Double, _ height: Double, _ onChange: TextFn?, _ context: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    let placeholder = string(placeholder)
    let callback = Callback(context: context)
    return onMain {
        let model = HostModel()
        let minHeight = height > 0 ? height : VoltaTokens.sizeTextAreaHeight
        return host(model) {
            VoltaTextArea(placeholder, text: textBinding(model, onChange, callback), minHeight: minHeight)
                .frame(width: width, height: minHeight)
        }
    }
}

@_cdecl("volta_field_get_text")
public func volta_field_get_text(_ field: UnsafeMutableRawPointer?, _ buffer: UnsafeMutablePointer<CChar>?, _ size: Int) -> Int {
    let text = onMain { model(of: field)?.text ?? "" }
    let bytes = Array(text.utf8)
    if let buffer, size > 0 {
        let count = min(bytes.count, size - 1)
        for index in 0..<count { buffer[index] = CChar(bitPattern: bytes[index]) }
        buffer[count] = 0
    }
    return bytes.count
}

@_cdecl("volta_field_set_text")
public func volta_field_set_text(_ field: UnsafeMutableRawPointer?, _ text: UnsafePointer<CChar>?) {
    let text = string(text)
    onMain { model(of: field)?.text = text }
}

// MARK: Choices

/// Options indexed by position, so C sees plain indexes.
private func indexedOptions(_ titles: [String]) -> [VoltaOption<Int>] {
    titles.enumerated().map { VoltaOption($0.element, value: $0.offset) }
}

@MainActor
private func choiceModel(_ count: Int, _ selected: Int) -> HostModel {
    let model = HostModel()
    model.count = count
    model.index = selected < count ? selected : 0
    return model
}

@MainActor
private func indexBinding(_ model: HostModel, _ onChange: IndexFn?, _ callback: Callback) -> Binding<Int> {
    Binding(get: { model.index }, set: { value in
        guard value != model.index else { return }
        model.index = value
        onChange?(callback.context, value)
    })
}

@_cdecl("volta_segmented_create")
public func volta_segmented_create(_ titles: UnsafePointer<UnsafePointer<CChar>?>?, _ count: Int, _ selected: Int, _ onChange: IndexFn?, _ context: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    let options = indexedOptions(strings(titles, count))
    let callback = Callback(context: context)
    return onMain {
        let model = choiceModel(options.count, selected)
        return host(model) { VoltaSegmentedControl("", options: options, selection: indexBinding(model, onChange, callback)) }
    }
}

@_cdecl("volta_radio_group_create")
public func volta_radio_group_create(_ titles: UnsafePointer<UnsafePointer<CChar>?>?, _ count: Int, _ selected: Int, _ onChange: IndexFn?, _ context: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    let options = indexedOptions(strings(titles, count))
    let callback = Callback(context: context)
    return onMain {
        let model = choiceModel(options.count, selected)
        return host(model) { VoltaRadioGroup("", options: options, selection: indexBinding(model, onChange, callback)) }
    }
}

@_cdecl("volta_select_create")
public func volta_select_create(_ titles: UnsafePointer<UnsafePointer<CChar>?>?, _ count: Int, _ selected: Int, _ width: Double, _ onChange: IndexFn?, _ context: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    let options = indexedOptions(strings(titles, count))
    let callback = Callback(context: context)
    return onMain {
        let model = choiceModel(options.count, selected)
        return host(model) { VoltaSelect("", options: options, selection: indexBinding(model, onChange, callback)).frame(width: width) }
    }
}

@_cdecl("volta_selection_get")
public func volta_selection_get(_ choice: UnsafeMutableRawPointer?) -> Int {
    onMain { model(of: choice)?.index ?? 0 }
}

@_cdecl("volta_selection_set")
public func volta_selection_set(_ choice: UnsafeMutableRawPointer?, _ index: Int) {
    onMain {
        guard let model = model(of: choice), index >= 0, index < model.count else { return }
        model.index = index
    }
}

// MARK: Display

@_cdecl("volta_avatar_create")
public func volta_avatar_create(_ name: UnsafePointer<CChar>?, _ size: Double) -> UnsafeMutableRawPointer? {
    let name = string(name)
    return onMain { host(HostModel()) { VoltaAvatar(name: name, size: size > 0 ? size : VoltaTokens.sizeAvatar) } }
}

@_cdecl("volta_chip_create")
public func volta_chip_create(_ title: UnsafePointer<CChar>?, _ symbol: UnsafePointer<CChar>?, _ isApplied: Bool) -> UnsafeMutableRawPointer? {
    let title = string(title)
    let symbol = symbol.map { String(cString: $0) }
    return onMain {
        let accent = Bridge.accent
        return host(HostModel()) { VoltaChip(title, symbol: symbol, color: accent, isApplied: isApplied) }
    }
}

@_cdecl("volta_badge_create")
public func volta_badge_create(_ title: UnsafePointer<CChar>?, _ tone: Int32) -> UnsafeMutableRawPointer? {
    let title = string(title)
    let tone = voltaTone(tone)
    return onMain { host(HostModel()) { VoltaBadge(title, tone: tone) } }
}

@_cdecl("volta_status_dot_create")
public func volta_status_dot_create(_ tone: Int32, _ label: UnsafePointer<CChar>?) -> UnsafeMutableRawPointer? {
    let tone = voltaTone(tone)
    let label = label.map { String(cString: $0) }
    return onMain { host(HostModel()) { VoltaStatusDot(tone, label: label) } }
}

@_cdecl("volta_message_create")
public func volta_message_create(_ text: UnsafePointer<CChar>?, _ tone: Int32, _ width: Double) -> UnsafeMutableRawPointer? {
    let text = string(text)
    let tone = voltaTone(tone)
    return onMain { host(HostModel()) { VoltaMessage(text, tone: tone).frame(width: width) } }
}

@_cdecl("volta_tag_create")
public func volta_tag_create(_ title: UnsafePointer<CChar>?, _ onRemove: ActionFn?, _ context: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    let title = string(title)
    let callback = Callback(context: context)
    return onMain {
        host(HostModel()) { VoltaTag(title, onRemove: onRemove.map { remove in { remove(callback.context) } }) }
    }
}

// MARK: Progress

@_cdecl("volta_progress_create")
public func volta_progress_create(_ width: Double) -> UnsafeMutableRawPointer? {
    onMain {
        let model = HostModel()
        return host(model) { ProgressHost(model: model).frame(width: width) }
    }
}

private struct ProgressHost: View {
    @ObservedObject var model: HostModel
    var body: some View { VoltaProgressBar(value: model.progress) }
}

@_cdecl("volta_progress_set")
public func volta_progress_set(_ progress: UnsafeMutableRawPointer?, _ value: Double) {
    onMain { model(of: progress)?.progress = value < 0 ? nil : value }
}

@_cdecl("volta_spinner_create")
public func volta_spinner_create(_ size: Double) -> UnsafeMutableRawPointer? {
    onMain { host(HostModel()) { VoltaSpinner(size: size > 0 ? size : VoltaTokens.sizeSpinner) } }
}

// MARK: Any view

@_cdecl("volta_view_set_enabled")
public func volta_view_set_enabled(_ pointer: UnsafeMutableRawPointer?, _ enabled: Bool) {
    onMain {
        model(of: pointer)?.enabled = enabled
        if let stack = view(pointer) as? NSStackView {
            for child in stack.arrangedSubviews {
                (objc_getAssociatedObject(child, &Bridge.modelKey) as? HostModel)?.enabled = enabled
            }
        }
    }
}

@_cdecl("volta_view_release")
public func volta_view_release(_ pointer: UnsafeMutableRawPointer?) {
    onMain { pointer.map { Unmanaged<NSView>.fromOpaque($0).release() } }
}
