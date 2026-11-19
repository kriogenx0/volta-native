import SwiftUI
import AppKit

extension NSAttributedString.Key {
    public static let voltaStyle = NSAttributedString.Key("Volta.style")
    public static let voltaList = NSAttributedString.Key("Volta.list")
    public static let voltaQuote = NSAttributedString.Key("Volta.quote")
}

/// Paragraph styles, named and sized like the Notes app.
public enum RichStyle: String, CaseIterable, Sendable {
    case title, heading, subheading, body, mono
    public var size: CGFloat {
        switch self {
        case .title: return 26
        case .heading: return 20
        case .subheading: return 16
        case .body: return 14
        case .mono: return 13
        }
    }
    public var isBold: Bool { self == .title || self == .heading || self == .subheading }
    public var label: String {
        switch self {
        case .title: return "Title"
        case .heading: return "Heading"
        case .subheading: return "Subheading"
        case .body: return "Body"
        case .mono: return "Monospaced"
        }
    }
}

public enum ListKind: String, Sendable {
    case bullet, dash, number
    public func marker(_ number: Int = 1) -> String {
        switch self {
        case .bullet: return "•\t"
        case .dash: return "–\t"
        case .number: return "\(number).\t"
        }
    }
}

/// Helpers shared by the editor and the HTML export.
public enum RichText {
    public static let indentStep: CGFloat = 24
    public static let listGap: CGFloat = 24

    public static func font(_ style: RichStyle, bold: Bool = false, italic: Bool = false) -> NSFont {
        var font = style == .mono
            ? NSFont.monospacedSystemFont(ofSize: style.size, weight: .regular)
            : NSFont.systemFont(ofSize: style.size, weight: style.isBold ? .bold : .regular)
        let manager = NSFontManager.shared
        if bold && !style.isBold { font = manager.convert(font, toHaveTrait: .boldFontMask) }
        if italic { font = manager.convert(font, toHaveTrait: .italicFontMask) }
        return font
    }

    public static func baseAttributes() -> [NSAttributedString.Key: Any] {
        [.font: font(.body), .foregroundColor: NSColor.labelColor, .voltaStyle: RichStyle.body.rawValue]
    }

    public static func paragraphStyle(indent: CGFloat, isList: Bool) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = 4
        style.firstLineHeadIndent = indent
        style.headIndent = indent + (isList ? listGap : 0)
        if isList { style.tabStops = [NSTextTab(textAlignment: .left, location: indent + listGap)] }
        return style
    }

    public static func indent(of attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        (attributes[.paragraphStyle] as? NSParagraphStyle)?.firstLineHeadIndent ?? 0
    }

    /// Colors follow the appearance, so they are applied for display and never saved.
    public static func restyleColors(_ text: NSMutableAttributedString) {
        let whole = NSRange(location: 0, length: text.length)
        text.addAttribute(.foregroundColor, value: NSColor.labelColor, range: whole)
        text.enumerateAttribute(.voltaQuote, in: whole) { value, range, _ in
            if value != nil { text.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: range) }
        }
    }

    public static func archive(_ text: NSAttributedString) -> Data? {
        let copy = NSMutableAttributedString(attributedString: text)
        copy.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: copy.length))
        return try? NSKeyedArchiver.archivedData(withRootObject: copy, requiringSecureCoding: true)
    }

    public static func unarchive(_ data: Data) -> NSMutableAttributedString? {
        guard let text = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data) else { return nil }
        let copy = NSMutableAttributedString(attributedString: text)
        restyleColors(copy)
        return copy
    }

    public static func markerLength(in text: NSString, paragraph: NSRange) -> Int {
        let tab = text.range(of: "\t", options: [], range: paragraph)
        return tab.location == NSNotFound ? 0 : tab.location - paragraph.location + 1
    }

    public static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    public static func safeLink(_ value: Any?) -> String? {
        let url = (value as? URL) ?? (value as? String).flatMap(URL.init(string:))
        guard let url, ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url.absoluteString
    }

    /// HTML for the formatted body, or nil when the text carries no formatting and should go out as plain text.
    public static func html(from text: NSAttributedString) -> String? {
        let string = text.string as NSString
        guard string.length > 0 else { return nil }
        var hasFormatting = false
        var blocks: [String] = []
        var openList: (kind: ListKind, tag: String)?
        func closeList() {
            if let list = openList { blocks.append("</\(list.tag)>"); openList = nil }
        }
        string.enumerateSubstrings(in: NSRange(location: 0, length: string.length), options: [.byParagraphs, .substringNotRequired]) { _, range, enclosing, _ in
            let anchor = min(range.length > 0 ? range.location : enclosing.location, max(0, string.length - 1))
            let attributes = text.attributes(at: anchor, effectiveRange: nil)
            let style = (attributes[.voltaStyle] as? String).flatMap(RichStyle.init(rawValue:)) ?? .body
            let list = (attributes[.voltaList] as? String).flatMap(ListKind.init(rawValue:))
            let isQuote = attributes[.voltaQuote] != nil
            let indent = Int((indent(of: attributes) / indentStep).rounded())
            if range.length == 0 {
                closeList()
                blocks.append("<div><br></div>")
                return
            }
            var content = NSRange(location: range.location, length: range.length)
            if list != nil {
                let skip = markerLength(in: string, paragraph: range)
                content = NSRange(location: range.location + skip, length: range.length - skip)
            }
            var inline = ""
            text.enumerateAttributes(in: content) { runAttributes, runRange, _ in
                var piece = escape(string.substring(with: runRange))
                if let font = runAttributes[.font] as? NSFont {
                    let traits = NSFontManager.shared.traits(of: font)
                    if traits.contains(.boldFontMask) && !style.isBold { piece = "<b>\(piece)</b>"; hasFormatting = true }
                    if traits.contains(.italicFontMask) { piece = "<i>\(piece)</i>"; hasFormatting = true }
                    if font.isFixedPitch && style != .mono { piece = "<code>\(piece)</code>"; hasFormatting = true }
                }
                if (runAttributes[.underlineStyle] as? Int ?? 0) != 0 { piece = "<u>\(piece)</u>"; hasFormatting = true }
                if (runAttributes[.strikethroughStyle] as? Int ?? 0) != 0 { piece = "<s>\(piece)</s>"; hasFormatting = true }
                if let link = safeLink(runAttributes[.link]) { piece = "<a href=\"\(escape(link))\">\(piece)</a>"; hasFormatting = true }
                inline += piece
            }
            if style != .body || list != nil || isQuote || indent > 0 { hasFormatting = true }
            if let list {
                let tag = list == .number ? "ol" : "ul"
                if openList?.kind != list || openList?.tag != tag {
                    closeList()
                    let type = list == .dash ? " list-style-type: '– ';" : ""
                    blocks.append("<\(tag) style=\"margin: 0 0 4px \(indent * Int(indentStep))px; padding-left: 24px;\(type)\">")
                    openList = (list, tag)
                }
                blocks.append("<li>\(inline)</li>")
                return
            }
            closeList()
            let margin = indent > 0 ? " margin-left: \(indent * Int(indentStep))px;" : ""
            switch (style, isQuote) {
            case (_, true):
                blocks.append("<blockquote style=\"margin: 0 0 4px \(indent * Int(indentStep))px; padding-left: 12px; border-left: 3px solid #c8c8c8; color: #666;\">\(inline)</blockquote>")
            case (.title, _): blocks.append("<h1 style=\"font-size: 26px; margin: 0 0 6px;\(margin)\">\(inline)</h1>")
            case (.heading, _): blocks.append("<h2 style=\"font-size: 20px; margin: 0 0 6px;\(margin)\">\(inline)</h2>")
            case (.subheading, _): blocks.append("<h3 style=\"font-size: 16px; margin: 0 0 6px;\(margin)\">\(inline)</h3>")
            case (.mono, _): blocks.append("<div style=\"font-family: Menlo, Courier, monospace; font-size: 13px; white-space: pre-wrap;\(margin)\">\(inline)</div>")
            case (.body, _): blocks.append("<div style=\"\(margin)\">\(inline)</div>")
            }
        }
        closeList()
        guard hasFormatting else { return nil }
        return "<div style=\"font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', Arial, sans-serif; font-size: 14px; line-height: 1.45;\">"
            + blocks.joined(separator: "\n") + "</div>"
    }
}

/// Applies Notes-style formatting to the text view of a `RichTextEditor`.
@MainActor
public final class RichTextController: ObservableObject {
    public weak var textView: NSTextView?

    public init() {}

    private var storage: NSTextStorage? { textView?.textStorage }

    // MARK: Character formatting

    public func toggleBold() { toggleTrait(.boldFontMask) }
    public func toggleItalic() { toggleTrait(.italicFontMask) }

    private func toggleTrait(_ trait: NSFontTraitMask) {
        guard let view = textView, let storage else { return }
        let manager = NSFontManager.shared
        let range = view.selectedRange()
        if range.length == 0 {
            var typing = view.typingAttributes
            let font = (typing[.font] as? NSFont) ?? RichText.font(.body)
            typing[.font] = manager.traits(of: font).contains(trait) ? manager.convert(font, toNotHaveTrait: trait) : manager.convert(font, toHaveTrait: trait)
            view.typingAttributes = typing
            return
        }
        var allHave = true
        storage.enumerateAttribute(.font, in: range) { value, _, _ in
            if !manager.traits(of: (value as? NSFont) ?? RichText.font(.body)).contains(trait) { allHave = false }
        }
        guard view.shouldChangeText(in: range, replacementString: nil) else { return }
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range) { value, sub, _ in
            let font = (value as? NSFont) ?? RichText.font(.body)
            storage.addAttribute(.font, value: allHave ? manager.convert(font, toNotHaveTrait: trait) : manager.convert(font, toHaveTrait: trait), range: sub)
        }
        storage.endEditing()
        view.didChangeText()
    }

    public func toggleUnderline() { toggleLine(.underlineStyle) }
    public func toggleStrikethrough() { toggleLine(.strikethroughStyle) }

    private func toggleLine(_ key: NSAttributedString.Key) {
        guard let view = textView, let storage else { return }
        let range = view.selectedRange()
        if range.length == 0 {
            var typing = view.typingAttributes
            if (typing[key] as? Int ?? 0) != 0 { typing.removeValue(forKey: key) } else { typing[key] = NSUnderlineStyle.single.rawValue }
            view.typingAttributes = typing
            return
        }
        var allHave = true
        storage.enumerateAttribute(key, in: range) { value, _, _ in if (value as? Int ?? 0) == 0 { allHave = false } }
        guard view.shouldChangeText(in: range, replacementString: nil) else { return }
        if allHave { storage.removeAttribute(key, range: range) }
        else { storage.addAttribute(key, value: NSUnderlineStyle.single.rawValue, range: range) }
        view.didChangeText()
    }

    // MARK: Paragraph styles

    public func setStyle(_ style: RichStyle) {
        guard let view = textView, let storage else { return }
        let manager = NSFontManager.shared
        for paragraph in paragraphRanges().reversed() {
            guard view.shouldChangeText(in: paragraph, replacementString: nil) else { continue }
            storage.beginEditing()
            storage.addAttribute(.voltaStyle, value: style.rawValue, range: paragraph)
            storage.enumerateAttribute(.font, in: paragraph) { value, sub, _ in
                let old = (value as? NSFont) ?? RichText.font(.body)
                let italic = manager.traits(of: old).contains(.italicFontMask)
                storage.addAttribute(.font, value: RichText.font(style, italic: italic), range: sub)
            }
            storage.endEditing()
        }
        var typing = view.typingAttributes
        typing[.font] = RichText.font(style)
        typing[.voltaStyle] = style.rawValue
        view.typingAttributes = typing
        view.didChangeText()
    }

    public func toggleList(_ kind: ListKind) {
        guard let view = textView, let storage else { return }
        let paragraphs = paragraphRanges()
        let removing = paragraphs.allSatisfy { listKind(at: $0.location) == kind }
        let range = NSRange(location: paragraphs.first?.location ?? 0,
                            length: (paragraphs.last.map(NSMaxRange) ?? 0) - (paragraphs.first?.location ?? 0))
        guard view.shouldChangeText(in: range, replacementString: nil) else { return }
        storage.beginEditing()
        for paragraph in paragraphs.reversed() {
            removeMarker(paragraph)
            if !removing { addMarker(kind, to: currentParagraph(at: paragraph.location)) }
        }
        storage.endEditing()
        renumber()
        view.didChangeText()
    }

    public func toggleQuote() {
        guard let view = textView, let storage else { return }
        let paragraphs = paragraphRanges()
        let removing = paragraphs.allSatisfy { storage.attribute(.voltaQuote, at: $0.location, effectiveRange: nil) != nil }
        guard view.shouldChangeText(in: NSRange(location: paragraphs.first?.location ?? 0, length: 0), replacementString: nil) else { return }
        storage.beginEditing()
        for paragraph in paragraphs {
            let attributes = storage.attributes(at: paragraph.location, effectiveRange: nil)
            let level = RichText.indent(of: attributes)
            if removing {
                storage.removeAttribute(.voltaQuote, range: paragraph)
                storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: paragraph)
                setIndent(max(0, level - RichText.indentStep), for: paragraph)
            } else {
                storage.addAttribute(.voltaQuote, value: "1", range: paragraph)
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: paragraph)
                setIndent(level + RichText.indentStep, for: paragraph)
            }
        }
        storage.endEditing()
        view.didChangeText()
    }

    public func indent(by steps: Int) {
        guard let view = textView, let storage else { return }
        let paragraphs = paragraphRanges()
        guard view.shouldChangeText(in: NSRange(location: paragraphs.first?.location ?? 0, length: 0), replacementString: nil) else { return }
        storage.beginEditing()
        for paragraph in paragraphs {
            let level = RichText.indent(of: storage.attributes(at: paragraph.location, effectiveRange: nil))
            setIndent(min(max(0, level + CGFloat(steps) * RichText.indentStep), RichText.indentStep * 10), for: paragraph)
        }
        storage.endEditing()
        view.didChangeText()
    }

    // MARK: Links

    public func addLink() {
        guard let view = textView, let storage else { return }
        let range = view.selectedRange()
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "https://example.com"
        if range.length > 0, let existing = storage.attribute(.link, at: range.location, effectiveRange: nil) {
            field.stringValue = ((existing as? URL)?.absoluteString) ?? (existing as? String) ?? ""
        }
        let alert = NSAlert()
        alert.messageText = "Add Link"
        alert.informativeText = range.length > 0 ? "Enter the address the selected text should open." : "Enter an address to insert as a link."
        alert.accessoryView = field
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        var value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            if range.length > 0, view.shouldChangeText(in: range, replacementString: nil) {
                storage.removeAttribute(.link, range: range); view.didChangeText()
            }
            return
        }
        if !value.contains(":") { value = (value.contains("@") && !value.contains("/") ? "mailto:" : "https://") + value }
        guard let url = URL(string: value), RichText.safeLink(url) != nil else { return }
        if range.length > 0 {
            guard view.shouldChangeText(in: range, replacementString: nil) else { return }
            storage.addAttribute(.link, value: url, range: range)
        } else {
            var attributes = view.typingAttributes
            attributes[.link] = url
            let text = NSAttributedString(string: url.absoluteString, attributes: attributes)
            guard view.shouldChangeText(in: range, replacementString: text.string) else { return }
            storage.replaceCharacters(in: range, with: text)
            view.setSelectedRange(NSRange(location: range.location + text.length, length: 0))
        }
        view.didChangeText()
    }

    // MARK: Lists and Return

    /// Continues a list on Return, and ends it when the item is empty.
    func handleReturn() -> Bool {
        guard let view = textView, let storage else { return false }
        let selection = view.selectedRange()
        guard selection.length == 0 else { return false }
        let text = storage.string as NSString
        let paragraph = text.paragraphRange(for: selection)
        guard let kind = listKind(at: paragraph.location) else { return false }
        let marker = RichText.markerLength(in: text, paragraph: paragraph)
        let body = text.substring(with: paragraph).trimmingCharacters(in: .newlines)
        if body.count <= marker {
            guard view.shouldChangeText(in: paragraph, replacementString: nil) else { return true }
            storage.beginEditing(); removeMarker(paragraph); storage.endEditing()
            view.didChangeText()
            return true
        }
        let attributes = storage.attributes(at: paragraph.location, effectiveRange: nil)
        let insert = NSAttributedString(string: "\n" + kind.marker(), attributes: attributes)
        guard view.shouldChangeText(in: selection, replacementString: insert.string) else { return true }
        storage.replaceCharacters(in: selection, with: insert)
        view.setSelectedRange(NSRange(location: selection.location + insert.length, length: 0))
        renumber()
        view.didChangeText()
        return true
    }

    /// Backspace inside a list marker removes the list formatting instead of eating half the marker.
    func shouldBlockMarkerDeletion(range: NSRange, replacement: String?) -> Bool {
        guard let view = textView, let storage, replacement == "" || replacement == nil, range.length > 0 else { return false }
        let text = storage.string as NSString
        guard range.location < text.length else { return false }
        let paragraph = text.paragraphRange(for: NSRange(location: range.location, length: 0))
        guard listKind(at: paragraph.location) != nil else { return false }
        let marker = RichText.markerLength(in: text, paragraph: paragraph)
        guard range.location < paragraph.location + marker, NSMaxRange(range) <= paragraph.location + marker else { return false }
        storage.beginEditing(); removeMarker(paragraph); storage.endEditing()
        view.didChangeText()
        return true
    }

    /// Keeps numbered items counting 1, 2, 3 within each run at the same indent.
    func renumber() {
        guard let storage else { return }
        let text = storage.string as NSString
        var location = 0
        var counters: [Int: Int] = [:]
        var previousWasNumber = false
        var previousIndent = -1
        while location < text.length {
            let paragraph = (storage.string as NSString).paragraphRange(for: NSRange(location: location, length: 0))
            let attributes = storage.attributes(at: paragraph.location, effectiveRange: nil)
            var nextLocation = NSMaxRange(paragraph)
            if (attributes[.voltaList] as? String) == ListKind.number.rawValue {
                let indent = Int(RichText.indent(of: attributes))
                if !previousWasNumber || indent != previousIndent { counters = [:] }
                let number = (counters[indent] ?? 0) + 1
                counters[indent] = number
                let current = storage.string as NSString
                let length = RichText.markerLength(in: current, paragraph: paragraph)
                let expected = ListKind.number.marker(number)
                if length > 0, current.substring(with: NSRange(location: paragraph.location, length: length)) != expected {
                    var markerAttributes = attributes
                    markerAttributes[.voltaList] = ListKind.number.rawValue
                    storage.replaceCharacters(in: NSRange(location: paragraph.location, length: length),
                                              with: NSAttributedString(string: expected, attributes: markerAttributes))
                    nextLocation += expected.count - length
                }
                previousWasNumber = true
                previousIndent = indent
            } else {
                previousWasNumber = false
                previousIndent = -1
            }
            location = nextLocation
        }
    }

    // MARK: Helpers

    private func paragraphRanges() -> [NSRange] {
        guard let view = textView, let storage else { return [] }
        let text = storage.string as NSString
        guard text.length > 0 else { return [NSRange(location: 0, length: 0)] }
        var selection = view.selectedRange()
        selection.location = min(selection.location, text.length)
        let covering = text.paragraphRange(for: selection)
        var ranges: [NSRange] = []
        text.enumerateSubstrings(in: covering, options: [.byParagraphs, .substringNotRequired]) { _, _, enclosing, _ in ranges.append(enclosing) }
        return ranges.isEmpty ? [covering] : ranges
    }

    private func currentParagraph(at location: Int) -> NSRange {
        guard let storage else { return NSRange(location: 0, length: 0) }
        return (storage.string as NSString).paragraphRange(for: NSRange(location: min(location, (storage.string as NSString).length), length: 0))
    }

    private func listKind(at location: Int) -> ListKind? {
        guard let storage, location < storage.length else { return nil }
        return (storage.attribute(.voltaList, at: location, effectiveRange: nil) as? String).flatMap(ListKind.init(rawValue:))
    }

    private func setIndent(_ indent: CGFloat, for paragraph: NSRange) {
        guard let storage else { return }
        let isList = listKind(at: paragraph.location) != nil
        storage.addAttribute(.paragraphStyle, value: RichText.paragraphStyle(indent: indent, isList: isList), range: paragraph)
    }

    private func addMarker(_ kind: ListKind, to paragraph: NSRange) {
        guard let storage else { return }
        var attributes = storage.length > paragraph.location ? storage.attributes(at: paragraph.location, effectiveRange: nil) : RichText.baseAttributes()
        attributes[.voltaList] = kind.rawValue
        storage.insert(NSAttributedString(string: kind.marker(), attributes: attributes), at: paragraph.location)
        let updated = currentParagraph(at: paragraph.location)
        storage.addAttribute(.voltaList, value: kind.rawValue, range: updated)
        setIndent(RichText.indent(of: attributes), for: updated)
    }

    private func removeMarker(_ paragraph: NSRange) {
        guard let storage, listKind(at: paragraph.location) != nil else { return }
        let text = storage.string as NSString
        let length = RichText.markerLength(in: text, paragraph: paragraph)
        if length > 0 { storage.deleteCharacters(in: NSRange(location: paragraph.location, length: length)) }
        let updated = currentParagraph(at: paragraph.location)
        let indent = RichText.indent(of: storage.length > updated.location ? storage.attributes(at: updated.location, effectiveRange: nil) : [:])
        storage.removeAttribute(.voltaList, range: updated)
        storage.addAttribute(.paragraphStyle, value: RichText.paragraphStyle(indent: indent, isList: false), range: updated)
    }
}

/// A Notes-style rich text editor. Reports plain text, an archive for saving, and HTML (nil when unformatted).
public struct RichTextEditor: NSViewRepresentable {
    let controller: RichTextController
    let initial: NSAttributedString
    var onChange: (_ plain: String, _ archive: Data?, _ html: String?) -> Void

    public init(controller: RichTextController, initial: NSAttributedString = NSAttributedString(string: "", attributes: RichText.baseAttributes()),
                onChange: @escaping (_ plain: String, _ archive: Data?, _ html: String?) -> Void) {
        self.controller = controller
        self.initial = initial
        self.onChange = onChange
    }

    public func makeCoordinator() -> Coordinator { Coordinator(controller: controller, onChange: onChange) }

    public func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        guard let view = scroll.documentView as? NSTextView else { return scroll }
        view.isRichText = true
        view.allowsUndo = true
        view.importsGraphics = false
        view.drawsBackground = false
        view.textContainerInset = NSSize(width: 16, height: 16)
        view.isAutomaticSpellingCorrectionEnabled = true
        view.isContinuousSpellCheckingEnabled = true
        view.isAutomaticLinkDetectionEnabled = true
        view.font = RichText.font(.body)
        view.typingAttributes = RichText.baseAttributes()
        view.delegate = context.coordinator
        view.textStorage?.setAttributedString(initial)
        controller.textView = view
        context.coordinator.textView = view
        return scroll
    }

    public func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.onChange = onChange
    }

    public final class Coordinator: NSObject, NSTextViewDelegate {
        let controller: RichTextController
        var onChange: (String, Data?, String?) -> Void
        weak var textView: NSTextView?

        init(controller: RichTextController, onChange: @escaping (String, Data?, String?) -> Void) {
            self.controller = controller
            self.onChange = onChange
        }

        public func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView, let storage = view.textStorage else { return }
            onChange(view.string, RichText.archive(storage), RichText.html(from: storage))
        }

        public func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
            return MainActor.assumeIsolated { controller.handleReturn() }
        }

        public func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String?) -> Bool {
            !MainActor.assumeIsolated { controller.shouldBlockMarkerDeletion(range: range, replacement: replacementString) }
        }
    }
}

/// The row of formatting buttons above the editor. Shortcuts match the Notes app and live in the Format menu.
public struct FormattingBar: View {
    @ObservedObject var controller: RichTextController

    public init(controller: RichTextController) { self.controller = controller }

    public var body: some View {
        HStack(spacing: 2) {
            Menu {
                ForEach(RichStyle.allCases, id: \.self) { style in
                    Button(style.label) { controller.setStyle(style) }
                }
            } label: { Image(systemName: "textformat").frame(width: 20, height: 20) }
                .menuStyle(.borderlessButton).tint(.secondary).fixedSize().help("Paragraph style").accessibilityLabel("Paragraph style")
            divider
            button("bold", "Bold (⌘B)") { controller.toggleBold() }
            button("italic", "Italic (⌘I)") { controller.toggleItalic() }
            button("underline", "Underline (⌘U)") { controller.toggleUnderline() }
            button("strikethrough", "Strikethrough (⇧⌘X)") { controller.toggleStrikethrough() }
            divider
            button("list.bullet", "Bulleted list (⇧⌘7)") { controller.toggleList(.bullet) }
            button("list.dash", "Dashed list (⇧⌘8)") { controller.toggleList(.dash) }
            button("list.number", "Numbered list (⇧⌘9)") { controller.toggleList(.number) }
            button("text.quote", "Block quote (⌘')") { controller.toggleQuote() }
            divider
            button("decrease.indent", "Decrease indent (⌘[)") { controller.indent(by: -1) }
            button("increase.indent", "Increase indent (⌘])") { controller.indent(by: 1) }
            divider
            button("link", "Add link (⌘K)") { controller.addLink() }
            Spacer()
        }.foregroundStyle(.secondary).padding(.horizontal, 22).padding(.vertical, 4)
    }

    private var divider: some View {
        Divider().frame(height: 14).padding(.horizontal, 4)
    }

    private func button(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 20, height: 20).padding(3) }
            .buttonStyle(VoltaHoverButtonStyle()).help(help).accessibilityLabel(help)
    }
}

/// The Format menu, with the same keystrokes as the Notes app.
public struct FormatCommands: Commands {
    @FocusedObject private var rich: RichTextController?

    public init() {}

    public var body: some Commands {
        CommandMenu("Format") {
            Group {
                Button("Bold") { rich?.toggleBold() }.keyboardShortcut("b", modifiers: .command)
                Button("Italic") { rich?.toggleItalic() }.keyboardShortcut("i", modifiers: .command)
                Button("Underline") { rich?.toggleUnderline() }.keyboardShortcut("u", modifiers: .command)
                Button("Strikethrough") { rich?.toggleStrikethrough() }.keyboardShortcut("x", modifiers: [.command, .shift])
            }
            Divider()
            Group {
                Button("Title") { rich?.setStyle(.title) }.keyboardShortcut("t", modifiers: [.command, .shift])
                Button("Heading") { rich?.setStyle(.heading) }.keyboardShortcut("h", modifiers: [.command, .shift])
                Button("Subheading") { rich?.setStyle(.subheading) }.keyboardShortcut("j", modifiers: [.command, .shift])
                Button("Body") { rich?.setStyle(.body) }.keyboardShortcut("b", modifiers: [.command, .shift])
                Button("Monospaced") { rich?.setStyle(.mono) }.keyboardShortcut("m", modifiers: [.command, .shift])
            }
            Divider()
            Group {
                Button("Bulleted List") { rich?.toggleList(.bullet) }.keyboardShortcut("7", modifiers: [.command, .shift])
                Button("Dashed List") { rich?.toggleList(.dash) }.keyboardShortcut("8", modifiers: [.command, .shift])
                Button("Numbered List") { rich?.toggleList(.number) }.keyboardShortcut("9", modifiers: [.command, .shift])
                Button("Block Quote") { rich?.toggleQuote() }.keyboardShortcut("'", modifiers: .command)
            }
            Divider()
            Group {
                Button("Increase Indent") { rich?.indent(by: 1) }.keyboardShortcut("]", modifiers: .command)
                Button("Decrease Indent") { rich?.indent(by: -1) }.keyboardShortcut("[", modifiers: .command)
                Button("Add Link…") { rich?.addLink() }.keyboardShortcut("k", modifiers: .command)
            }
        }
    }
}
