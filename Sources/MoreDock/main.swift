import AppKit
import Sparkle
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private lazy var dockController = DockController(settings: settings)
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    private var settingsWindowController: SettingsWindowController?
    private var logWindowController: LogWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Diagnostics.logStartup()
        configureStatusItem()
        dockController.start()

        if CommandLine.arguments.contains("--show-settings") {
            openSettings()
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "MoreDock")
        item.button?.imagePosition = .imageLeading

        let menu = NSMenu()
        menu.addItem(withTitle: "MoreDock", action: nil, keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())

        let enabledItem = NSMenuItem(title: "Enable Docks", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        enabledItem.state = settings.isEnabled ? .on : .off
        menu.addItem(enabledItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())
        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "u")
        updateItem.target = self
        menu.addItem(updateItem)

        let logsItem = NSMenuItem(title: "Show Logs...", action: #selector(showLogs), keyEquivalent: "l")
        logsItem.target = self
        menu.addItem(logsItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit MoreDock", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        settings.isEnabled.toggle()
        sender.state = settings.isEnabled ? .on : .off
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(settings: settings) { [weak self] in
                self?.updaterController.checkForUpdates(nil)
            }
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
    }

    @objc private func refreshNow() {
        dockController.refreshAll()
    }

    @objc private func showLogs() {
        if logWindowController == nil {
            logWindowController = LogWindowController()
        }
        NSApp.activate(ignoringOtherApps: true)
        logWindowController?.showWindow(nil)
    }

    @objc private func checkForUpdates(_ sender: NSMenuItem) {
        updaterController.checkForUpdates(sender)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
withExtendedLifetime(delegate) {
    app.run()
}
