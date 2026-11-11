import AppKit
import SwiftUI
import SillHostCore

/// DuoDeck Host's home: the window the app opens with and that the Dock, the menu bar item and
/// ⌘0 bring back. A plain macOS grouped form, like a System Settings pane: what is happening now,
/// the switches people change between sessions, and the paired devices. Everything else stays in
/// Settings (⌘,).
@MainActor
final class HomeWindowController: NSWindowController, NSWindowDelegate {
    private static let frameName = "DuoDeckHomeWindow3"   // 3: the native grouped form

    init(model: AppModel) {
        let host = NSHostingController(rootView: HomeView(model: model))
        host.sizingOptions = []
        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = "DuoDeck"
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.collectionBehavior.formUnion([.moveToActiveSpace])
        window.contentMinSize = NSSize(width: 420, height: 420)
        window.setContentSize(NSSize(width: 460, height: 640))
        super.init(window: window)
        window.delegate = self
        if !window.setFrameUsingName(Self.frameName) { window.center() }
        window.setFrameAutosaveName(Self.frameName)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not from a nib") }

    func show() {
        guard let window else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

// MARK: - The view

struct HomeView: View {
    let model: AppModel
    /// Harness overrides, so previews can draw each state without a running host.
    var previewPresentation: StatusPresentation?
    var previewAllGranted: Bool?
    var previewPaired: [PairedDeviceSummary]?

    private var presentation: StatusPresentation { previewPresentation ?? model.presentation }
    private var allGranted: Bool { previewAllGranted ?? model.permissions.allGranted }
    private var paired: [PairedDeviceSummary] { previewPaired ?? model.coordinator?.status.snapshot.remote?.paired ?? [] }

    private static let iosApp = URL(string: "https://apps.apple.com/app/id6832548998")!

    var body: some View {
        Form {
            header
            if !allGranted {
                PermissionsSection(permissions: model.permissions)
            } else {
                nowSection
                if !presentation.attention.isEmpty { attentionSection }
                StreamingSection(model: model, settings: model.settings)
                devicesSection
            }
        }
        .formStyle(.grouped)
        .tint(DuoDeckHostStyle.accent)
        .frame(minWidth: 420, minHeight: 420)
        .onAppear { model.permissions.refresh() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { model.showSettings?(nil) } label: { Label("Settings", systemImage: "gearshape") }
                    .help("Settings")
            }
        }
    }

    // MARK: Header: the app, this Mac, and its state in one line

    private var header: some View {
        Section {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(presentation.advertisedName ?? "This Mac").font(.headline)
                    HStack(spacing: 6) {
                        Circle().fill(stateColor).frame(width: 7, height: 7)
                        Text(stateLine).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
        }
    }

    private var stateLine: String {
        if !allGranted { return "Needs two permissions" }
        switch presentation.glyph {
        case .idle: return paired.isEmpty ? "Ready to pair" : "Ready · waiting for a device"
        default: return presentation.header
        }
    }

    private var stateColor: Color {
        if !allGranted { return .orange }
        switch presentation.glyph {
        case .streaming, .connected: return .green
        case .attention: return .orange
        case .idle: return .secondary
        }
    }

    // MARK: Now: what streams and to whom, or how to connect

    @ViewBuilder private var nowSection: some View {
        if !presentation.devices.isEmpty {
            Section("Now") {
                if let source = presentation.source {
                    LabeledContent {
                        EmptyView()
                    } label: {
                        Label { Text(source.title).lineLimit(1).truncationMode(.middle) } icon: { Image(systemName: source.symbol) }
                        if let detail = source.detail { Text(detail).monospacedDigit() }
                    }
                }
                ForEach(presentation.devices) { device in
                    LabeledContent {
                        if let issue = device.issue { Text(issue).foregroundStyle(.orange) }
                    } label: {
                        Label { Text(DuoDeckHostStyle.deviceName(device.title)) } icon: { Image(systemName: device.symbol) }
                        if let detail = device.detail { Text(detail).monospacedDigit() }
                    }
                }
            }
        } else if paired.isEmpty {
            Section {
                LabeledContent {
                    Button("Pair…") { model.pairDevice() }.disabled(!presentation.canPair)
                } label: {
                    Text("Connect your iPhone or iPad")
                    Text("Open DuoDeck on the device, then pair it with this Mac's code.")
                }
                LabeledContent {
                    Button("App Store") { NSWorkspace.shared.open(Self.iosApp) }
                } label: {
                    Text("Get DuoDeck for iPhone and iPad")
                    Text("Free on the App Store.")
                }
            } header: {
                Text("Get started")
            }
        } else {
            Section("Now") {
                LabeledContent {
                    EmptyView()
                } label: {
                    Text("No device connected")
                    Text("Open DuoDeck on your iPhone or iPad and tap this Mac.")
                }
            }
        }
    }

    private var attentionSection: some View {
        Section {
            ForEach(presentation.attention) { item in
                LabeledContent {
                    if item.action != .none { Button("Review…") { review(item.action) } }
                } label: {
                    Label { Text(item.title) } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    Text(item.subtitle)
                }
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

    // MARK: Devices

    private var devicesSection: some View {
        Section {
            ForEach(paired.sorted { ($0.lastSeen ?? $0.pairedAt) > ($1.lastSeen ?? $1.pairedAt) }.prefix(6), id: \.id) { device in
                let connected = presentation.devices.contains { DuoDeckHostStyle.deviceName($0.title) == DuoDeckHostStyle.deviceName(device.name) }
                LabeledContent {
                    if connected { Text("Connected").foregroundStyle(.green) }
                } label: {
                    Label { Text(DuoDeckHostStyle.deviceName(device.name)) } icon: {
                        Image(systemName: (device.model ?? device.name).lowercased().contains("iphone") ? "iphone" : "ipad")
                    }
                    Text(Self.lastConnected(device))
                }
            }
            HStack {
                Button("Pair iPhone or iPad…") { model.pairDevice() }.disabled(!presentation.canPair)
                Spacer()
                if !paired.isEmpty { Button("Manage…") { model.showSettings?(.devices) } }
            }
        } header: {
            Text("Paired devices")
        }
    }

    private static func lastConnected(_ device: PairedDeviceSummary) -> String {
        guard let seen = device.lastSeen else { return "Not connected yet" }
        if Date().timeIntervalSince(seen) < 60 { return "Last connected just now" + (device.lastRoute.map { " \($0)" } ?? "") }
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .full; f.dateTimeStyle = .named
        return "Last connected \(f.localizedString(for: seen, relativeTo: Date()))" + (device.lastRoute.map { " \($0)" } ?? "")
    }
}

// MARK: - Sections

/// The switches people change between sessions, bound to the same settings as Settings.
private struct StreamingSection: View {
    let model: AppModel
    @Bindable var settings: HostSettings

    private var snapshot: HostStatusSnapshot? { model.coordinator?.status.snapshot }

    var body: some View {
        Section {
            Picker(selection: preset) {
                ForEach(DuoDeckStreamingPreset.allCases) { Text($0.title).tag($0.rawValue) }
                if DuoDeckStreamingPreset.current(in: settings.config) == nil { Text("Custom").tag("custom") }
            } label: {
                Text("Picture")
                Text(DuoDeckStreamingPreset.current(in: settings.config)?.detail ?? "Set in Settings › Streaming")
            }
            if snapshot?.virtualDisplayAPIMissing != true {
                Toggle(isOn: $settings.config.virtualDisplay) {
                    Text("Fit windows to the device")
                    Text("Each window gets its own display at your device's size.")
                }
            }
            Toggle(isOn: $settings.config.sendAudio) {
                Text("Sound")
                Text(settings.config.sendAudio && snapshot?.audio?.problem != nil
                     ? "Not available right now." : "Play your Mac's sound on the device.")
            }
            Toggle(isOn: $settings.config.shareClipboard) {
                Text("Clipboard")
                Text("Copy on one, paste on the other.")
            }
            Toggle(isOn: $settings.config.remoteAccess) {
                Text("Away from home")
                Text(remoteNote)
            }
        } header: {
            Text("Streaming")
        }
    }

    private var remoteNote: String {
        if let note = model.presentation.remoteAccessNote, note != "Off" { return note }
        return "Reach this Mac from anywhere."
    }

    private var preset: Binding<String> {
        Binding(get: { DuoDeckStreamingPreset.current(in: settings.config)?.rawValue ?? "custom" },
                set: { if let p = DuoDeckStreamingPreset(rawValue: $0) { settings.config = p.applying(to: settings.config) } })
    }
}

/// The two macOS permissions, each with its own button, until both are on.
private struct PermissionsSection: View {
    let permissions: PermissionsModel

    var body: some View {
        Section {
            row("Screen Recording", "Shows your windows on the device.", granted: permissions.screenRecording) {
                permissions.requestScreenRecording()
            }
            row("Accessibility", "Lets your taps and typing reach the Mac.", granted: permissions.accessibility) {
                permissions.requestAccessibility()
            }
        } header: {
            Text("Finish setup")
        } footer: {
            Text("DuoDeck needs both to stream and control this Mac.").foregroundStyle(.secondary)
        }
    }

    private func row(_ title: String, _ detail: String, granted: Bool, allow: @escaping () -> Void) -> some View {
        LabeledContent {
            if granted {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityLabel("Allowed")
            } else {
                Button("Allow…", action: allow)
            }
        } label: {
            Text(title)
            Text(detail)
        }
    }
}
