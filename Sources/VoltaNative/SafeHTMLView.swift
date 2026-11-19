import SwiftUI
import WebKit
import AppKit

/// Shows untrusted HTML safely: no JavaScript, a strict content security policy, no persistent storage,
/// and links open in the default browser. Remote images load only when `allowRemoteImages` is true.
public struct SafeHTMLView: NSViewRepresentable {
    let html: String
    var query: String
    var allowRemoteImages: Bool
    var linkColor: String

    /// - Parameters:
    ///   - query: text to highlight with find-in-page.
    ///   - linkColor: any CSS color for links.
    public init(html: String, query: String = "", allowRemoteImages: Bool = false, linkColor: String = "#d34f31") {
        self.html = html
        self.query = query
        self.allowRemoteImages = allowRemoteImages
        self.linkColor = linkColor
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }
    public func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.setValue(false, forKey: "drawsBackground")
        return view
    }
    public func updateNSView(_ view: WKWebView, context: Context) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if context.coordinator.query != query {
            context.coordinator.query = query
            if !view.isLoading { context.coordinator.highlight(in: view) }
        }
        // The link color goes into the trusted style block, so keep only characters a CSS color needs.
        let linkColor = linkColor.filter { $0.isLetter || $0.isNumber || "#(),. %".contains($0) }
        let key = (allowRemoteImages ? "images:" : "blocked:") + linkColor + ":" + html
        guard context.coordinator.loaded != key else { return }
        context.coordinator.loaded = key
        // This first CSP cannot be weakened by policies inside the untrusted message.
        let prefix = """
        <!doctype html><html><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src \(allowRemoteImages ? "data: https:" : "data:"); style-src 'unsafe-inline'; font-src 'none'; media-src 'none'; frame-src 'none'; connect-src 'none'; form-action 'none'; base-uri 'none'">
        <meta name="color-scheme" content="light dark">
        <style>body { margin: 24px 28px; font: 14px -apple-system, sans-serif; line-height: 1.7; overflow-wrap: anywhere; } img { max-width: 100%; height: auto; } table { max-width: 100%; } a { color: \(linkColor); }</style></head><body>
        """
        view.loadHTMLString(prefix + html + "</body></html>", baseURL: nil)
    }
    public final class Coordinator: NSObject, WKNavigationDelegate {
        var loaded: String?
        var query = ""
        func highlight(in view: WKWebView) {
            let configuration = WKFindConfiguration()
            configuration.caseSensitive = false
            configuration.wraps = true
            view.find(query, configuration: configuration) { _ in }
        }
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            highlight(in: webView)
        }
        public func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated, let url = action.request.url,
               ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else if action.request.url?.absoluteString == "about:blank" && action.navigationType == .other {
                decisionHandler(.allow)
            } else { decisionHandler(.cancel) }
        }
    }
}
