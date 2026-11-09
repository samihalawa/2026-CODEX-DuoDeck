import AppKit
import SwiftUI
import SillHostCore
import StreamProtocol

/// The everyday controls live here. Connection tuning and diagnostics are deliberate disclosures.
struct GeneralPane: View {
    let model: AppModel
    @Bindable var settings: HostSettings
    var previewUpdates: UpdatePolicy.Pane?
    var previewClipboardAccess: ClipboardPolicy.MacAccess?
    var previewFirewall: FirewallRule.Verdict?

    @State private var showConnectionOptions = false
    @State private var showUpdates = false
    @State private var showDiagnostics = false

    private var installedInApplications: Bool {
        let path = Bundle.main.bundlePath
        return path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Image(systemName: model.presentation.glyph == .attention
                          ? "exclamationmark.circle.fill" : model.presentation.glyph == .idle ? "circle.dotted" : "checkmark.circle.fill")
                        .foregroundStyle(model.presentation.glyph == .attention ? Color.orange : DuoDeckHostStyle.accent)
                } label: {
                    Text(model.presentation.header).fontWeight(.medium)
                    Text(model.presentation.subtitle ?? "Open DuoDeck on your iPhone or iPad to connect.")
                }
                if let source = model.presentation.source { DuoDeckStatusRow(row: source) }
                ForEach(model.presentation.devices) { DuoDeckStatusRow(row: $0) }
                HStack(spacing: 10) {
                    if !model.permissions.allGranted {
                        Button("Finish Setup…") { model.showSettings?(.permissions) }
                            .buttonStyle(.borderedProminent)
                    }
                    Button("Pair a Device…") { model.pairDevice() }
                        .disabled(!model.presentation.canPair)
                        .keyboardShortcut("p", modifiers: [.command, .shift])
                    Spacer()
                    Button("Devices…") { model.showSettings?(.devices) }
                }
            } header: {
                Text("Your Mac")
            }

            if let firewall = previewFirewall ?? model.coordinator?.status.snapshot.firewall, firewall.blocksDevices {
                FirewallSection(verdict: firewall)
            }

            Section {
                Picker("Stream quality", selection: profile) {
                    ForEach(DuoDeckStreamingPreset.allCases) { Text($0.title).tag($0.rawValue) }
                    if DuoDeckStreamingPreset.current(in: settings.config) == nil { Text("Custom").tag("custom") }
                }
                Toggle("Launch at login", isOn: Binding(get: { model.loginItem.isOn }, set: { model.loginItem.set($0) }))
                    .disabled(!model.loginItem.available)
                if model.loginItem.needsApproval {
                    Button("Approve Login Item…") { model.loginItem.openSystemSettings() }
                }
                if let error = model.loginItem.error {
                    Text(error).font(.callout).foregroundStyle(.red)
                }
            } header: {
                Text("Everyday settings")
            } footer: {
                Footnote(model.presentation.away
                         ? "Using your away quality now. Adjust it in Streaming settings."
                         : "Balanced is a good starting point. Changes apply to the current stream.")
            }

            ClipboardSection(shareClipboard: $settings.config.shareClipboard,
                             access: previewClipboardAccess ?? model.permissions.clipboardAccess,
                             allow: { model.permissions.allowClipboard() })

            Section {
                DisclosureGroup("Connection options", isExpanded: $showConnectionOptions) {
                    LabeledContent("Network name", value: networkName)
                    Toggle("Connect directly over Wi-Fi", isOn: $settings.config.directWireless)
                    Footnote("Use this when your devices are nearby without a shared network. It can reduce performance on a shared Wi-Fi connection.")
                    HStack {
                        Button("Remote Access…") { model.showSettings?(.remoteAccess) }
                        Button("Rename This Mac…") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Sharing-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                    .padding(.top, 3)
                }
                DisclosureGroup("Updates", isExpanded: $showUpdates) {
                    if let preview = previewUpdates {
                        UpdatesSection(pane: preview, automatic: .constant(true))
                    } else {
                        UpdatesSection(pane: model.updates.pane, automatic: $settings.updateCheck,
                                       actions: UpdatesSection.Actions(checkNow: { model.updates.checkNow() },
                                                                       openRelease: { NSWorkspace.shared.open($0) }))
                    }
                }
                DisclosureGroup("About & diagnostics", isExpanded: $showDiagnostics) {
                    LabeledContent("Version", value: "\(AppModel.version) (\(AppModel.build))")
                    LabeledContent("Running from") {
                        Text(Bundle.main.bundlePath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    if !installedInApplications {
                        Footnote("Keep the app in Applications so its login item and permissions stay with the same copy.")
                    }
                    HStack {
                        Button("Show Log…") { model.showLog?() }
                        Button("Reveal Log File") {
                            if let url = HostLog.shared.fileURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                        }
                        .disabled(HostLog.shared.fileURL == nil)
                        Spacer()
                        Link("Help", destination: URL(string: "https://duodeck.megawebs.com/#how")!)
                    }
                    Footnote("DuoDeck by Agents AI Ltd. Built on the Apache 2.0-licensed Sill streaming engine.")
                    Button("Quit DuoDeck Host") { NSApp.terminate(nil) }
                        .padding(.top, 4)
                }
            }
        }
    }

    private var profile: Binding<String> {
        Binding(get: { DuoDeckStreamingPreset.current(in: settings.config)?.rawValue ?? "custom" },
                set: { value in
                    if let preset = DuoDeckStreamingPreset(rawValue: value) {
                        settings.config = preset.applying(to: settings.config)
                    }
                })
    }

    private var networkName: String {
        let snapshot = model.coordinator?.status.snapshot ?? HostStatusSnapshot()
        switch snapshot.network {
        case .advertising(let name): return name
        case .notAdvertised: return "Not advertised in test mode"
        case .failed: return "Unavailable"
        case .waiting: return "Waiting for the network"
        case .starting, .registering: return "Registering…"
        }
    }
}
