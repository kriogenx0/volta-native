import XCTest
import AppKit
@testable import VoltaNative

@MainActor
final class RichTextTests: XCTestCase {
    private func editor(_ text: String) -> (RichTextController, NSTextView) {
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        view.isRichText = true
        view.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: RichText.baseAttributes()))
        let controller = RichTextController()
        controller.textView = view
        return (controller, view)
    }

    func testPlainTextHasNoHTMLAndIsSentAsPlain() {
        let (_, view) = editor("Just words\nand more")
        XCTAssertNil(RichText.html(from: view.textStorage!))
    }

    func testBoldItalicUnderlineAndLinkBecomeHTMLWithEscaping() throws {
        let (controller, view) = editor("a < b bold link")
        view.setSelectedRange(NSRange(location: 6, length: 4))
        controller.toggleBold()
        view.setSelectedRange(NSRange(location: 11, length: 4))
        controller.toggleUnderline()
        view.textStorage?.addAttribute(.link, value: URL(string: "https://example.com/?a=1&b=2")!, range: NSRange(location: 11, length: 4))
        view.textStorage?.addAttribute(.link, value: URL(string: "javascript:alert(1)")!, range: NSRange(location: 0, length: 1))
        let html = try XCTUnwrap(RichText.html(from: view.textStorage!))
        XCTAssertTrue(html.contains("a &lt; b "))
        XCTAssertTrue(html.contains("<b>bold</b>"))
        XCTAssertTrue(html.contains("<a href=\"https://example.com/?a=1&amp;b=2\"><u>link</u></a>"))
        XCTAssertFalse(html.contains("javascript"))
        controller.toggleBold()
        view.setSelectedRange(NSRange(location: 6, length: 4))
        controller.toggleBold()
        XCTAssertNil(RichText.html(from: NSAttributedString(string: "x", attributes: RichText.baseAttributes())))
    }

    func testStylesListsAndQuotesBuildBlocks() throws {
        let (controller, view) = editor("Heading\nfirst\nsecond\nquoted")
        view.setSelectedRange(NSRange(location: 0, length: 0))
        controller.setStyle(.heading)
        view.setSelectedRange(NSRange(location: 8, length: 12))
        controller.toggleList(.number)
        XCTAssertEqual(view.string, "Heading\n1.\tfirst\n2.\tsecond\nquoted")
        view.setSelectedRange(NSRange(location: view.string.count, length: 0))
        controller.toggleQuote()
        let html = try XCTUnwrap(RichText.html(from: view.textStorage!))
        XCTAssertTrue(html.contains("<h2"))
        XCTAssertTrue(html.contains("<ol"))
        XCTAssertTrue(html.contains("<li>first</li>"))
        XCTAssertTrue(html.contains("<li>second</li>"))
        XCTAssertTrue(html.contains("<blockquote"))
        XCTAssertFalse(html.contains("1.\t"))
    }

    func testReturnContinuesAndEndsLists() {
        let (controller, view) = editor("item")
        view.setSelectedRange(NSRange(location: 0, length: 0))
        controller.toggleList(.bullet)
        XCTAssertEqual(view.string, "•\titem")
        view.setSelectedRange(NSRange(location: view.string.count, length: 0))
        XCTAssertTrue(controller.handleReturn())
        XCTAssertEqual(view.string, "•\titem\n•\t")
        XCTAssertTrue(controller.handleReturn(), "Return on an empty item ends the list")
        XCTAssertEqual(view.string, "•\titem\n")
        XCTAssertFalse(controller.handleReturn(), "outside a list Return is left to the text view")
    }

    func testNumberedListsRenumberAfterInsertion() {
        let (controller, view) = editor("a\nb")
        view.setSelectedRange(NSRange(location: 0, length: 3))
        controller.toggleList(.number)
        XCTAssertEqual(view.string, "1.\ta\n2.\tb")
        view.setSelectedRange(NSRange(location: 4, length: 0))
        XCTAssertTrue(controller.handleReturn())
        XCTAssertEqual(view.string, "1.\ta\n2.\t\n3.\tb")
    }

    func testIndentStaysWithinBounds() {
        let (controller, view) = editor("text")
        controller.indent(by: -1)
        XCTAssertEqual(RichText.indent(of: view.textStorage!.attributes(at: 0, effectiveRange: nil)), 0)
        controller.indent(by: 1)
        XCTAssertEqual(RichText.indent(of: view.textStorage!.attributes(at: 0, effectiveRange: nil)), RichText.indentStep)
        for _ in 0..<20 { controller.indent(by: 1) }
        XCTAssertEqual(RichText.indent(of: view.textStorage!.attributes(at: 0, effectiveRange: nil)), RichText.indentStep * 10)
    }

    func testArchiveRoundTripKeepsFormattingWithoutColors() throws {
        let (controller, view) = editor("bold line\nlist")
        view.setSelectedRange(NSRange(location: 0, length: 4))
        controller.toggleBold()
        view.setSelectedRange(NSRange(location: 10, length: 4))
        controller.toggleList(.bullet)
        let data = try XCTUnwrap(RichText.archive(view.textStorage!))
        let restored = try XCTUnwrap(RichText.unarchive(data))
        XCTAssertEqual(restored.string, view.string)
        XCTAssertEqual(RichText.html(from: restored), RichText.html(from: view.textStorage!))
        XCTAssertNotNil(restored.attribute(.foregroundColor, at: 0, effectiveRange: nil), "colors are re-applied for display")
    }
}
