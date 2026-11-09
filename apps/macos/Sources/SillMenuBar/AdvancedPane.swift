import AppKit
import SwiftUI
import SillHostCore

/// Legacy settings routes remain valid, grouped under one Advanced toolbar item.
struct AdvancedPane: View {
    let model: AppModel
    @Bindable var settings: HostSettings
    var previewTab: SettingsTab?

    private var destination: SettingsTab {
        let tab = previewTab ?? settings.settingsTab
        return tab.navigationGroup == .advanced ? tab : .advanced
    }

    var body: some View {
        if destination == .advanced {
            AdvancedOptionsPane(model: model, settings: settings)
        } else {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        model.showSettings?(.advanced)
                    } label: {
                        Label("Advanced", systemImage: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                    Text(destination.title).fontWeight(.medium)
                    Spacer()
                    // Balance the back control without adding an invisible focusable button.
                    Color.clear.frame(width: 88, height: 1).accessibilityHidden(true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)
                Group {
                    switch destination {
                    case .virtualDisplay: VirtualDisplayPane(model: model, settings: settings)
                    case .permissions: PermissionsPane(model: model)
                    case .remoteAccess: LiveRemoteAccessPane(model: model, settings: settings)
                    default: EmptyView()
                    }
                }
            }
        }
    }
}

private struct AdvancedOptionsPane: View {
    let model: AppModel
    @Bindable var settings: HostSettings
    @State private var showDiagnostics = false

    private var installedInApplications: Bool {
        let path = Bundle.main.bundlePath
        return path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Network name") {
                    Text(networkName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Rename…") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Sharing-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                Toggle("Connect directly over Wi-Fi", isOn: $settings.config.directWireless)
                LabeledContent {
                    Button("Configure…") { model.showSettings?(.remoteAccess) }
                        .accessibilityLabel("Configure remote access")
                } label: {
                    Text("Remote access")
                    Text(model.presentation.remoteAccessNote ?? "Connect through a VPN or the internet.")
                }
            } header: {
                Text("Connections")
            } footer: {
                Footnote("Direct Wi-Fi connects nearby devices without a shared network. It can reduce performance when both devices already share Wi-Fi.")
            }

            Section {
                LabeledContent {
                    Button("Configure…") { model.showSettings?(.virtualDisplay) }
                        .accessibilityLabel("Configure virtual display")
                } label: {
                    Text("Virtual display")
                    Text(settings.config.virtualDisplay ? "On" : "Off")
                }
                LabeledContent {
                    Button("Manage…") { model.showSettings?(.permissions) }
                        .accessibilityLabel("Manage permissions")
                } label: {
                    Text("Permissions")
                    Text(model.permissions.allGranted ? "Screen Recording and Accessibility are allowed." : "Finish setup to stream and control this Mac.")
                }
                Button("Open Privacy & Security…") { model.permissions.openPrivacyPane(nil) }
            }

            Section {
                DisclosureGroup("Diagnostics", isExpanded: $showDiagnostics) {
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
                    }
                    if let source = model.presentation.source { DuoDeckStatusRow(row: source) }
                    ForEach(model.presentation.devices) { DuoDeckStatusRow(row: $0) }
                }
                LabeledContent("DuoDeck Host", value: "\(AppModel.version) (\(AppModel.build))")
                Link("Help", destination: URL(string: "https://duodeck.megawebs.com/#how")!)
            } footer: {
                Footnote("DuoDeck by Agents AI Ltd. Built on the Apache 2.0-licensed Sill streaming engine.")
            }
        }
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
