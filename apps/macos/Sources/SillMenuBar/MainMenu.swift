import AppKit

/// Standard menus for a regular Mac application. The responder chain owns editing and window
/// commands; navigation and pairing go through the same AppDelegate actions as the Dock.
enum MainMenu {
    @MainActor
    static func make() -> NSMenu {
        let main = NSMenu()

        let app = submenu(in: main, title: "DuoDeck Host")
        app.addItem(withTitle: "About DuoDeck Host", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Settings…", action: #selector(AppDelegate.showSettings(_:)), keyEquivalent: ",")
        app.addItem(.separator())
        let services = NSMenu(title: "Services")
        app.addItem(withTitle: "Services", action: nil, keyEquivalent: "").submenu = services
        NSApp.servicesMenu = services
        app.addItem(.separator())
        app.addItem(withTitle: "Hide DuoDeck Host", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = app.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        app.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Quit DuoDeck Host", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let file = submenu(in: main, title: "File")
        let pair = file.addItem(withTitle: "Pair iPhone or iPad…", action: #selector(AppDelegate.pairDevice(_:)), keyEquivalent: "p")
        pair.keyEquivalentModifierMask = [.command, .shift]
        file.addItem(.separator())
        file.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let edit = submenu(in: main, title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(.separator())
        let findItem = edit.addItem(withTitle: "Find", action: nil, keyEquivalent: "")
        let find = NSMenu(title: "Find")
        let actions: [(String, String, NSFindPanelAction)] = [("Find…", "f", .showFindPanel), ("Find Next", "g", .next),
                                                              ("Find Previous", "G", .previous)]
        for (title, key, tag) in actions {
            let item = find.addItem(withTitle: title, action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: key)
            item.tag = Int(tag.rawValue)
        }
        findItem.submenu = find

        let view = submenu(in: main, title: "View")
        for (index, tab) in SettingsTab.navigationTabs.enumerated() {
            let item = view.addItem(withTitle: tab.title, action: #selector(AppDelegate.showSection(_:)), keyEquivalent: String(index + 1))
            item.representedObject = tab.rawValue
        }

        let window = submenu(in: main, title: "Window")
        window.addItem(withTitle: "Show DuoDeck", action: #selector(AppDelegate.showMainWindow(_:)), keyEquivalent: "0")
        window.addItem(.separator())
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        let fullScreen = window.addItem(withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullScreen.keyEquivalentModifierMask = [.command, .control]
        window.addItem(.separator())
        window.addItem(withTitle: "Show Log", action: #selector(AppDelegate.showLogWindow(_:)), keyEquivalent: "")
        window.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        window.delegate = NSApp.delegate as? NSMenuDelegate
        NSApp.windowsMenu = window

        let help = submenu(in: main, title: "Help")
        help.addItem(withTitle: "DuoDeck Help", action: #selector(AppDelegate.openHelp(_:)), keyEquivalent: "?")
        NSApp.helpMenu = help

        return main
    }

    @MainActor
    private static func submenu(in main: NSMenu, title: String) -> NSMenu {
        let item = main.addItem(withTitle: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: title)
        item.submenu = menu
        return menu
    }
}
