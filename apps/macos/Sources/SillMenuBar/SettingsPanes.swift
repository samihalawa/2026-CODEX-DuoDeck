import AppKit
import Combine
import SwiftUI
import SillHostCore
import StreamProtocol

/// One navigation section: a native grouped Form inside the resizable main window. The controls bind straight to
/// `settings.config`, whose didSet is the one path to the host (see HostSettings).
struct SettingsPane: View {
    let tab: SettingsTab
    let model: AppModel
    /// The previews (DebugHooks): General's update section in this state instead of the live one,
    /// so a render does not depend on what an earlier run stored.
    var previewUpdates: UpdatePolicy.Pane?
    /// …and its clipboard section with macOS's answer as given, never read from this Mac.
    var previewClipboardAccess: ClipboardPolicy.MacAccess?
    /// …and what the macOS firewall does as given (FirewallRule), never asked.
    var previewFirewall: FirewallRule.Verdict?

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
            case .general: GeneralPane(model: model, settings: model.settings, previewUpdates: previewUpdates,
                                       previewClipboardAccess: previewClipboardAccess, previewFirewall: previewFirewall)
            case .devices: LiveDevicesPane(model: model, settings: model.settings)
            case .streaming: StreamingPane(model: model, settings: model.settings)
            case .advanced: AdvancedPane(model: model, settings: model.settings)
            case .virtualDisplay: VirtualDisplayPane(model: model, settings: model.settings)
            case .permissions: PermissionsPane(model: model)
            case .remoteAccess: LiveRemoteAccessPane(model: model, settings: model.settings)
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 560, maxWidth: .infinity, minHeight: 360, maxHeight: .infinity)
        .tint(DuoDeckHostStyle.accent)
        // Permissions and the login item change behind Sill's back, in System Settings. Re-read
        // them once a second, only while this tab is on screen, and when Sill becomes active; an
        // idle Sill with Settings closed wakes for nothing. The Devices and Remote Access panes
        // follow the host's status, which is pushed, so they poll nothing.
        .task(id: model.visibleSettingsTab) {
            // General on screen: whether the macOS firewall blocks Sill, asked again (FirewallCheck).
            if model.visibleSettingsTab == tab, tab == .general { model.coordinator?.checkFirewall() }
            guard let visible = model.visibleSettingsTab, visible.navigationGroup == tab.navigationGroup,
                  visible != .streaming, visible != .devices, visible != .remoteAccess, visible != .advanced else { return }
            while !Task.isCancelled {
                model.permissions.refresh()
                model.loginItem.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.permissions.refresh()
            model.loginItem.refresh()
            // Back from Terminal with the command run: General's firewall line follows.
            if model.visibleSettingsTab == tab, tab == .general { model.coordinator?.checkFirewall() }
        }
    }
}

/// Footer text the way System Settings sets it: small, secondary, from the leading edge.
struct Footnote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// An orange problem line with its sign.
struct Warning: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A system error message inside a sentence of ours: without its own full stop.
func withoutFullStop(_ text: String) -> String {
    text.hasSuffix(".") ? String(text.dropLast()) : text
}

// MARK: Firewall

/// The macOS firewall keeps devices out (FirewallRule; a user's report of 2026-10-29), in the
/// Permissions pane's style: what it blocks and why that matters, then the Terminal command that
/// unblocks Sill, the running executable's path in it, with Copy; or, for Block all incoming
/// connections, where to turn it off. Nothing while the firewall lets devices in. Sill never runs the
/// command itself (it needs an administrator). Drawn alone in the previews in each verdict.
struct FirewallSection: View {
    let verdict: FirewallRule.Verdict
    @State private var copied = false

    var body: some View {
        if let line = FirewallRule.Copy.paneLine(verdict) {
            let command = FirewallRule.Copy.command(verdict)
            Section {
                LabeledContent {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        if let command {
                            Button(copied ? "Copied" : "Copy") { copy(command) }
                                .help("Copies the command, to paste into Terminal")
                        }
                    }
                } label: {
                    Text("Firewall")
                    Text(line.replacingOccurrences(of: "Sill’s executable", with: "DuoDeck Host"))
                }
                if let lines = FirewallRule.Copy.commandLines(verdict) {
                    // A line for the tool and one for each option, never "--" over "unblockapp".
                    Text(verbatim: lines.joined(separator: "\n"))
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(command ?? "")
                }
            }
        }
    }

    /// The command onto the clipboard, and "Copied" on the button for 2 s (VoiceOver hears it).
    private func copy(_ command: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        copied = true
        AccessibilityNotification.Announcement("Copied").post()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }
}

// MARK: Clipboard

/// Share clipboard with devices (HostClipboard, docs/clipboard-plan.md): the switch and its footnote,
/// and while the switch is on and macOS does not allow every read Sill makes on its own
/// (ClipboardPolicy.MacAccess), why what is copied here stays on this Mac and the way to allow it.
/// Drawn alone in the previews in each of macOS's answers (DebugHooks).
struct ClipboardSection: View {
    @Binding var shareClipboard: Bool
    let access: ClipboardPolicy.MacAccess
    var allow: () -> Void = {}

    var body: some View {
        Section {
            Toggle("Share clipboard with devices", isOn: $shareClipboard)
            if shareClipboard, let warning = ClipboardPolicy.Copy.macAccessWarning(access) {
                VStack(alignment: .leading, spacing: 6) {
                    Warning(warning.replacingOccurrences(of: "Sill", with: "DuoDeck Host"))
                    if let hint = ClipboardPolicy.Copy.macAccessHint(access) {
                        Text(hint.replacingOccurrences(of: "Sill", with: "DuoDeck Host"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button(ClipboardPolicy.Copy.macAccessButton, action: allow)
                }
            }
        } footer: {
            Footnote(ClipboardPolicy.Copy.macFootnote)
        }
    }
}

// MARK: Updates

/// Settings › General's update check: the automatic switch, the line (what the last check found, or
/// why Sill cannot check), Open Release Page… while a newer release is offered, and Check Now. Plain
/// values in, so the previews draw every state. Errors show here and in the log, never in an alert.
struct UpdatesSection: View {
    struct Actions {
        var checkNow: () -> Void = {}
        var openRelease: (URL) -> Void = { _ in }
    }

    let pane: UpdatePolicy.Pane
    @Binding var automatic: Bool
    var actions = Actions()

    var body: some View {
        Section {
            Toggle("Check for updates automatically", isOn: $automatic)
            LabeledContent {
                HStack(spacing: 8) {
                    if let url = pane.releasePage {
                        Button("Open Release Page…") { actions.openRelease(url) }
                    }
                    Button("Check Now") { actions.checkNow() }
                        .disabled(!pane.canCheck)
                }
            } label: {
                Text(pane.line)
                    .foregroundStyle(pane.failed ? Color.orange : Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // VoiceOver hears Check Now's result, which arrives after the click.
            .onChange(of: pane.resultID) { _, _ in
                AccessibilityNotification.Announcement(pane.line).post()
            }
        } footer: {
            Footnote(UpdatePolicy.footnote)
        }
    }
}

// MARK: Virtual Display

struct VirtualDisplayPane: View {
    let model: AppModel
    @Bindable var settings: HostSettings
    @State private var retrying = false

    var body: some View {
        let snapshot = model.coordinator?.status.snapshot ?? HostStatusSnapshot()
        Form {
            Section {
                Toggle("Stream from a virtual display", isOn: $settings.config.virtualDisplay)
            } footer: {
                Footnote("DuoDeck Host moves the window you pick onto an invisible display made for your device, so it keeps updating when other windows cover it and text is drawn at your device’s scale. The window leaves this screen while it streams and comes back when you stop streaming or quit DuoDeck Host.")
            }
            Section {
                LabeledContent("Status") {
                    HStack(spacing: 8) {
                        Text(statusText(snapshot))
                            .multilineTextAlignment(.trailing)
                        if canRetry(snapshot) {
                            Button("Try Again") {
                                retrying = true
                                Task { @MainActor in
                                    await model.coordinator?.retryVirtualDisplay()
                                    retrying = false
                                }
                            }
                            .disabled(retrying || model.coordinator == nil)
                        }
                    }
                }
                if settings.config.virtualDisplay, let failure = snapshot.lastStageFailure {
                    LabeledContent("Last window") {
                        Text("Streamed where it is: \(failure)").multilineTextAlignment(.trailing)
                    }
                }
            } footer: {
                Footnote("Uses a private macOS interface (CGVirtualDisplay). If a macOS update breaks it, DuoDeck Host streams the window where it is.")
            }
        }
    }

    private func statusText(_ s: HostStatusSnapshot) -> String {
        let sr = model.permissions.screenRecording, ax = model.permissions.accessibility
        if s.virtualDisplayAPIMissing, let problem = s.virtualDisplayProblem {
            return "Not available on this version of macOS: \(problem)"
        }
        if !sr && !ax { return "Needs Screen Recording and Accessibility" }
        if !ax { return "Needs Accessibility" }
        if !sr { return "Needs Screen Recording" }
        if let problem = s.virtualDisplayProblem { return "Off for this session: \(problem)" }
        return "Available"
    }

    /// A run-level disable (the system removed the display too often) can be retried; a missing
    /// API or permission cannot.
    private func canRetry(_ s: HostStatusSnapshot) -> Bool {
        s.virtualDisplayProblem != nil && !s.virtualDisplayAPIMissing && model.permissions.allGranted
    }
}

// MARK: Permissions

struct PermissionsPane: View {
    let model: AppModel

    var body: some View {
        let permissions = model.permissions
        let network = model.coordinator?.status.snapshot.network
        Form {
            Section {
                PermissionRow(title: "Screen Recording", allowed: permissions.screenRecording,
                              // Not "on this network": a device connected over Direct Wireless shares none.
                              explanation: "Lets DuoDeck Host capture the windows you pick on your iPhone or iPad, and their sound when Send Audio is on. Nothing is recorded or saved; frames and sound go straight to your devices.",
                              button: "Allow…") {
                    permissions.requestScreenRecording()
                }
                PermissionRow(title: "Accessibility", allowed: permissions.accessibility,
                              explanation: "Lets your iPhone or iPad click, scroll and type on this Mac, and lets DuoDeck Host move and size the window it streams.",
                              button: "Allow…") {
                    permissions.requestAccessibility()
                }
            } footer: {
                Footnote("In System Settings, allow DuoDeck Host itself. macOS decides whether access is granted.")
            }
            if !permissions.allGranted {
                Section {
                    LabeledContent("App requesting access") {
                        Text(Bundle.main.bundlePath)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    LabeledContent {
                        Button("Repair Permissions") { permissions.repairPermissions() }
                    } label: {
                        Text("Already on in System Settings?")
                        Text("DuoDeck Host clears the old macOS record and asks again for this copy.")
                    }
                    Button("Show App in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                    }
                } footer: {
                    Footnote("Enable DuoDeck Host in both Screen Recording and Accessibility. If a switch is already on but this page still asks, use Repair Permissions.")
                }
            }
            if permissions.outsideApplications {
                Section {
                    LabeledContent {
                        Button("Move to Applications") { permissions.moveToApplications() }
                    } label: {
                        Text("DuoDeck Host isn’t in Applications")
                        Text("Permissions stay with the copy you allowed. Move it to Applications and allow that copy.")
                    }
                }
            }
            if !permissions.otherCopies.isEmpty {
                Section {
                    LabeledContent {
                        Button("Move to Trash") { permissions.trashOtherCopies() }
                    } label: {
                        Text(permissions.otherCopies.count == 1 ? "Another copy of DuoDeck Host" : "\(permissions.otherCopies.count) other copies of DuoDeck Host")
                        Text(permissions.otherCopies.map { $0.path }.joined(separator: "\n"))
                            .textSelection(.enabled)
                    }
                } footer: {
                    Footnote("System Settings shows every copy as DuoDeck Host, so a switch can belong to one you don’t use. Keeping one copy avoids that.")
                }
            }
            if let note = permissions.repairNote {
                Section { Text(note) }
            }
            if permissions.relaunchSuggested {
                Section {
                    LabeledContent(permissions.screenRecording
                                   ? "If sharing has not started, reopen DuoDeck Host to apply the change."
                                   : "After enabling Screen Recording, reopen DuoDeck Host to apply the change.") {
                        Button(permissions.canRelaunch ? "Relaunch DuoDeck Host" : "Quit DuoDeck Host") { permissions.relaunch() }
                    }
                }
            }
            if Self.networkNeedsHelp(network) {
                Section {
                    LabeledContent {
                        Button("Open Local Network…") { permissions.openPrivacyPane("Privacy_LocalNetwork") }
                    } label: {
                        Text("Local Network")
                        Text("If your iPhone or iPad can’t find this Mac, allow DuoDeck Host in Privacy & Security › Local Network.")
                    }
                }
            }
            if permissions.allGranted {
                Section {
                    Label("You’re all set. Open DuoDeck on your iPhone or iPad.", systemImage: "checkmark.seal.fill")
                }
            }
        }
    }

    private static func networkNeedsHelp(_ network: HostStatusSnapshot.Network?) -> Bool {
        switch network {
        case .waiting, .failed: return true
        default: return false
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let allowed: Bool
    let explanation: String
    let button: String
    let action: () -> Void

    var body: some View {
        LabeledContent {
            if allowed {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Button(button, action: action)
                }
            }
        } label: {
            Text(title)
            Text(explanation)
        }
    }
}
