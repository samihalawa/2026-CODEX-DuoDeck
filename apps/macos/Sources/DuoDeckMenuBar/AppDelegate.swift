import AppKit
import DuoDeckHostCore

/// DuoDeck Host is a normal Mac app with one primary window and a status-item shortcut.
/// Its host keeps serving paired devices when the window closes; Quit ends the host through
/// the existing orderly shutdown path.
///
/// THE MODAL-LOOP RULE. Never start a nested modal loop from `Task { @MainActor }`, an async
/// continuation or a `DispatchQueue.main` block: NSMenu.popUp, NSAlert.runModal, NSApp.runModal,
/// NSSavePanel.runModal, and NSApp.terminate whenever it can answer .terminateLater. The main
/// queue is serial, so while that loop runs every host hop waits behind it (input, client
/// messages, source switches, the stats line), and a terminate issued from a Task never gets its
/// reply. Both were measured (design workflow, 2026-09-23). Start them only from AppKit
/// target/action, SwiftUI Button actions or a run-loop Timer, and show errors inline, never in an
/// alert.
///
/// App code may call `MainActor.assumeIsolated` in main-queue callbacks, because the app always
/// runs NSApplication and its main queue is the main thread. The host core may not: the CLI's
/// dispatchMain drains the main queue on a worker thread, where that call traps.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSMenuItemValidation {
    let model = AppModel()
    private var statusItem: StatusItemController?
    private var settingsWindow: SettingsWindowController?
    private var homeWindow: HomeWindowController?
    private var logWindow: LogWindowController?
    private var pairingWindow: PairDeviceWindowController?
    private var cableNotice: CableNoticeWindowController?
    private var terminating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        DebugHooks.renderPreviewsIfAsked(model: model)      // exits when asked
        // Closing the window never ends an active/background host.
        ProcessInfo.processInfo.disableAutomaticTermination("DuoDeck Host serves paired devices while its window is closed")
        ProcessInfo.processInfo.disableSuddenTermination()
        let item = StatusItemController(model: model)        // "Starting…" until the host is up
        statusItem = item
        model.onPresentation = { [weak item] p in item?.show(p) }
        model.showSettings = { [weak self] tab in self?.showSettings(tab: tab) }
        model.showHome = { [weak self] in self?.showHome() }
        model.settingsWindowForTests = { [weak self] in self?.settingsWindow }
        model.showLog = { [weak self] in self?.showLog() }
        // An offer can come from a device's request (its ask at the home door, or kind 21), and the
        // cable notice from a device pairing over the cable, each on a main-actor hop: showing a
        // window there is fine, it runs no modal loop.
        model.showPairing = { [weak self] offer in self?.showPairing(offer) }
        model.bringPairingForward = { [weak self] in
            guard let window = self?.pairingWindow, window.isShowing else { return false }
            window.bringForward()
            return true
        }
        model.closePairingWindow = { [weak self] in
            guard let window = self?.pairingWindow, window.isShowing else { return false }
            window.close()          // windowWillClose cancels the pairing, as Cancel does
            return true
        }
        model.showCableNotice = { [weak self] notice in self?.showCableNotice(notice) }
        // Settings › Devices' "Show the pairing window to screen sharing": a pairing window already
        // made follows a change at once, on screen or not (one made later reads it as it is made).
        model.settings.onPairingWindowSharingChange = { [weak self] in self?.pairingWindow?.applySharing() }
        // UI-only lifecycle checks stop here, before listeners, capture, identity, or pairing start.
        ApplicationLifecycleCheck.runIfAsked(delegate: self, model: model)
        showHome()
        // Always, not only with the virtual display on: Settings can turn it on at any time, and a
        // kill must then still put the streamed window back.
        HostShutdown.install { [model] in model.coordinator }
        model.start()
        DebugHooks.schedule(model: model)
    }

    /// Dock, Finder, Spotlight, and Open restore the same primary window, including after Close
    /// or Minimize. A remote pairing panel being visible does not prevent this.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showHome()
        return false
    }

    /// Standard Mac behavior: Close hides a window; only Quit stops the host.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let open = menu.addItem(withTitle: "Show DuoDeck", action: #selector(showMainWindow(_:)), keyEquivalent: "")
        open.target = self
        let pair = menu.addItem(withTitle: "Pair iPhone or iPad…", action: #selector(pairDevice(_:)), keyEquivalent: "")
        pair.target = self
        pair.isEnabled = model.presentation.canPair
        menu.autoenablesItems = false
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === NSApp.windowsMenu,
              let item = menu.items.first(where: { $0.action == #selector(NSWindow.toggleFullScreen(_:)) }) else { return }
        item.title = NSApp.keyWindow?.styleMask.contains(.fullScreen) == true ? "Exit Full Screen" : "Enter Full Screen"
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(pairDevice(_:)) { return model.presentation.canPair }
        if menuItem.action == #selector(showSection(_:)), let raw = menuItem.representedObject as? String,
           let tab = SettingsTab(rawValue: raw) {
            menuItem.state = model.settings.settingsTab.navigationGroup == tab ? .on : .off
        }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// Quit ⌘Q, logout and Screen Recording's "Quit & Reopen" all arrive here from the event loop.
    /// The streamed window goes home and the virtual display goes away before AppKit exits. A
    /// window in a full-screen Space on the virtual display cannot be moved, so it is taken out of
    /// full screen first, waiting up to 2 s on a run-loop timer; a 4 s watchdog exits regardless,
    /// and the atexit restore still runs then. No confirmation. Signals do not come through here:
    /// HostShutdown handles them synchronously, with exit code 128 + the signal.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if terminating { return .terminateNow }
        terminating = true
        let coordinator = model.coordinator
        guard let c = coordinator, c.stagedWindowIsFullScreen else {
            HostShutdown.releaseForQuit(coordinator: coordinator)
            return .terminateNow
        }
        print("Quit: taking the streamed window out of full screen first.")
        c.beginLeavingFullScreenForQuit()
        let deadline = Date().addingTimeInterval(2)
        let poll = Timer(timeInterval: 0.1, repeats: true) { timer in
            MainActor.assumeIsolated {
                guard c.stagedWindowSettled || Date() >= deadline else { return }
                timer.invalidate()
                HostShutdown.releaseForQuit(coordinator: c)
                NSApp.reply(toApplicationShouldTerminate: true)
            }
        }
        RunLoop.main.add(poll, forMode: .common)
        DispatchQueue.global().asyncAfter(deadline: .now() + 4) {
            print("Quit timed out; exiting anyway.")
            exit(0)
        }
        return .terminateLater
    }

    // MARK: Windows

    @objc func showMainWindow(_ sender: Any?) { showHome() }

    @objc func pairDevice(_ sender: Any?) { model.pairDevice() }

    @objc func showLogWindow(_ sender: Any?) { showLog() }

    @objc func showSection(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let tab = SettingsTab(rawValue: raw) else { return }
        showSettings(tab: tab)
    }

    @objc func openHelp(_ sender: Any?) {
        if let url = URL(string: "https://duodeck.megawebs.com/#how") { NSWorkspace.shared.open(url) }
    }

    /// Settings… (⌘,) restores the controls in the primary window.
    @objc func showSettings(_ sender: Any?) {
        showSettings(tab: nil)
    }

    func showSettings(tab: SettingsTab?) {
        let controller = settingsWindow ?? SettingsWindowController(model: model)
        settingsWindow = controller
        controller.show(tab: tab)
    }

    /// The home window: what the app opens with, and what the Dock, the menu bar item and ⌘0 bring back.
    func showHome() {
        let controller = homeWindow ?? HomeWindowController(model: model)
        homeWindow = controller
        controller.show()
    }

    func showLog() {
        let controller = logWindow ?? LogWindowController(settings: model.settings)
        logWindow = controller
        controller.show()
    }

    /// The one pairing window: made once, shown with each offer (the same code while it is open).
    func showPairing(_ offer: RemoteAccess.PairingOffer) {
        let controller = pairingWindow ?? PairDeviceWindowController(model: model)
        pairingWindow = controller
        controller.show(offer)
    }

    /// The one cable notice window, beside the pairing window: made once, shown for each pairing.
    func showCableNotice(_ notice: CableNotice) {
        let controller = cableNotice ?? CableNoticeWindowController(model: model)
        cableNotice = controller
        controller.show(notice)
    }
}
