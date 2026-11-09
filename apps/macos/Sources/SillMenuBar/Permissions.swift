import AppKit
import ApplicationServices
import CoreGraphics
import Observation
import SillHostCore
import StreamProtocol

/// Screen Recording and Accessibility, for Sill itself, and what macOS lets it do with the clipboard
/// (`clipboardAccess`). TCC keys them to the bundle ID plus the code's designated requirement, so a
/// rebuild signed with the same Apple Development identity keeps them, and what Terminal was granted
/// for the SillHost CLI does not carry over.
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
    }

    /// Explicit user action. macOS decides whether this app identity needs a prompt; a saved UI
    /// preference must not suppress the request after the app's signing identity changes.
    func requestScreenRecording() {
        settings.askedScreenRecording = true
        _ = CGRequestScreenCaptureAccess()
        relaunchSuggested = true
        refresh()
        if !screenRecording { openPrivacyPane("Privacy_ScreenCapture") }
    }

    /// Accessibility grants take effect without a relaunch. Only a button/menu action calls this.
    func requestAccessibility() {
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
