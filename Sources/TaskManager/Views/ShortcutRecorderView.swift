import SwiftUI
import Carbon.HIToolbox

/// An AppKit-backed view that captures the next key chord the user presses
/// while it has focus, and reports it as a KeyCombo.
struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var combo: KeyCombo
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onCapture = { newCombo in
            combo = newCombo
            isRecording = false
        }
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

final class RecorderNSView: NSView {
    var onCapture: ((KeyCombo) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        var modifiers: UInt32 = 0
        let flags = event.modifierFlags
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }

        let keyCode = UInt32(event.keyCode)
        let combo = KeyCombo(keyCode: keyCode, modifiers: modifiers)
        onCapture?(combo)
    }
}
