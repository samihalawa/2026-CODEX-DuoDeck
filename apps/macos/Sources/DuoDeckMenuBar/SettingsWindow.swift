import AppKit
import SwiftUI
import DuoDeckHostCore

/// The Settings window's tabs, in the toolbar's order.
enum SettingsTab: String, CaseIterable {
    case general, devices, streaming, advanced, virtualDisplay, permissions, remoteAccess

    /// The saved raw routes stay stable; older deep links open inside Advanced.
    static let navigationTabs: [Self] = [.general, .devices, .streaming, .advanced]

    var navigationGroup: Self {
        switch self {
        case .virtualDisplay, .permissions, .remoteAccess: .advanced
        default: self
        }
    }

    var title: String {
        switch self {
        case .general: "General"
        case .devices: "Devices"
        case .streaming: "Streaming"
        case .advanced: "Advanced"
        case .virtualDisplay: "Virtual Display"
        case .permissions: "Permissions"
        case .remoteAccess: "Remote Access"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .devices: "ipad.and.iphone"
        case .streaming: "play.rectangle"
        case .advanced: "slider.horizontal.3"
        case .virtualDisplay: "display"
        case .permissions: "lock.shield"
        case .remoteAccess: "globe"
        }
    }
}

/// DuoDeck's primary window. Its size belongs to the user and survives navigation and reopening.
/// The existing Settings routes remain the single navigation path for the app, Dock, and menu.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let model: AppModel
    private let tabs: SettingsTabController
    private var releaseWatch: Timer?
    private static let frameName = "DuoDeckMainWindow"

    init(model: AppModel) {
        self.model = model
        tabs = SettingsTabController(model: model)
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = "DuoDeck Settings"
        window.isReleasedWhenClosed = false
        window.isExcludedFromWindowsMenu = false
        window.tabbingMode = .disallowed
        window.collectionBehavior.formUnion([.moveToActiveSpace, .fullScreenPrimary])
        window.contentMinSize = NSSize(width: 560, height: 360)
        window.setContentSize(NSSize(width: 760, height: 620))
        super.init(window: window)
        window.delegate = self
        if !window.setFrameUsingName(Self.frameName) { window.center() }
        window.setFrameAutosaveName(Self.frameName)
        refit()
        tabs.onSelect = { [weak self] in
            self?.window?.title = "DuoDeck Settings"
        }
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged(_:)),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not from a nib") }

    func show(tab: SettingsTab?) {
        tabs.select(tab ?? model.settings.settingsTab)
        guard let window else { return }
        window.title = "DuoDeck Settings"
        model.settings.settingsTab = tabs.current
        model.visibleSettingsTab = tabs.current
        refit()
        WindowPlacement.bringForward(window)
        window.layoutIfNeeded()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Dismissing setup stops the automatic jump to Permissions, not the host or its main window.
        model.permissions.refresh()
        if !model.permissions.allGranted { model.settings.permissionsOnboardingDismissed = true }
        return true
    }

    func windowWillClose(_ notification: Notification) { model.visibleSettingsTab = nil }
    func windowDidMiniaturize(_ notification: Notification) { model.visibleSettingsTab = nil }
    func windowDidDeminiaturize(_ notification: Notification) { model.visibleSettingsTab = tabs.current }

    /// Zoom uses the usable display area; the green button also supports native full screen.
    func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame newFrame: NSRect) -> NSRect {
        fitVisibleFrame() ?? newFrame
    }

    func windowDidChangeScreen(_ notification: Notification) { refit() }
    func windowDidEndLiveResize(_ notification: Notification) { refit() }
    func windowDidExitFullScreen(_ notification: Notification) { refit() }
    @objc private func screensChanged(_ notification: Notification) { refit() }

    /// Keep a restored/resized window reachable after a display change. Do not fight a live drag
    /// or native full-screen transition, and never resize the window merely because its tab changed.
    private func refit() {
        guard let window, !window.styleMask.contains(.fullScreen), !window.inLiveResize,
              let visible = fitVisibleFrame() else { return }
        guard NSEvent.pressedMouseButtons == 0 else { placeOnRelease(); return }
        var frame = window.frame
        frame.size.width = min(frame.width, visible.width)
        frame.size.height = min(frame.height, visible.height)
        frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
        if frame != window.frame { window.setFrame(frame, display: window.isVisible) }
    }

    private func placeOnRelease() {
        guard releaseWatch == nil else { return }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard NSEvent.pressedMouseButtons == 0 else { return }
                timer.invalidate()
                self?.releaseWatch = nil
                self?.refit()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        releaseWatch = timer
    }

    /// The app must stay on a real display, never on the virtual display used for a streamed window.
    private func fitVisibleFrame() -> CGRect? {
        let screens = NSScreen.screens
        let ids = screens.map(Self.displayID)
        let list = zip(screens, ids).map { screen, id in
            SettingsWindowFit.Screen(visible: screen.visibleFrame, duodeckVirtual: id.map(StreamCoordinator.isDuoDeckVirtualDisplay) ?? false)
        }
        let on = window?.screen.flatMap(Self.displayID).flatMap { id in ids.firstIndex(of: id) }
        guard let index = SettingsWindowFit.screenIndex(windowOn: on, screens: list) else { return nil }
        return SettingsWindowFit.visible(list[index].visible, testHeight: DebugHooks.testScreenHeight)
    }

    private static func displayID(_ screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    // MARK: TEST ONLY (-DuoDeckSettingsAfter, -DuoDeckSettingsShot)

    /// The window as it stands, on one line: its frame, content and chrome, the pane's whole height
    /// and how much of it shows (the Form's scroll view), the visible frame it fits in, the cap, and
    /// the room left above and below it.
    func fitReport() -> String {
        guard let window else { return "no window" }
        func n(_ v: CGFloat) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }
        func r(_ rect: CGRect) -> String { "\(n(rect.minX)),\(n(rect.minY)) \(n(rect.width))×\(n(rect.height))" }
        let frame = window.frame
        let content = window.contentRect(forFrameRect: frame).height
        let host = tabs.tabViewItems[max(0, tabs.selectedTabViewItemIndex)].viewController
        let pane = host?.view.bounds.height ?? 0
        var shows = "no scroll view"
        if let scroll = host.flatMap({ Self.firstScrollView(in: $0.view) }) {
            let clip = scroll.contentView.bounds, document = scroll.documentView?.frame.height ?? 0
            shows = "shows \(n(clip.height)) of \(n(document))" + (document > clip.height + 0.5 ? ", scrolls" : "")
                + (clip.minY > 0.5 ? " (scrolled \(n(clip.minY)))" : "")
        }
        var screen = "no screen"
        if let used = fitVisibleFrame() {
            let real = window.screen?.visibleFrame
            screen = "screen \(window.screen?.localizedName ?? "none") visible \(real.map(r) ?? "none")"
                + (DebugHooks.testScreenHeight != nil ? ", as \(r(used)) (-DuoDeckTestScreenHeight)" : "")
                + "; \(n(frame.minY - used.minY)) pt over its bottom, \(n(used.maxY - frame.maxY)) under its top"
        }
        let available = fitVisibleFrame().map { SettingsWindowFit.contentLimit(visible: $0, chrome: frame.height - content) } ?? content
        return "\(tabs.current.title): window \(r(frame)) (content \(n(content)), chrome \(n(frame.height - content))); "
            + "pane \(n(pane)) tall, \(shows); available content \(n(available)); \(screen)\(window.isVisible ? "" : "; not on screen")"
    }

    /// Scrolls the pane's Form to its last row, as a scroll to the end would: what a capped pane hides
    /// below the window can be reached.
    func scrollPaneToEnd() -> Bool {
        guard let host = tabs.tabViewItems[max(0, tabs.selectedTabViewItemIndex)].viewController,
              let scroll = Self.firstScrollView(in: host.view), let document = scroll.documentView else { return false }
        let clip = scroll.contentView
        let end = max(0, document.frame.height - clip.bounds.height)
        clip.scroll(to: NSPoint(x: clip.bounds.minX, y: document.isFlipped ? end : 0))
        scroll.reflectScrolledClipView(clip)
        return true
    }

    /// Writes the window, its title bar and toolbar included, as cacheDisplay draws them.
    func writeShot(to url: URL) -> Bool {
        guard let frameView = window?.contentView?.superview,
              let rep = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds) else { return false }
        frameView.cacheDisplay(in: frameView.bounds, to: rep)
        return (try? rep.representation(using: .png, properties: [:])?.write(to: url)) != nil
    }

    private static func firstScrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        for sub in view.subviews { if let scroll = firstScrollView(in: sub) { return scroll } }
        return nil
    }
}

/// One hosting controller per navigation group. The containing window controls the size;
/// content scrolls within it instead of changing the window whenever a section opens.
@MainActor
final class SettingsTabController: NSTabViewController {
    private let model: AppModel
    private var lastAdvancedTab: SettingsTab = .advanced
    /// Every selection, including programmatic navigation, keeps the app title consistent.
    var onSelect: (() -> Void)?

    init(model: AppModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
        tabStyle = .toolbar
        for tab in SettingsTab.navigationTabs {
            let host = NSHostingController(rootView: SettingsPane(tab: tab, model: model))
            host.sizingOptions = []
            host.title = tab.title
            let item = NSTabViewItem(viewController: host)
            item.label = tab.title
            item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
            item.identifier = tab.rawValue
            addTabViewItem(item)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not from a nib") }

    var current: SettingsTab {
        let index = max(0, selectedTabViewItemIndex)
        let group = (tabViewItems[index].identifier as? String).flatMap(SettingsTab.init(rawValue:)) ?? .general
        return group == .advanced ? lastAdvancedTab : group
    }

    func select(_ tab: SettingsTab) {
        if tab.navigationGroup == .advanced { lastAdvancedTab = tab }
        if let index = tabViewItems.firstIndex(where: { ($0.identifier as? String) == tab.navigationGroup.rawValue }) {
            selectedTabViewItemIndex = index
        }
    }

    /// A tab the user picked. Only while the window is on screen: NSTabViewController also
    /// selects its first tab when `NSWindow(contentViewController:)` loads it, before `show`
    /// has read the saved tab, and saving that would reopen Settings on General every launch.
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        onSelect?()
        guard view.window?.isVisible == true else { return }
        let tab = current
        model.settings.settingsTab = tab
        model.visibleSettingsTab = tab
    }
}

/// Where DuoDeck's windows appear, and how they come forward.
@MainActor
enum WindowPlacement {
    /// Restore and activate an app window on a real display, including a Dock-reopened window.
    static func bringForward(_ window: NSWindow) {
        if window.isMiniaturized { window.deminiaturize(nil) }
        if onNoUsefulScreen(window), let area = NSScreen.screens.first?.visibleFrame {
            let size = window.frame.size
            window.setFrameOrigin(NSPoint(x: area.midX - size.width / 2, y: area.midY - size.height / 2))
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                if !window.isKeyWindow { window.orderFrontRegardless() }
            }
        }
    }

    /// A window a device put up (a pairing window it asked for, the cable notice): in front of every
    /// app's windows (over a full-screen app too, with `.fullScreenAuxiliary` in its collection
    /// behavior), off the virtual display, without activating DuoDeck or taking the keyboard, so a
    /// device's request can never swallow what is being typed in another app. A click makes it key.
    /// (docs/home-pairing-plan.md §6.3)
    static func showInFront(_ window: NSWindow) {
        if onNoUsefulScreen(window), let area = NSScreen.screens.first?.visibleFrame {
            let size = window.frame.size
            window.setFrameOrigin(NSPoint(x: area.midX - size.width / 2, y: area.midY - size.height / 2))
        }
        window.orderFrontRegardless()
    }

    private static func onNoUsefulScreen(_ window: NSWindow) -> Bool {
        guard let screen = window.screen else { return true }
        guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
        return StreamCoordinator.isDuoDeckVirtualDisplay(id)
    }
}
