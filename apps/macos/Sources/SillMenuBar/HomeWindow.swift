import AppKit
import SwiftUI
import SillHostCore

/// DuoDeck Host's home: the window the app opens with and that the Dock, the menu bar item and
/// ⌘0 bring back. A large, quiet window: the state and what is happening now on the left in big
/// type, the switches people change between sessions and the paired devices in a sidebar on the
/// right. Plain window background, standard controls, no decoration. Everything else stays in
/// Settings (⌘,).
@MainActor
final class HomeWindowController: NSWindowController, NSWindowDelegate {
    private static let frameName = "DuoDeckHomeWindow5"   // 5: the large two-column window

    init(model: AppModel) {
        let host = NSHostingController(rootView: HomeView(model: model))
        host.sizingOptions = []
        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.title = "DuoDeck"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.collectionBehavior.formUnion([.moveToActiveSpace, .fullScreenPrimary])
        window.contentMinSize = NSSize(width: 820, height: 540)
        super.init(window: window)
        window.delegate = self
        if !window.setFrameUsingName(Self.frameName) {
            // First open: most of the screen, centred.
            let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
            let size = NSSize(width: min(1180, visible.width * 0.82), height: min(780, visible.height * 0.86))
            window.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                                   width: size.width, height: size.height), display: false)
        }
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
    var previewImage: Data?

    private var presentation: StatusPresentation { previewPresentation ?? model.presentation }
    private var allGranted: Bool { previewAllGranted ?? model.permissions.allGranted }
    private var paired: [PairedDeviceSummary] { previewPaired ?? model.coordinator?.status.snapshot.remote?.paired ?? [] }

    private static let iosApp = URL(string: "https://apps.apple.com/app/id6832548998")!

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 40) {
                heading
                stage
            }
            .padding(.horizontal, 64)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            if allGranted {
                Divider().ignoresSafeArea()
                Sidebar(model: model, settings: model.settings, paired: paired, connected: connectedNames,
                        canPair: presentation.canPair)
                    .frame(width: 320)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(DuoDeckHostStyle.accent)
        .frame(minWidth: 820, minHeight: 540)
        .onAppear { model.permissions.refresh() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { model.showSettings?(nil) } label: { Label("Settings", systemImage: "gearshape") }
                    .help("Settings")
            }
        }
    }

    private var connectedNames: [String] { presentation.devices.map { DuoDeckHostStyle.deviceName($0.title) } }

    // MARK: Heading: the state in large type

    private var heading: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 52, weight: .bold))
                .contentTransition(.opacity)
            HStack(spacing: 8) {
                Circle().fill(stateColor).frame(width: 8, height: 8)
                Text(subtitle).font(.title3).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        if !allGranted { return "Almost ready" }
        switch presentation.glyph {
        case .streaming: return "Streaming"
        case .connected: return "Connected"
        case .attention: return "Needs a look"
        case .idle: return "Ready"
        }
    }

    private var subtitle: String { presentation.advertisedName ?? "This Mac" }

    private var stateColor: Color {
        if !allGranted { return .orange }
        switch presentation.glyph {
        case .streaming, .connected: return .green
        case .attention: return .orange
        case .idle: return Color.secondary.opacity(0.6)
        }
    }

    // MARK: Stage: the one thing that matters now

    @ViewBuilder private var stage: some View {
        if !allGranted {
            PermissionsStage(permissions: model.permissions)
        } else if !presentation.devices.isEmpty {
            StreamingStage(source: presentation.source, devices: presentation.devices,
                           preview: previewImage ?? model.coordinator?.preview.image)
        } else if paired.isEmpty {
            FirstDeviceStage(appURL: Self.iosApp, canPair: presentation.canPair) { model.pairDevice() }
        } else {
            WaitingStage(device: lastDevice)
        }
        ForEach(presentation.attention.filter { allGranted || !($0.action == .allowScreenRecording || $0.action == .allowAccessibility) }) { item in
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(item.title).font(.body.weight(.semibold)).help(item.subtitle)
                Spacer(minLength: 12)
                if item.action != .none { Button("Review…") { review(item.action) } }
            }
        }
    }

    private var lastDevice: String {
        paired.max { ($0.lastSeen ?? $0.pairedAt) < ($1.lastSeen ?? $1.pairedAt) }
            .map { DuoDeckHostStyle.deviceName($0.name) } ?? "device"
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
}

// MARK: - Stages

/// What is showing, then each device with its live numbers set large.
private struct StreamingStage: View {
    let source: StatusPresentation.Row?
    let devices: [StatusPresentation.Row]
    let preview: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let preview, let image = NSImage(data: preview) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 640, maxHeight: 360, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
                    .accessibilityLabel(source.map { "Live preview of \($0.title)" } ?? "Live preview")
                    .transition(.opacity)
            }
            if let source {
                Text(source.title).font(.title2.weight(.semibold)).lineLimit(1).truncationMode(.middle)
            }
            ForEach(devices) { device in
                HStack(alignment: .firstTextBaseline, spacing: 28) {
                    Label(DuoDeckHostStyle.deviceName(device.title), systemImage: device.symbol)
                        .font(.title3).foregroundStyle(.secondary)
                    if let issue = device.issue {
                        Text(issue).foregroundStyle(.orange)
                    } else if let detail = device.detail {
                        Stats(parts: detail.components(separatedBy: " · "))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: preview)
    }
}

/// "118 fps · frame age 9 ms · RTT 7 ms · Wi-Fi" as big figures with small labels under them.
private struct Stats: View {
    let parts: [String]

    private var items: [(value: String, label: String)] {
        parts.map { part in
            if part.hasSuffix(" fps") { return (part.replacingOccurrences(of: " fps", with: ""), "fps") }
            if part.hasPrefix("frame age ") { return (part.replacingOccurrences(of: "frame age ", with: ""), "delay") }
            if part.hasPrefix("RTT ") { return (part.replacingOccurrences(of: "RTT ", with: ""), "round trip") }
            return (part, "link")
        }
        .filter { $0.label != "round trip" }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.value).font(.title3.weight(.semibold)).monospacedDigit()
                    Text(item.label).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A Mac that has never paired: three steps, the App Store code, and Pair.
private struct FirstDeviceStage: View {
    let appURL: URL
    let canPair: Bool
    let pair: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 48) {
            VStack(alignment: .leading, spacing: 22) {
                Step(n: 1, title: "Get DuoDeck on your iPhone or iPad")
                Step(n: 2, title: "Pair it with this Mac")
                Step(n: 3, title: "Pick a window")
                Button(action: pair) { Text("Pair iPhone or iPad…").padding(.horizontal, 8) }
                    .controlSize(.large)
                    .prominent()
                    .disabled(!canPair)
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                    .padding(.top, 6)
            }
            if let image = QRCode.image(for: appURL.absoluteString) {
                VStack(spacing: 8) {
                    Image(decorative: image, scale: 1).interpolation(.none).resizable()
                        .frame(width: 148, height: 148)
                    Text("App Store").font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("App Store code for DuoDeck on iPhone and iPad")
            }
        }
    }
}

private struct Step: View {
    let n: Int
    let title: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("\(n)").font(.title3.weight(.semibold)).foregroundStyle(.tertiary).frame(width: 18, alignment: .leading)
            Text(title).font(.title3)
        }
    }
}

/// Paired before, nobody connected now.
private struct WaitingStage: View {
    let device: String
    var body: some View {
        Text("Open DuoDeck on your \(device).").font(.title2).foregroundStyle(.secondary)
    }
}

/// The two macOS permissions, each with its own button, until both are on.
private struct PermissionsStage: View {
    let permissions: PermissionsModel
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            line("Screen Recording", "Shows your windows on the device.", granted: permissions.screenRecording) {
                permissions.requestScreenRecording()
            }
            line("Accessibility", "Lets your taps and typing reach the Mac.", granted: permissions.accessibility) {
                permissions.requestAccessibility()
            }
        }
    }

    private func line(_ title: String, _ detail: String, granted: Bool, allow: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .font(.title3).foregroundStyle(granted ? Color.green : Color.secondary)
            Text(title).font(.title3).help(detail)
            Spacer(minLength: 24)
            if !granted { Button("Allow…", action: allow).controlSize(.large).prominent() }
        }
        .frame(maxWidth: 520)
    }
}

// MARK: - Sidebar: switches and devices

private struct Sidebar: View {
    let model: AppModel
    @Bindable var settings: HostSettings
    let paired: [PairedDeviceSummary]
    let connected: [String]
    let canPair: Bool

    private var snapshot: HostStatusSnapshot? { model.coordinator?.status.snapshot }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 14) {
                    Caption("Streaming")
                    HStack {
                        Text("Picture")
                        Spacer()
                        Picker("Picture", selection: preset) {
                            ForEach(DuoDeckStreamingPreset.allCases) { Text($0.title).tag($0.rawValue) }
                            if DuoDeckStreamingPreset.current(in: settings.config) == nil { Text("Custom").tag("custom") }
                        }
                        .labelsHidden().fixedSize()
                    }
                    if snapshot?.virtualDisplayAPIMissing != true {
                        Switch(title: "Fit to device", detail: "Each window gets its own display at your device's size.",
                               isOn: $settings.config.virtualDisplay)
                    }
                    Switch(title: "Sound", detail: settings.config.sendAudio && snapshot?.audio?.problem != nil
                           ? "Not available right now." : "Play your Mac's sound on the device.", isOn: $settings.config.sendAudio)
                    Switch(title: "Clipboard", detail: "Copy on one, paste on the other.", isOn: $settings.config.shareClipboard)
                    Switch(title: "Away from home", detail: remoteNote, isOn: $settings.config.remoteAccess)
                    Switch(title: "Without Wi‑Fi", detail: "Lets your devices connect directly: on your iPhone's hotspot, or with no shared network. Can add a little lag while on.",
                           isOn: $settings.config.directWireless)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Caption("Devices")
                        Spacer()
                        if !paired.isEmpty {
                            Button("Manage") { model.showSettings?(.devices) }.buttonStyle(.plain)
                                .font(.callout).foregroundStyle(DuoDeckHostStyle.accent)
                        }
                    }
                    ForEach(sorted.prefix(6), id: \.id) { device in
                        let isConnected = connected.contains(DuoDeckHostStyle.deviceName(device.name))
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: (device.model ?? device.name).lowercased().contains("iphone") ? "iphone" : "ipad")
                                .foregroundStyle(.secondary).frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(DuoDeckHostStyle.deviceName(device.name))
                                Text(isConnected ? "Connected" : Self.lastConnected(device))
                                    .font(.caption).foregroundStyle(isConnected ? Color.green : Color.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Button { model.pairDevice() } label: { Label("Pair device", systemImage: "plus") }
                        .buttonStyle(.plain).foregroundStyle(DuoDeckHostStyle.accent)
                        .disabled(!canPair)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 64)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.never)
    }

    /// Newest first, one line per name (a device paired twice shows once).
    private var sorted: [PairedDeviceSummary] {
        var seen = Set<String>()
        return paired.sorted { ($0.lastSeen ?? $0.pairedAt) > ($1.lastSeen ?? $1.pairedAt) }
            .filter { seen.insert(DuoDeckHostStyle.deviceName($0.name)).inserted }
    }

    private var remoteNote: String {
        if let note = model.presentation.remoteAccessNote, note != "Off" { return note }
        return "Reach this Mac from anywhere."
    }

    private var preset: Binding<String> {
        Binding(get: { DuoDeckStreamingPreset.current(in: settings.config)?.rawValue ?? "custom" },
                set: { if let p = DuoDeckStreamingPreset(rawValue: $0) { settings.config = p.applying(to: settings.config) } })
    }

    private static func lastConnected(_ device: PairedDeviceSummary) -> String {
        guard let seen = device.lastSeen else { return "Never connected" }
        let cal = Calendar.current
        if cal.isDateInToday(seen) { return "Today" }
        if cal.isDateInYesterday(seen) { return "Yesterday" }
        return seen.formatted(.dateTime.month(.abbreviated).day())
    }
}

private struct Switch: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(detail)
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct Caption: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary) }
}

private extension View {
    /// Liquid Glass's prominent button on macOS 26, the bordered prominent one before it.
    @ViewBuilder func prominent() -> some View {
        if #available(macOS 26.0, *) { self.buttonStyle(.glassProminent) } else { self.buttonStyle(.borderedProminent) }
    }
}
