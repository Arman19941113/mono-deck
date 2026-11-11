import AppKit
import SwiftUI

struct AuxiliaryWindowPlacement: NSViewControllerRepresentable {
    struct Anchor {
        var frame: CGRect
        var visibleFrame: CGRect

        func center(_ window: NSWindow) {
            let size = window.frame.size
            let x = frame.midX - size.width / 2
            let y = frame.midY - size.height / 2
            let maxX = max(visibleFrame.minX, visibleFrame.maxX - size.width)
            let maxY = max(visibleFrame.minY, visibleFrame.maxY - size.height)
            window.setFrameOrigin(CGPoint(x: min(max(x, visibleFrame.minX), maxX),
                                          y: min(max(y, visibleFrame.minY), maxY)))
        }
    }

    var expectedSize: CGSize? = nil
    var anchor: () -> Anchor?

    func makeNSViewController(context: Context) -> Controller {
        Controller(expectedSize: expectedSize, anchor: anchor)
    }

    func updateNSViewController(_ controller: Controller, context: Context) {
        controller.expectedSize = expectedSize
        controller.anchor = anchor
        controller.centerIfNeeded()
    }

    static func dismantleNSViewController(_ controller: Controller, coordinator: ()) {
        controller.stopObserving()
    }

    final class Controller: NSViewController {
        var expectedSize: CGSize?
        var anchor: () -> Anchor?
        private weak var observedWindow: NSWindow?
        private var needsCenter = true
        private var appearing = false

        init(expectedSize: CGSize?, anchor: @escaping () -> Anchor?) {
            self.expectedSize = expectedSize
            self.anchor = anchor
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func loadView() { view = NSView() }

        override func viewDidAppear() {
            super.viewDidAppear()
            appearing = true
            centerIfNeeded()
        }

        override func viewDidDisappear() {
            super.viewDidDisappear()
            appearing = false
        }

        @objc func centerIfNeeded() {
            guard appearing, let window = viewIfLoaded?.window else { return }
            if observedWindow !== window {
                stopObserving()
                observedWindow = window
                needsCenter = true
                NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification, object: window)
                if expectedSize != nil {
                    NotificationCenter.default.addObserver(self, selector: #selector(centerIfNeeded), name: NSWindow.didResizeNotification, object: window)
                }
            }
            guard needsCenter else { return }
            // Settings adjusts its content height after measuring the title bar.
            if let expectedSize, abs(window.frame.width - expectedSize.width) >= 1 || abs(window.frame.height - expectedSize.height) >= 1 { return }
            needsCenter = false
            if let anchor = anchor() {
                anchor.center(window)
            } else if let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame {
                Anchor(frame: visibleFrame, visibleFrame: visibleFrame).center(window)
            }
        }

        @objc private func windowWillClose() {
            needsCenter = true
            appearing = false
        }

        func stopObserving() {
            if let window = observedWindow { NotificationCenter.default.removeObserver(self, name: nil, object: window) }
            observedWindow = nil
        }
    }
}
