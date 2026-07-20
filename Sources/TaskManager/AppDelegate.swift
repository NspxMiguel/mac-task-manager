import Cocoa
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindow()
        setupStatusItem()
        setupHotKey()
    }

    private func setupWindow() {
        let contentView = ContentView()
        let hosting = NSHostingController(rootView: contentView)

        window = NSWindow(contentViewController: hosting)
        window.title = "Gerenciador de Tarefas"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 760, height: 560))
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.67percent", accessibilityDescription: "Gerenciador de Tarefas")
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        statusMenu = NSMenu()
        statusMenu.addItem(NSMenuItem(title: "Mostrar/Ocultar", action: #selector(toggleWindow), keyEquivalent: ""))
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Sair", action: #selector(quit), keyEquivalent: "q"))
        statusMenu.items.forEach { $0.target = self }
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent, event.type == .rightMouseUp else {
            toggleWindow()
            return
        }
        // Temporarily attach the menu just for this right-click, so a
        // left-click keeps toggling the window instead of always opening it.
        statusItem.menu = statusMenu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func setupHotKey() {
        HotKeyManager.shared.onTrigger = { [weak self] in
            self?.toggleWindow()
        }
        HotKeyManager.shared.register(combo: SettingsStore.shared.hotKeyCombo)

        settingsObserver = SettingsStore.shared.$hotKeyCombo
            .dropFirst()
            .sink { combo in
                HotKeyManager.shared.register(combo: combo)
            }
    }

    private var settingsObserver: AnyCancellable?

    @objc private func toggleWindow() {
        if window.isVisible && NSApp.isActive {
            window.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
