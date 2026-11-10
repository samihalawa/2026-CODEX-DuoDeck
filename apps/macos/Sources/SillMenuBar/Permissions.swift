import AppKit
import ApplicationServices
import CoreGraphics
import Observation
import SillHostCore
import StreamProtocol

/// Screen Recording and Accessibility, for Sill itself, and what macOS lets it do with the clipboard
/// (`clipboardAccess`). TCC keys them to the bundle ID plus the code's designated requirement, so a
/// rebuild signed with the same certificate keeps them, a copy signed with another certificate is
/// a different app to macOS (development builds therefore use their own bundle ID), and what
/// Terminal was granted for the SillHost CLI does not carry over.
///
/// Read on demand, never on a background timer: when the menu opens, once a second while the
/// Permissions pane is on screen, when Sill becomes active, and whenever the host's status changes
/// (a revoked Screen Recording stops the capture, which shows up here on the next read).
@MainActor @Observable
final class PermissionsModel {
    private(set) var screenRecording = CGPreflightScreenCaptureAccess()
    private(set) var accessibility = AXIsProcessTrusted()
    /// A Screen Recording request was made. A grant reaches ScreenCaptureKit only in a new
    /// process, so the pane offers Relaunch Sill (macOS itself offers Quit & Reopen).
    private(set) var relaunchSuggested = false
    /// What macOS lets Sill do with the clipboard (ClipboardPolicy.MacAccess, macOS 15.4 and later):
    /// Settings › General's clipboard section says so while it does not allow every read. Read with
    /// the rest (MacClipboard.access), which never reads the clipboard itself; `.allowed` until then.
    private(set) var clipboardAccess = ClipboardPolicy.MacAccess.allowed

    var allGranted: Bool { screenRecording && accessibility }

    /// Other copies of this app that LaunchServices knows under the same bundle ID (an older
    /// download, a build folder), Trash excluded. macOS can tie permissions to any of them, and
    /// System Settings lists them under one name, so the installed app looks unallowed.
    private(set) var otherCopies: [URL] = []
    /// This copy is not in /Applications (a mounted disk image, Downloads, App Translocation).
    /// Permissions granted to a copy that later moves or is replaced do not follow it.
    private(set) var outsideApplications = false
    /// What the last repair or cleanup did, for the pane.
    private(set) var repairNote: String?

    /// Only inside Sill.app: relaunching the bare binary would open its folder instead.
    let canRelaunch = Bundle.main.bundleURL.pathExtension == "app"

    @ObservationIgnored private let settings: HostSettings

    init(settings: HostSettings) {
        self.settings = settings
    }

    func refresh() {
        let sr = CGPreflightScreenCaptureAccess(), ax = AXIsProcessTrusted()
        if sr != screenRecording { screenRecording = sr }
        if ax != accessibility { accessibility = ax }
        let clipboard = MacClipboard.access()
        if clipboard != clipboardAccess { clipboardAccess = clipboard }
        if sr && ax && settings.permissionsOnboardingDismissed { settings.permissionsOnboardingDismissed = false }
        let copies = Self.findOtherCopies()
        if copies != otherCopies { otherCopies = copies }
        let outside = canRelaunch && !Self.isInApplications(Bundle.main.bundleURL)
        if outside != outsideApplications { outsideApplications = outside }
    }

    // MARK: Self-repair (no Terminal needed)

    /// TCC service names for `tccutil`.
    private enum Service: String { case screenCapture = "ScreenCapture", accessibility = "Accessibility" }

    /// Clears macOS's record of this app for one permission. A record made for another copy
    /// (another certificate, an old build) keeps the switch on in System Settings while this copy
    /// stays unallowed; once cleared, the next request is judged for this copy alone. Only ever
    /// for this app's own bundle ID, and only while the permission is missing, so nothing working
    /// is taken away.
    @discardableResult
    private func resetRecord(_ service: Service) -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        let tool = Process()
        tool.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        tool.arguments = ["reset", service.rawValue, id]
        tool.standardOutput = FileHandle.nullDevice
        tool.standardError = FileHandle.nullDevice
        do { try tool.run(); tool.waitUntilExit() } catch { return false }
        print("Permissions: cleared macOS's \(service.rawValue) record for \(id) (\(tool.terminationStatus == 0 ? "done" : "failed"))")
        return tool.terminationStatus == 0
    }

    /// Repair Permissions: clears the records of every missing permission, then asks again.
    func repairPermissions() {
        refresh()
        var cleared: [String] = []
        if !screenRecording, resetRecord(.screenCapture) { cleared.append("Screen Recording") }
        if !accessibility, resetRecord(.accessibility) { cleared.append("Accessibility") }
        repairNote = cleared.isEmpty
            ? "Nothing needed repairing."
            : "Cleared the old \(cleared.joined(separator: " and ")) record. Turn DuoDeck Host on in the list that opens."
        if !screenRecording { requestScreenRecording(repairing: false) }
        else if !accessibility { requestAccessibility(repairing: false) }
    }

    /// Moves the other copies to the Trash (recoverable), so one DuoDeck Host remains.
    func trashOtherCopies() {
        let copies = otherCopies
        guard !copies.isEmpty else { return }
        // FileManager's own Trash move: NSWorkspace.recycle asks Finder over Apple Events, which a
        // hardened app without the automation entitlement may not do.
        var moved = 0, failures: [String] = []
        for url in copies {
            do { try Self.trash(url); moved += 1 }
            catch { failures.append(url.lastPathComponent + ": " + error.localizedDescription) }
        }
        repairNote = failures.isEmpty
            ? "Moved \(moved) other \(moved == 1 ? "copy" : "copies") of DuoDeck Host to the Trash."
            : "Moved \(moved) to the Trash. Couldn’t move: \(failures.joined(separator: "; "))"
        refresh()
    }

    /// Copies this app into /Applications (replacing an older DuoDeck Host there, which goes to
    /// the Trash) and reopens it from there.
    func moveToApplications() {
        let source = Bundle.main.bundleURL
        let target = URL(fileURLWithPath: "/Applications").appendingPathComponent(source.lastPathComponent)
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: target.path) { try fm.trashItem(at: target, resultingItemURL: nil) }
            try fm.copyItem(at: source, to: target)
        } catch {
            repairNote = "Couldn’t copy DuoDeck Host to Applications: \(error.localizedDescription). Drag it there in Finder."
            NSWorkspace.shared.activateFileViewerSelecting([source])
            return
        }
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        shell.arguments = ["-c", "while /bin/kill -0 \"$1\" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$0\"",
                           target.path, String(ProcessInfo.processInfo.processIdentifier)]
        do { try shell.run() } catch { print("Reopen from Applications failed: \(error.localizedDescription)") }
        NSApp.terminate(nil)
    }

    /// Moves a bundle to the Trash. The Trash refuses a name it already holds ("DuoDeck Host.app"
    /// from an earlier cleanup), so on that error the copy is renamed beside itself first.
    private static func trash(_ url: URL) throws {
        let fm = FileManager.default
        do { try fm.trashItem(at: url, resultingItemURL: nil) }
        catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let renamed = url.deletingLastPathComponent()
                .appendingPathComponent("\(url.deletingPathExtension().lastPathComponent) (old \(stamp)).app")
            try fm.moveItem(at: url, to: renamed)
            try fm.trashItem(at: renamed, resultingItemURL: nil)
        }
    }

    private static func isInApplications(_ url: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix("/Applications/") || path.hasPrefix(home + "/Applications/")
    }

    private static func findOtherCopies() -> [URL] {
        guard let id = Bundle.main.bundleIdentifier else { return [] }
        let me = Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL
        return NSWorkspace.shared.urlsForApplications(withBundleIdentifier: id)
            .map { $0.resolvingSymlinksInPath().standardizedFileURL }
            .filter { $0 != me && !$0.path.contains("/.Trash/") && !$0.path.hasPrefix("/Volumes/")
                      && FileManager.default.fileExists(atPath: $0.path) }
            .sorted { $0.path < $1.path }
    }

    /// Explicit user action. macOS decides whether this app identity needs a prompt; a saved UI
    /// preference must not suppress the request after the app's signing identity changes.
    /// When it was asked before and is still missing, macOS's record most likely belongs to another
    /// copy: clear it first so this request counts for this copy.
    func requestScreenRecording(repairing: Bool = true) {
        if repairing && settings.askedScreenRecording && !CGPreflightScreenCaptureAccess() { resetRecord(.screenCapture) }
        settings.askedScreenRecording = true
        _ = CGRequestScreenCaptureAccess()
        relaunchSuggested = true
        refresh()
        if !screenRecording { openPrivacyPane("Privacy_ScreenCapture") }
    }

    /// Accessibility grants take effect without a relaunch. Only a button/menu action calls this.
    func requestAccessibility(repairing: Bool = true) {
        if repairing && settings.askedAccessibility && !AXIsProcessTrusted() { resetRecord(.accessibility) }
        settings.askedAccessibility = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
        if !accessibility { openPrivacyPane("Privacy_Accessibility") }
    }

    /// Allow in System Settings, for the clipboard (Settings › General): Privacy & Security › Paste
    /// from Other Apps, where the person sets Sill to Allow. While macOS has not asked about Sill yet
    /// (`notAsked`), it is not listed there, so one read first has macOS ask (MacClipboard.askOnce),
    /// and the pane opens once that alert is answered.
    func allowClipboard() {
        guard clipboardAccess == .notAsked else { openPrivacyPane("Privacy_Pasteboard"); return }
        MacClipboard.askOnce { [weak self] in
            Task { @MainActor in
                self?.refresh()
                self?.openPrivacyPane("Privacy_Pasteboard")
            }
        }
    }

    /// System Settings › Privacy & Security, at `anchor`'s pane when that link opens, else at the
    /// top of Privacy & Security.
    func openPrivacyPane(_ anchor: String? = nil) {
        let root = "x-apple.systempreferences:com.apple.preference.security"
        if let anchor, let url = URL(string: "\(root)?\(anchor)"), NSWorkspace.shared.open(url) { return }
        if let url = URL(string: root) { NSWorkspace.shared.open(url) }
    }

    /// Quits and opens Sill again, so a Screen Recording grant takes effect. A shell outlives this
    /// process, waits until it has exited, then has LaunchServices open the bundle, so Sill, not
    /// the shell, is the responsible process for its permissions. From a button or menu action
    /// only: terminate can run a modal loop (see AppDelegate).
    func relaunch() {
        if canRelaunch {
            let shell = Process()
            shell.executableURL = URL(fileURLWithPath: "/bin/sh")
            shell.arguments = ["-c", "while /bin/kill -0 \"$1\" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$0\"",
                               Bundle.main.bundlePath, String(ProcessInfo.processInfo.processIdentifier)]
            do { try shell.run() } catch { print("Relaunch failed: \(error.localizedDescription)") }
        }
        NSApp.terminate(nil)
    }
}
