import Cocoa
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!
    private var showHideItem: NSMenuItem!
    private var quitItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindow()
        setupStatusItem()
        setupHotKey()
        setupSettingsObservers()
    }

    private func setupWindow() {
        let contentView = ContentView()
        let hosting = NSHostingController(rootView: contentView)

        window = NSWindow(contentViewController: hosting)
        window.title = tr(en: "Task Manager", pt: "Gerenciador de Tarefas")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.appearance = SettingsStore.shared.themeMode.nsAppearance
        window.setContentSize(NSSize(width: 780, height: 580))
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.67percent", accessibilityDescription: window.title)
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        showHideItem = NSMenuItem(title: tr(en: "Show/Hide", pt: "Mostrar/Ocultar"), action: #selector(toggleWindow), keyEquivalent: "")
        quitItem = NSMenuItem(title: tr(en: "Quit", pt: "Sair"), action: #selector(quit), keyEquivalent: "q")

        statusMenu = NSMenu()
        statusMenu.addItem(showHideItem)
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(quitItem)
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

        hotKeyObserver = SettingsStore.shared.$hotKeyCombo
            .dropFirst()
            .sink { combo in
                HotKeyManager.shared.register(combo: combo)
            }
    }

    private func setupSettingsObservers() {
        themeObserver = SettingsStore.shared.$themeMode
            .dropFirst()
            .sink { [weak self] mode in
                self?.window.appearance = mode.nsAppearance
            }

        languageObserver = SettingsStore.shared.$language
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                self.window.title = tr(en: "Task Manager", pt: "Gerenciador de Tarefas")
                self.showHideItem.title = tr(en: "Show/Hide", pt: "Mostrar/Ocultar")
                self.quitItem.title = tr(en: "Quit", pt: "Sair")
            }
    }

    private var hotKeyObserver: AnyCancellable?
    private var themeObserver: AnyCancellable?
    private var languageObserver: AnyCancellable?

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

extension ThemeMode {
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}
