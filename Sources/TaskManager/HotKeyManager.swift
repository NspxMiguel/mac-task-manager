import Cocoa
import Carbon.HIToolbox

/// A key + modifier combo that can be persisted and displayed.
struct KeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32 // Carbon modifier flags (cmdKey, optionKey, controlKey, shiftKey)

    static let defaultCombo = KeyCombo(keyCode: UInt32(kVK_Escape), modifiers: UInt32(cmdKey) | UInt32(shiftKey))

    /// Human readable representation, e.g. "⌘⇧⎋"
    var displayString: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        s += KeyCombo.keyName(for: keyCode)
        return s
    }

    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Escape: return "⎋"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        default:
            if let scalar = KeyCombo.characterMap[Int(keyCode)] {
                return scalar.uppercased()
            }
            return "Key\(keyCode)"
        }
    }

    // Minimal mapping for common alphanumeric keys (ANSI layout).
    static let characterMap: [Int: String] = [
        kVK_ANSI_A: "a", kVK_ANSI_B: "b", kVK_ANSI_C: "c", kVK_ANSI_D: "d", kVK_ANSI_E: "e",
        kVK_ANSI_F: "f", kVK_ANSI_G: "g", kVK_ANSI_H: "h", kVK_ANSI_I: "i", kVK_ANSI_J: "j",
        kVK_ANSI_K: "k", kVK_ANSI_L: "l", kVK_ANSI_M: "m", kVK_ANSI_N: "n", kVK_ANSI_O: "o",
        kVK_ANSI_P: "p", kVK_ANSI_Q: "q", kVK_ANSI_R: "r", kVK_ANSI_S: "s", kVK_ANSI_T: "t",
        kVK_ANSI_U: "u", kVK_ANSI_V: "v", kVK_ANSI_W: "w", kVK_ANSI_X: "x", kVK_ANSI_Y: "y",
        kVK_ANSI_Z: "z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3", kVK_ANSI_4: "4",
        kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9",
    ]
}

/// Registers a single system-wide hotkey using the Carbon Event Manager.
/// This does NOT require Accessibility/Input Monitoring permission, unlike
/// NSEvent global monitors.
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x544B4D47 /* 'TKMG' */), id: 1)
    var onTrigger: (() -> Void)?

    private init() {}

    func register(combo: KeyCombo) {
        unregister()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (_, eventRef, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onTrigger?()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)

        RegisterEventHotKey(combo.keyCode, combo.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
}
