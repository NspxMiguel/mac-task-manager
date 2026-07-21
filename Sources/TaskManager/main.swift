import Cocoa
import SwiftUI

// Dev-only: `TaskManager --screenshot <light|dark> <output.png>` renders
// ContentView in a real (but off-screen positioned) window for README
// screenshots, then exits. AppKit-bridged SwiftUI controls (List, TextField)
// don't render correctly through ImageRenderer without a live window, so
// this uses an actual NSWindow instead.
if CommandLine.arguments.count >= 4, CommandLine.arguments[1] == "--screenshot" {
    let mode = CommandLine.arguments[2]
    let outputPath = CommandLine.arguments[3]

    final class ScreenshotDelegate: NSObject, NSApplicationDelegate {
        let mode: String
        let outputPath: String
        var window: NSWindow!

        init(mode: String, outputPath: String) {
            self.mode = mode
            self.outputPath = outputPath
        }

        func applicationDidFinishLaunching(_ notification: Notification) {
            let view = ContentView()
                .environment(\.colorScheme, mode == "light" ? .light : .dark)
            let hosting = NSHostingController(rootView: view)

            window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            window.setContentSize(NSSize(width: 780, height: 580))
            window.setFrameOrigin(NSPoint(x: -20000, y: -20000)) // keep off-screen
            window.orderFrontRegardless()

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.capture()
            }
        }

        func capture() {
            guard let contentView = window.contentView,
                  let bitmap = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) else {
                print("render failed")
                exit(1)
            }
            bitmap.size = contentView.bounds.size
            contentView.cacheDisplay(in: contentView.bounds, to: bitmap)
            if let png = bitmap.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: outputPath))
                print("wrote \(outputPath)")
            }
            exit(0)
        }
    }

    let app = NSApplication.shared
    let screenshotDelegate = ScreenshotDelegate(mode: mode, outputPath: outputPath)
    app.delegate = screenshotDelegate
    app.setActivationPolicy(.regular)
    app.run()
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
