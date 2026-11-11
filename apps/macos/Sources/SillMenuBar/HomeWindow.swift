import AppKit
import SwiftUI
import SillHostCore

/// DuoDeck Host's home: the window the app opens with and that the Dock, the menu bar item and
/// ⌘0 bring back. A plain macOS grouped form, like a System Settings pane: what is happening now,
/// the switches people change between sessions, and the paired devices. Everything else stays in
/// Settings (⌘,).
@MainActor
final class HomeWindowController: NSWindowController, NSWindowDelegate {
    private static let frameName = "DuoDeckHomeWindow4"   // 4: soft gradient, frosted cards

    init(model: AppModel) {
        let host = NSHostingController(rootView: HomeView(model: model))
        host.sizingOptions = []
        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.title = "DuoDeck"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.collectionBehavior.formUnion([.moveToActiveSpace])
        window.contentMinSize = NSSize(width: 420, height: 420)
        window.setContentSize(NSSize(width: 480, height: 700))
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
        ZStack {
            SoftBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    if !allGranted {
                        PermissionsSection(permissions: model.permissions)
                    } else {
                        nowSection
                        if !presentation.attention.isEmpty { attentionSection }
                        StreamingSection(model: model, settings: model.settings)
                        devicesSection
                    }
                }
                .frame(maxWidth: 520, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 56)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.never)
        }
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

    // MARK: Hero: the state in large type, this Mac under it

    private var hero: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(heroTitle)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .contentTransition(.opacity)
                HStack(spacing: 6) {
                    Circle().fill(stateColor).frame(width: 7, height: 7)
                    Text(stateLine).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var heroTitle: String {
        if !allGranted { return "Almost ready" }
        switch presentation.glyph {
        case .streaming: return "Streaming"
        case .connected: return "Connected"
        case .attention: return "Needs a look"
        case .idle: return "Ready"
        }
    }

    private var stateLine: String {
        if !allGranted { return "Two permissions to go" }
        switch presentation.glyph {
        case .idle: return (presentation.advertisedName ?? "This Mac") + (paired.isEmpty ? " · ready to pair" : " · waiting for a device")
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
            Panel("Now") {
                if let source = presentation.source {
                    Row(symbol: source.symbol, title: source.title, detail: source.detail, tint: DuoDeckHostStyle.accent) { EmptyView() }
                }
                ForEach(presentation.devices) { device in
                    Row(symbol: device.symbol, title: DuoDeckHostStyle.deviceName(device.title),
                        detail: device.issue ?? device.detail, detailIsWarning: device.issue != nil) {
                        LiveDot(color: device.issue == nil ? .green : .orange)
                    }
                }
            }
        } else if paired.isEmpty {
            Panel("Get started") {
                Row(symbol: "qrcode.viewfinder", title: "Connect your iPhone or iPad",
                    detail: "Open DuoDeck on the device, then pair it with this Mac's code.", tint: DuoDeckHostStyle.accent) {
                    Button("Pair…") { model.pairDevice() }.prominent().disabled(!presentation.canPair)
                }
                Row(symbol: "arrow.down.app", title: "Get DuoDeck for iPhone and iPad", detail: "Free on the App Store.") {
                    Button("App Store") { NSWorkspace.shared.open(Self.iosApp) }
                }
            }
        } else {
            Panel("Now") {
                Row(symbol: "dot.radiowaves.left.and.right", title: "No device connected",
                    detail: "Open DuoDeck on your iPhone or iPad and tap this Mac.") { EmptyView() }
            }
        }
    }

    private var attentionSection: some View {
        Panel(nil) {
            ForEach(presentation.attention) { item in
                Row(symbol: "exclamationmark.triangle.fill", title: item.title, detail: item.subtitle, tint: .orange) {
                    if item.action != .none { Button("Review…") { review(item.action) } }
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
        Panel("Paired devices", trailing: {
            if !paired.isEmpty { Button("Manage…") { model.showSettings?(.devices) }.buttonStyle(.plain).foregroundStyle(DuoDeckHostStyle.accent) }
        }) {
            ForEach(paired.sorted { ($0.lastSeen ?? $0.pairedAt) > ($1.lastSeen ?? $1.pairedAt) }.prefix(6), id: \.id) { device in
                let connected = presentation.devices.contains { DuoDeckHostStyle.deviceName($0.title) == DuoDeckHostStyle.deviceName(device.name) }
                Row(symbol: (device.model ?? device.name).lowercased().contains("iphone") ? "iphone" : "ipad",
                    title: DuoDeckHostStyle.deviceName(device.name),
                    detail: connected ? "Connected now" : Self.lastConnected(device),
                    tint: connected ? DuoDeckHostStyle.accent : .secondary) {
                    if connected { LiveDot(color: .green) }
                }
            }
            Row(symbol: "plus", title: "Pair iPhone or iPad…", detail: nil, tint: DuoDeckHostStyle.accent) { EmptyView() }
                .contentShape(Rectangle())
                .onTapGesture { if presentation.canPair { model.pairDevice() } }
                .accessibilityAddTraits(.isButton)
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
        Panel("Streaming") {
            Row(symbol: "sparkles.tv", title: "Picture",
                detail: DuoDeckStreamingPreset.current(in: settings.config)?.detail ?? "Set in Settings › Streaming") {
                Picker("Picture", selection: preset) {
                    ForEach(DuoDeckStreamingPreset.allCases) { Text($0.title).tag($0.rawValue) }
                    if DuoDeckStreamingPreset.current(in: settings.config) == nil { Text("Custom").tag("custom") }
                }
                .labelsHidden().fixedSize()
            }
            if snapshot?.virtualDisplayAPIMissing != true {
                SwitchRow(symbol: "rectangle.on.rectangle", title: "Fit windows to the device",
                          detail: "Each window gets its own display at your device's size.", isOn: $settings.config.virtualDisplay)
            }
            SwitchRow(symbol: "speaker.wave.2", title: "Sound",
                      detail: settings.config.sendAudio && snapshot?.audio?.problem != nil
                        ? "Not available right now." : "Play your Mac's sound on the device.",
                      isOn: $settings.config.sendAudio)
            SwitchRow(symbol: "doc.on.clipboard", title: "Clipboard", detail: "Copy on one, paste on the other.",
                      isOn: $settings.config.shareClipboard)
            SwitchRow(symbol: "globe", title: "Away from home", detail: remoteNote, isOn: $settings.config.remoteAccess)
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
        Panel("Finish setup") {
            row("rectangle.dashed.badge.record", "Screen Recording", "Shows your windows on the device.", granted: permissions.screenRecording) {
                permissions.requestScreenRecording()
            }
            row("hand.tap", "Accessibility", "Lets your taps and typing reach the Mac.", granted: permissions.accessibility) {
                permissions.requestAccessibility()
            }
        }
    }

    private func row(_ symbol: String, _ title: String, _ detail: String, granted: Bool, allow: @escaping () -> Void) -> some View {
        Row(symbol: symbol, title: title, detail: detail, tint: granted ? .green : DuoDeckHostStyle.accent) {
            if granted {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3).accessibilityLabel("Allowed")
            } else {
                Button("Allow…", action: allow).prominent()
            }
        }
    }
}

// MARK: - Building blocks

/// A titled group: a small caption above one frosted card whose rows are divided by hairlines.
private struct Panel<Content: View, Trailing: View>: View {
    let title: String?
    let trailing: Trailing
    let content: Content

    init(_ title: String?, @ViewBuilder trailing: () -> Trailing = { EmptyView() }, @ViewBuilder content: () -> Content) {
        self.title = title; self.trailing = trailing(); self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                HStack {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    trailing.font(.subheadline)
                }
                .padding(.horizontal, 6)
            }
            Group {
                if #available(macOS 15.0, *) {
                    VStack(spacing: 0) {
                        Group(subviews: content) { rows in
                            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                                if index > 0 { Divider().padding(.leading, 54) }
                                row
                            }
                        }
                    }
                } else {
                    VStack(spacing: 0) { content }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        }
    }
}

/// One line in a panel: a tinted symbol tile, a title with an optional second line, a trailing control.
private struct Row<Accessory: View>: View {
    let symbol: String
    let title: String
    let detail: String?
    var detailIsWarning = false
    var tint: Color = .secondary
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body).lineLimit(1).truncationMode(.middle)
                if let detail {
                    Text(detail).font(.caption).monospacedDigit()
                        .foregroundStyle(detailIsWarning ? Color.orange : Color.secondary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            accessory
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

private struct SwitchRow: View {
    let symbol: String
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Row(symbol: symbol, title: title, detail: detail, tint: isOn ? DuoDeckHostStyle.accent : .secondary) {
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
    }
}

private struct LiveDot: View {
    let color: Color
    @State private var on = false
    var body: some View {
        Circle().fill(color).frame(width: 8, height: 8)
            .overlay(Circle().stroke(color.opacity(0.5), lineWidth: 5).scaleEffect(on ? 2 : 1).opacity(on ? 0 : 0.7))
            .onAppear { withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { on = true } }
            .accessibilityHidden(true)
    }
}

/// A very soft, slow-moving wash of the mark's colours behind everything (light: pale lilac, blush,
/// peach; dark: deep plum). Stays still with Reduce Motion.
private struct SoftBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var palette: [Color] {
        scheme == .dark
            ? [c(0x17121F), c(0x1E1530), c(0x1A1424), c(0x241634), c(0x1B1426), c(0x2A1626), c(0x161219), c(0x1D1522), c(0x22161C)]
            : [c(0xF6F2FF), c(0xF1EBFF), c(0xFBF1F8), c(0xEFE8FF), c(0xFAF6FF), c(0xFDEFF4), c(0xF8F5FB), c(0xFCF3EE), c(0xFFF4EA)]
    }

    var body: some View {
        Group {
            if #available(macOS 15.0, *) {
                TimelineView(.animation(minimumInterval: 1 / 15, paused: reduceMotion)) { timeline in
                    let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    let wobble = Float(sin(t / 9) * 0.08), wobble2 = Float(cos(t / 11) * 0.08)
                    MeshGradient(width: 3, height: 3, points: [
                        [0, 0], [0.5, 0], [1, 0],
                        [0, 0.5], [0.5 + wobble, 0.45 + wobble2], [1, 0.5],
                        [0, 1], [0.5, 1], [1, 1],
                    ], colors: palette)
                }
            } else {
                LinearGradient(colors: [palette[0], palette[4], palette[8]], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .ignoresSafeArea()
    }

    private func c(_ hex: UInt32) -> Color {
        Color(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

private extension Button {
    /// Liquid Glass's prominent button on macOS 26, the bordered prominent one before it.
    @ViewBuilder func prominent() -> some View {
        if #available(macOS 26.0, *) { self.buttonStyle(.glassProminent) } else { self.buttonStyle(.borderedProminent) }
    }
}
