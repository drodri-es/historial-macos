import AppKit
import ApplicationServices
import Carbon
import SwiftUI

@main
enum HistorialApp {
    static func main() {
        let application = NSApplication.shared
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            application.applicationIconImage = icon
        }
        let coordinator = AppCoordinator.shared
        application.delegate = coordinator
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

@MainActor
final class AppCoordinator: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    static let shared = AppCoordinator()

    private let store = HistoryStore()
    private let language = LocalizationStore.shared
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
    private var previousApplication: NSRunningApplication?
    private var hotkeyReference: EventHotKeyRef?
    private var hotkeyHandler: EventHandlerRef?
    private var nextHotkeyID: UInt32 = 1
    private var shortcut: HotkeyPreference = .standard
    private var accessibilityPromptRequested = false
    private var pasteFallbackShown = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let data = UserDefaults.standard.data(forKey: "globalShortcut"),
           let saved = try? JSONDecoder().decode(HotkeyPreference.self, from: data) {
            shortcut = saved
        }

        NotificationCenter.default.addObserver(self, selector: #selector(languageDidChange), name: .historialLanguageDidChange, object: nil)
        statusItem.button?.image = MenuBarIcon.make(accessibilityDescription: language.text("app.clipboardHistory"))
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        refreshChrome()

        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 420, height: 510)
        updatePopoverContent()
        installHotkeyHandler()
        registerHotkey(shortcut)
        store.startMonitoring()
        if CommandLine.arguments.contains("--show-settings") || !UserDefaults.standard.bool(forKey: "hasShownWelcome") {
            UserDefaults.standard.set(true, forKey: "hasShownWelcome")
            DispatchQueue.main.async { [weak self] in self?.openSettings() }
        }
    }

    private func updatePopoverContent() {
        popover.contentViewController = NSHostingController(rootView: HistoryPanel(
            store: store,
            onSelect: { [weak self] entry in self?.select(entry) },
            hotkey: shortcut,
            onHotkeyChange: { [weak self] value in self?.changeHotkey(value) },
            onOpenSettings: { [weak self] in self?.openSettings() }
        ))
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        let active = NSWorkspace.shared.frontmostApplication
        previousApplication = active?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : active
        updatePopoverContent()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func select(_ entry: ClipEntry) {
        guard store.restore(entry) else { return }
        store.markOwnPasteboardChange()
        popover.performClose(nil)
        guard let previousApplication else {
            showPasteFallback()
            return
        }
        guard previousApplication.activate() else {
            showPasteFallback()
            return
        }

        guard AXIsProcessTrusted() else {
            if !accessibilityPromptRequested {
                accessibilityPromptRequested = true
                let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(options)
            } else {
                showPasteFallback()
            }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == previousApplication.processIdentifier else {
                self?.showPasteFallback()
                return
            }
            let source = CGEventSource(stateID: .combinedSessionState)
            let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
            down?.flags = .maskCommand
            up?.flags = .maskCommand
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }

    private func showPasteFallback() {
        guard !pasteFallbackShown else { return }
        pasteFallbackShown = true
        let alert = NSAlert()
        alert.messageText = language.text("paste.ready")
        alert.informativeText = language.text("paste.fallback")
        alert.addButton(withTitle: language.text("common.ok"))
        alert.runModal()
    }

    private func openSettings() {
        popover.performClose(nil)
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 530),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = language.text("settings.title")
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        settingsWindow?.contentView = NSHostingView(rootView: SettingsPanel(
            store: store,
            hotkey: shortcut,
            onHotkeyChange: { [weak self] value in self?.changeHotkey(value) }
        ))
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func changeHotkey(_ value: HotkeyPreference) {
        guard value != shortcut else { return }
        guard registerHotkey(value) else { return }
        shortcut = value
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: "globalShortcut")
        }
        refreshChrome()
        updatePopoverContent()
        if settingsWindow?.isVisible == true { openSettings() }
    }

    @objc private func languageDidChange() {
        refreshChrome()
    }

    private func refreshChrome() {
        statusItem.button?.image = MenuBarIcon.make(accessibilityDescription: language.text("app.clipboardHistory"))
        statusItem.button?.toolTip = language.text("app.tooltip", shortcut.displayText)
        settingsWindow?.title = language.text("settings.title")
    }

    private func installHotkeyHandler() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, _, _ in
            Task { @MainActor in AppCoordinator.shared.showPopover() }
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventSpec, nil, &hotkeyHandler)
    }

    @discardableResult
    private func registerHotkey(_ value: HotkeyPreference) -> Bool {
        var newReference: EventHotKeyRef?
        let hotkeyID = EventHotKeyID(signature: 0x48495354, id: nextHotkeyID)
        nextHotkeyID &+= 1
        let result = RegisterEventHotKey(value.keyCode, value.modifiers, hotkeyID, GetApplicationEventTarget(), 0, &newReference)
        if result == noErr {
            if let hotkeyReference { UnregisterEventHotKey(hotkeyReference) }
            hotkeyReference = newReference
            return true
        }
        let alert = NSAlert()
        alert.messageText = language.text("hotkey.failed", value.displayText)
        alert.informativeText = language.text("hotkey.failedDetail")
        alert.runModal()
        return false
    }
}
