import AppKit
import SwiftUI
import SillHostCore

/// DuoDeck Host's home: the window the app opens with and that the Dock, the menu bar item and
/// ⌘0 bring back. It says one thing at a time — whether this Mac is ready, who is connected and
/// what the next step is — and leaves every control to Settings (⌘,).
@MainActor
final class HomeWindowController: NSWindowController, NSWindowDelegate {
    private static let frameName = "DuoDeckHomeWindow"

    init(model: AppModel) {
        let host = NSHostingController(rootView: HomeView(model: model))
        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.title = "DuoDeck"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.collectionBehavior.formUnion([.moveToActiveSpace])
        window.contentMinSize = NSSize(width: 440, height: 560)
        window.setContentSize(NSSize(width: 480, height: 640))
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

    private var presentation: StatusPresentation { previewPresentation ?? model.presentation }
    private var allGranted: Bool { previewAllGranted ?? model.permissions.allGranted }

    private static let iosAppURL = "https://apps.apple.com/app/id6832548998"

    var body: some View {
        ZStack {
            HomeBackground()
            VStack(spacing: 0) {
                header
                    .padding(.top, 44)
                Spacer(minLength: 24)
                content
                    .frame(maxWidth: 380)
                Spacer(minLength: 24)
                footer
                    .padding(.bottom, 18)
            }
            .padding(.horizontal, 32)
        }
        .frame(minWidth: 440, minHeight: 560)
        .onAppear { model.permissions.refresh() }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 14) {
            DuoDeckMark()
                .frame(width: 84, height: 84)
                .shadow(color: Color(red: 0.43, green: 0.16, blue: 0.85).opacity(0.25), radius: 18, y: 8)
                .accessibilityHidden(true)
            Text("DuoDeck")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
            StatusPill(state: presentation.glyph, text: statusLine)
        }
    }

    private var statusLine: String {
        if !allGranted { return "Almost ready" }
        switch presentation.glyph {
        case .streaming: return presentation.header
        case .connected: return presentation.header
        case .attention: return presentation.header
        case .idle: return "Ready on \(presentation.advertisedName ?? "this Mac")"
        }
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        if !allGranted {
            SetupCard(permissions: model.permissions)
        } else if !presentation.devices.isEmpty {
            ConnectedCard(source: presentation.source, devices: presentation.devices)
        } else {
            WaitingCard(appURL: Self.iosAppURL, canPair: presentation.canPair) { model.pairDevice() }
        }
        ForEach(presentation.attention.filter { allGranted || !Self.isPermission($0.action) }) { item in
            AttentionRow(item: item) { review(item.action) }
                .padding(.top, 10)
        }
    }

    private static func isPermission(_ action: StatusPresentation.Attention.Action) -> Bool {
        action == .allowScreenRecording || action == .allowAccessibility
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

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 16) {
            Button { model.showSettings?(nil) } label: { Label("Settings", systemImage: "gearshape") }
            Button { model.showSettings?(.devices) } label: { Label("Devices", systemImage: "ipad.and.iphone") }
            Spacer()
            Toggle("Open at login", isOn: Binding(get: { model.loginItem.isOn }, set: { model.loginItem.set($0) }))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .disabled(!model.loginItem.available)
        }
        .buttonStyle(.borderless)
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Pieces

/// The seated-Duo mark, drawn from design/DuoDeckMark.svg's geometry (viewBox 20 16 200 200).
struct DuoDeckMark: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 200
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: (x - 20) * s, y: (y - 16) * s) }
            let upperRect = CGRect(origin: p(52, 28), size: CGSize(width: 136 * s, height: 112 * s))
            let upper = Path(roundedRect: upperRect, cornerRadius: 32 * s, style: .continuous)
            var deck = Path()
            deck.move(to: p(68, 142)); deck.addLine(to: p(172, 142)); deck.addLine(to: p(194, 184))
            deck.addLine(to: p(46, 184)); deck.closeSubpath()
            let stroke = StrokeStyle(lineWidth: 36 * s, lineJoin: .round)
            let deckShading = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Color(hex: 0xFF5A3C), Color(hex: 0xFFB020)]), startPoint: p(40, 120), endPoint: p(210, 210))
            ctx.fill(deck, with: deckShading)
            ctx.stroke(deck, with: deckShading, style: stroke)
            ctx.fill(upper, with: .linearGradient(Gradient(colors: [Color(hex: 0x6D28D9), Color(hex: 0xEC4899)]),
                                                  startPoint: p(60, 20), endPoint: p(190, 150)))
            ctx.drawLayer { layer in
                layer.clip(to: upper)
                layer.opacity = 0.55
                layer.fill(deck, with: .color(Color(hex: 0x4C1D95)))
                layer.stroke(deck, with: .color(Color(hex: 0x4C1D95)), style: stroke)
            }
            let key = Path(roundedRect: CGRect(origin: p(92, 168), size: CGSize(width: 56 * s, height: 12 * s)), cornerRadius: 6 * s)
            ctx.fill(key, with: .color(.white.opacity(0.88)))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct HomeBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(colors: [Color(hex: 0x6D28D9).opacity(scheme == .dark ? 0.28 : 0.12), .clear],
                           center: UnitPoint(x: 0.3, y: 0.0), startRadius: 0, endRadius: 360)
            RadialGradient(colors: [Color(hex: 0xEC4899).opacity(scheme == .dark ? 0.18 : 0.08), .clear],
                           center: UnitPoint(x: 0.85, y: 0.08), startRadius: 0, endRadius: 300)
        }
        .ignoresSafeArea()
    }
}

private struct StatusPill: View {
    let state: StatusGlyph.State
    let text: String
    @State private var pulse = false

    private var color: Color {
        switch state {
        case .streaming, .connected: .green
        case .attention: .orange
        case .idle: Color(hex: 0x8B5CF6)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
                .overlay(Circle().stroke(color.opacity(0.5), lineWidth: 6).scaleEffect(pulse ? 1.8 : 1).opacity(pulse ? 0 : 0.6))
            Text(text).font(.callout.weight(.medium)).lineLimit(1)
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(.thinMaterial, in: Capsule())
        .onAppear {
            guard state != .attention else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.quaternary))
    }
}

/// Nobody connected yet: the two steps, the App Store code for the device, and Pair.
private struct WaitingCard: View {
    let appURL: String
    let canPair: Bool
    let pair: () -> Void

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Connect your iPhone or iPad").font(.headline)
                    Step(number: 1, text: "Get DuoDeck on your iPhone or iPad.")
                    Step(number: 2, text: "Open it and tap this Mac.")
                    Step(number: 3, text: "Pick a window — it's yours on the go.")
                }
                Spacer(minLength: 0)
                if let image = QRCode.image(for: appURL) {
                    VStack(spacing: 6) {
                        Image(decorative: image, scale: 1)
                            .interpolation(.none).resizable()
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text("Scan for the app").font(.caption2).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("App Store code for DuoDeck on iPhone and iPad")
                }
            }
            Button(action: pair) {
                Label("Pair iPhone or iPad…", systemImage: "qrcode.viewfinder").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: 0x6D28D9))
            .controlSize(.large)
            .disabled(!canPair)
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }
    }
}

private struct Step: View {
    let number: Int
    let text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold)).foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(LinearGradient(colors: [Color(hex: 0x6D28D9), Color(hex: 0xEC4899)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Devices on this Mac now: what is showing, and each device with its link.
private struct ConnectedCard: View {
    let source: StatusPresentation.Row?
    let devices: [StatusPresentation.Row]

    var body: some View {
        Card {
            if let source {
                HStack(spacing: 12) {
                    Image(systemName: source.symbol).font(.title2).foregroundStyle(Color(hex: 0x8B5CF6)).frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Showing").font(.caption).foregroundStyle(.secondary)
                        Text(source.title).font(.headline).lineLimit(1).truncationMode(.middle)
                    }
                }
                Divider()
            }
            ForEach(devices) { device in
                HStack(spacing: 12) {
                    Image(systemName: device.symbol).font(.title2).foregroundStyle(.secondary).frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(DuoDeckHostStyle.deviceName(device.title)).font(.body.weight(.medium)).lineLimit(1)
                        if let line = device.issue ?? device.detail {
                            Text(line).font(.caption).monospacedDigit()
                                .foregroundStyle(device.issue != nil ? Color.orange : Color.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                    Circle().fill(device.issue == nil ? Color.green : Color.orange).frame(width: 8, height: 8)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// The two macOS permissions, each with its own button, until both are on.
private struct SetupCard: View {
    let permissions: PermissionsModel

    var body: some View {
        Card {
            Text("Finish setting up this Mac").font(.headline)
            Text("DuoDeck needs two macOS permissions to show your windows and take your taps.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            PermissionLine(title: "Screen Recording", detail: "To show your windows", granted: permissions.screenRecording) {
                permissions.requestScreenRecording()
            }
            PermissionLine(title: "Accessibility", detail: "To click and type for you", granted: permissions.accessibility) {
                permissions.requestAccessibility()
            }
        }
    }
}

private struct PermissionLine: View {
    let title: String
    let detail: String
    let granted: Bool
    let allow: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .font(.title3).foregroundStyle(granted ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                Button("Allow…", action: allow).tint(Color(hex: 0x6D28D9)).buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct AttentionRow: View {
    let item: StatusPresentation.Attention
    let review: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.callout.weight(.medium))
                Text(item.subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if item.action != .none { Button("Review…", action: review).controlSize(.small) }
        }
        .padding(12)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}
