import SwiftUI
import AppKit

/// Makes the window state its resizing abilities plainly, since window managers and the Window menu read them.
public struct WindowChrome: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { Self.tidy(view.window) }
        return view
    }

    public func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { Self.tidy(view.window) }
    }

    private static func tidy(_ window: NSWindow?) {
        guard let window else { return }
        window.styleMask.insert([.resizable, .miniaturizable, .closable])
        window.collectionBehavior = [.managed, .participatesInCycle, .primary, .fullScreenPrimary, .fullScreenAllowsTiling]
        window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    }
}

