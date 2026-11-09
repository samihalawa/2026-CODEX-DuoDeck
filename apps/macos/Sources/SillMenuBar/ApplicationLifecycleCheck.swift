import AppKit

/// Explicit UI-only validation. Runs before the host starts and never requests permissions,
/// opens a listener, captures a screen, or accesses pairing identity.
@MainActor
enum ApplicationLifecycleCheck {
    static func runIfAsked(delegate: AppDelegate, model: AppModel) {
        guard let path = UserDefaults.standard.string(forKey: "DuoDeckLifecycleCheck"), !path.isEmpty else { return }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var checks: [[String: Any]] = []
        var failures = 0

        func expect(_ passed: Bool, _ name: String) {
            checks.append(["name": name, "passed": passed])
            if !passed { failures += 1 }
            print("Lifecycle \(passed ? "PASS" : "FAIL"): \(name)")
        }
        func settle(_ seconds: TimeInterval = 0.08) {
            RunLoop.current.run(until: Date().addingTimeInterval(seconds))
        }
        func until(_ condition: () -> Bool) -> Bool {
            let deadline = Date().addingTimeInterval(2)
            repeat {
                if condition() { return true }
                settle(0.02)
            } while Date() < deadline
            return condition()
        }
        func sameSize(_ a: NSSize, _ b: NSSize) -> Bool {
            abs(a.width - b.width) < 1 && abs(a.height - b.height) < 1
        }
        func finish() -> Never {
            let report: [String: Any] = [
                "checks": checks, "failures": failures,
                "bundle": Bundle.main.bundleIdentifier ?? "unbundled",
                "activationPolicy": NSApp.activationPolicy().rawValue,
                "hostStarted": model.coordinator != nil
            ]
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: directory.appendingPathComponent("results.json"))
            }
            print("Lifecycle checks finished: \(checks.count) checks, \(failures) failures")
            exit(failures == 0 ? 0 : 1)
        }

        expect(NSApp.activationPolicy() == .regular && NSRunningApplication.current.activationPolicy == .regular,
               "Regular activation exposes the app in Dock and app switcher")
        expect((Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool) != true,
               "Bundle is not an agent-only application")
        expect(Bundle.main.url(forResource: "AppIcon", withExtension: "icns") != nil,
               "App bundle contains its branded icon")
        expect(NSApp.windowsMenu != nil && NSApp.helpMenu != nil && NSApp.servicesMenu != nil,
               "Native Window, Help, and Services menus are registered")
        expect(model.coordinator == nil, "Checks run without starting the host")

        delegate.showSettings(tab: .general)
        settle()
        guard let controller = model.settingsWindowForTests?(), let window = controller.window else {
            expect(false, "Primary window exists")
            finish()
        }
        expect(window.isVisible, "Normal launch opens a meaningful primary window")
        expect(window.styleMask.isSuperset(of: [.titled, .closable, .miniaturizable, .resizable]),
               "Primary window has standard close, minimize, and resize controls")
        expect(window.standardWindowButton(.zoomButton)?.isEnabled == true &&
               window.collectionBehavior.contains(.fullScreenPrimary),
               "Native zoom and full-screen controls are available")
        expect(!window.isExcludedFromWindowsMenu, "Primary window participates in the Window menu")

        let requested = NSSize(width: 960, height: 640)
        window.setContentSize(requested)
        settle()
        let resized = window.contentRect(forFrameRect: window.frame).size
        expect(sameSize(resized, requested), "Window accepts a user-selected size in both dimensions")
        _ = controller.writeShot(to: directory.appendingPathComponent("resized-main-window.png"))
        for route: SettingsTab in [.devices, .streaming, .permissions, .remoteAccess, .advanced, .general] {
            delegate.showSettings(tab: route)
            settle()
            expect(model.settings.settingsTab == route && model.visibleSettingsTab == route &&
                   sameSize(window.contentRect(forFrameRect: window.frame).size, resized),
                   "Navigation preserves window size and route: \(route.rawValue)")
            if route == .permissions {
                _ = controller.writeShot(to: directory.appendingPathComponent("permissions-main-window.png"))
            }
        }

        window.performMiniaturize(nil)
        expect(until { window.isMiniaturized }, "Yellow control minimizes the primary window")
        expect(model.visibleSettingsTab == nil, "Minimizing pauses pane-only refresh work")
        _ = delegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
        expect(until { window.isVisible && !window.isMiniaturized }, "Dock reopen restores a minimized window")
        expect(model.visibleSettingsTab == model.settings.settingsTab, "Restored window resumes its visible pane")

        let beforeZoom = window.frame
        window.performZoom(nil)
        settle()
        expect(window.frame.width >= beforeZoom.width && window.frame.height >= beforeZoom.height &&
               window.frame != beforeZoom, "Zoom expands the window to usable display space")
        _ = controller.writeShot(to: directory.appendingPathComponent("zoomed-main-window.png"))
        window.performZoom(nil)
        settle()
        expect(sameSize(window.frame.size, beforeZoom.size), "Zoom restores the previous user-selected size")

        window.performClose(nil)
        settle()
        expect(!window.isVisible && model.visibleSettingsTab == nil, "Close hides the window and its pane refresh")
        expect(!delegate.applicationShouldTerminateAfterLastWindowClosed(NSApp) && NSApp.isRunning,
               "Closing the last window keeps the app available for background hosting")
        _ = delegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
        settle()
        expect(model.settingsWindowForTests?()?.window === window && window.isVisible,
               "Dock reopen reuses the same primary window after Close")
        expect(sameSize(window.contentRect(forFrameRect: window.frame).size, resized),
               "Reopening preserves the user-selected window size")

        let menuHasOpen = delegate.applicationDockMenu(NSApp)?.items.contains {
            $0.action == #selector(AppDelegate.showMainWindow(_:))
        } == true
        expect(menuHasOpen, "Dock menu offers Show DuoDeck Host")
        expect(NSApp.windowsMenu?.items.contains { $0.action == #selector(NSWindow.performZoom(_:)) } == true &&
               NSApp.windowsMenu?.items.contains { $0.action == #selector(NSWindow.toggleFullScreen(_:)) } == true,
               "Window menu exposes native Zoom and Full Screen commands")
        _ = controller.writeShot(to: directory.appendingPathComponent("reopened-main-window.png"))
        if let icon = NSRunningApplication.current.icon, let tiff = icon.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: directory.appendingPathComponent("running-app-icon.png"))
        }
        expect(model.coordinator == nil, "Lifecycle validation leaves listeners, capture, and pairing unstarted")
        finish()
    }
}
