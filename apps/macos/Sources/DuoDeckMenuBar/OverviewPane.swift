import AppKit
import SwiftUI
import DuoDeckHostCore
import StreamProtocol

/// The everyday controls: host state, one setup action, login, clipboard, and updates.
struct GeneralPane: View {
    let model: AppModel
    @Bindable var settings: HostSettings
    var previewUpdates: UpdatePolicy.Pane?
    var previewClipboardAccess: ClipboardPolicy.MacAccess?
    var previewFirewall: FirewallRule.Verdict?
    var previewPresentation: StatusPresentation?
    var previewAllPermissionsGranted: Bool?

    private var presentation: StatusPresentation { previewPresentation ?? model.presentation }
    private var allPermissionsGranted: Bool { previewAllPermissionsGranted ?? model.permissions.allGranted }

    @State private var showConnectionDetails = false
    @State private var showUpdates = false

    /// Setup and firewall have dedicated controls below; other real issues remain visible.
    private var attention: [StatusPresentation.Attention] {
        presentation.attention.filter {
            switch $0.action {
            case .allowScreenRecording, .allowAccessibility, .showGeneral: false
            default: true
            }
        }
    }

    private func review(_ action: StatusPresentation.Attention.Action) {
        switch action {
        case .showRemoteAccess: model.showSettings?(.remoteAccess)
        case .showDevices: model.showSettings?(.devices)
        case .pairingRequest(let name, let showing): model.showPairingRequest(name: name, showing: showing)
        case .allowScreenRecording, .allowAccessibility: model.showSettings?(.permissions)
        case .showGeneral: model.showSettings?(.general)
        case .none: break
        }
    }

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Image(systemName: DuoDeckHostStyle.statusSymbol(presentation.glyph))
                        .foregroundStyle(DuoDeckHostStyle.statusColor(presentation.glyph))
                } label: {
                    Text(presentation.header).fontWeight(.medium)
                    Text(presentation.subtitle ?? "Open DuoDeck on your iPhone or iPad to connect.")
                }
                ForEach(attention) { item in
                    LabeledContent {
                        if item.action != .none {
                            Button("Review…") { review(item.action) }
                                .accessibilityLabel("Review \(item.title)")
                        }
                    } label: {
                        Label(item.title, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(item.subtitle)
                    }
                }
                if let source = presentation.source { DuoDeckStatusRow(row: source, showDetails: false) }
                ForEach(presentation.devices) { DuoDeckStatusRow(row: $0, showDetails: false) }
                HStack(spacing: 10) {
                    if !allPermissionsGranted {
                        Button("Finish Setup…") { model.showSettings?(.permissions) }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Pair iPhone or iPad…") { model.pairDevice() }
                            .buttonStyle(.borderedProminent)
                            .disabled(!presentation.canPair)
                            .keyboardShortcut("p", modifiers: [.command, .shift])
                    }
                    Spacer()
                    Button("Devices…") { model.showSettings?(.devices) }
                }
                if presentation.source != nil || !presentation.devices.isEmpty {
                    DisclosureGroup("Connection details", isExpanded: $showConnectionDetails) {
                        if let source = presentation.source { DuoDeckStatusRow(row: source) }
                        ForEach(presentation.devices) { DuoDeckStatusRow(row: $0) }
                    }
                }
            } header: {
                Text(presentation.advertisedName ?? "This Mac")
            }

            if let firewall = previewFirewall ?? model.coordinator?.status.snapshot.firewall, firewall.blocksDevices {
                FirewallSection(verdict: firewall)
            }

            Section {
                Toggle("Launch at login", isOn: Binding(get: { model.loginItem.isOn }, set: { model.loginItem.set($0) }))
                    .disabled(!model.loginItem.available)
                if model.loginItem.needsApproval {
                    Button("Approve Login Item…") { model.loginItem.openSystemSettings() }
                }
                if let error = model.loginItem.error {
                    Text(error).font(.callout).foregroundStyle(.red)
                }
            }

            ClipboardSection(shareClipboard: $settings.config.shareClipboard,
                             access: previewClipboardAccess ?? model.permissions.clipboardAccess,
                             allow: { model.permissions.allowClipboard() })

            Section {
                DisclosureGroup("Updates", isExpanded: $showUpdates) {
                    if let preview = previewUpdates {
                        UpdatesSection(pane: preview, automatic: .constant(true))
                    } else {
                        UpdatesSection(pane: model.updates.pane, automatic: $settings.updateCheck,
                                       actions: UpdatesSection.Actions(checkNow: { model.updates.checkNow() },
                                                                       openRelease: { NSWorkspace.shared.open($0) }))
                    }
                }
            }
        }
    }
}
