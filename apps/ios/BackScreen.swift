import SwiftUI
import UIKit
import AVFoundation
import StreamProtocol

// The iPhone Duo's back screen during a session: off, a copy of the Mac's picture, or a trackpad for
// the fingers behind the device.
//
// iOS 27.1 shows an app's scene accessory on the back screen while the app runs a camera capture
// session (CameraCaptureAccessory), so the camera runs only while a mode is on, the app is open on the
// inner screen and a Mac is connected. Nothing is recorded: no output is attached to the session.
//
// The trackpad goes the way the holder feels it. A finger moving to the holder's right behind the
// device moves left in the back screen's own coordinates, so the pad mirrors left and right; when the
// back screen keeps its upright shape while the front is held sideways, the pad also turns its motion
// a quarter turn to follow the front (`BackPadGeometry`). Swipes follow the same mapping.

/// What the back screen does during a session.
enum BackScreenMode: String, CaseIterable, Identifiable {
    case off, mirror, trackpad

    static let key = "DuoDeck.backScreen"
    static let naturalKey = "DuoDeck.backPadNatural"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .mirror: return "Mirror Mac"
        case .trackpad: return "Trackpad"
        }
    }

    var symbol: String {
        switch self {
        case .off: return "rectangle.slash"
        case .mirror: return "rectangle.on.rectangle"
        case .trackpad: return "rectangle.and.hand.point.up.left"
        }
    }

    static var current: BackScreenMode {
        BackScreenMode(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .off
    }
}

/// How a back-screen stroke becomes the holder's motion. Pure, so it can be reasoned about alone.
enum BackPadGeometry {
    /// `inner`: the front's interface orientation. `backBounds`: the back pad's size.
    /// `natural`: off keeps the back screen's own directions.
    static func axis(inner: UIInterfaceOrientation, backBounds: CGSize, natural: Bool) -> (CGAffineTransform, CGSize) {
        let mirror = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
        guard natural, backBounds.width > 0, backBounds.height > 0 else {
            return (.identity, CGSize(width: backBounds.width, height: backBounds.width / 1.6))
        }
        let backUpright = backBounds.height >= backBounds.width
        if inner.isLandscape, backUpright {
            // The back screen stays upright while the front is sideways: its height runs across the
            // front picture. Back (bx, by) is the device's (−bx, by); the front reads that sideways.
            let along = backBounds.height
            let span = CGSize(width: along, height: along / 1.6)
            if inner == .landscapeLeft {
                return (CGAffineTransform(a: 0, b: -1, c: -1, d: 0, tx: 0, ty: 0), span)
            }
            return (CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0), span)
        }
        // Both upright or both sideways, each the right way up for whoever looks at it: left and
        // right swap, up and down stay.
        return (mirror, CGSize(width: backBounds.width, height: backBounds.width / 1.6))
    }
}

// MARK: - Camera

/// Keeps a capture session running while the back screen is in use. No output, nothing recorded.
final class BackScreenCamera: @unchecked Sendable {
    static let shared = BackScreenCamera()

    private let session = AVCaptureSession()
    /// A preview layer on the session, never shown: as in DuoMagic, it gives the session a video
    /// connection, which is what makes iOS count the app as capturing and present the accessory.
    private lazy var preview: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
    private let queue = DispatchQueue(label: "DuoDeck.backScreen.camera")
    private var configured = false
    private var wanted = false
    private var observers: [NSObjectProtocol] = []

    func set(running on: Bool) {
        queue.async { self.wanted = on }
        guard on else {
            queue.async { if self.session.isRunning { self.session.stopRunning() } }
            return
        }
        Task {
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                print("backscreen: camera access denied")
                return
            }
            await MainActor.run {
                self.preview.session = self.session
                self.preview.videoGravity = .resizeAspectFill
            }
            queue.async { self.start() }
        }
    }

    private func start() {
        guard wanted else { return }
        if !configured {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }
            session.beginConfiguration()
            if session.canSetSessionPreset(.low) { session.sessionPreset = .low }
            if session.canAddInput(input) { session.addInput(input) }
            if session.isMultitaskingCameraAccessSupported { session.isMultitaskingCameraAccessEnabled = true }
            session.commitConfiguration()
            configured = true
            // An interruption or an error would otherwise leave the back screen dark.
            for name in [AVCaptureSession.runtimeErrorNotification, AVCaptureSession.interruptionEndedNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: session, queue: nil) { [weak self] _ in
                    guard let self else { return }
                    self.queue.async { self.start() }
                })
            }
        }
        if !session.isRunning { session.startRunning() }
        print("backscreen: camera \(session.isRunning ? "running" : "not running") · multitasking \(session.isMultitaskingCameraAccessEnabled) · inputs \(session.inputs.count)")
    }
}

// MARK: - The scene accessory

/// Presents the back screen's surface and runs the camera exactly while it is wanted.
struct BackScreenHost: ViewModifier {
    @ObservedObject var client: StreamClient
    @Environment(\.duoEnvironment) private var duo
    @Environment(\.scenePhase) private var phase
    @AppStorage(BackScreenMode.key) private var raw = BackScreenMode.off.rawValue

    private var mode: BackScreenMode { BackScreenMode(rawValue: raw) ?? .off }
    /// Open on the inner screen with a Mac connected and a mode chosen. Folded shut, DuoDeck itself is
    /// on the outer screen, so nothing is presented there.
    private var wanted: Bool {
        mode != .off && phase != .background
            && (duo.hinge == .partiallyOpen || duo.hinge == .fullyOpen)
    }

    func body(content: Content) -> some View {
        presented(content)
            .onChange(of: wanted, initial: true) { _, on in
                print("backscreen: wanted \(on) (mode \(mode.rawValue), hinge \(duo.hinge.rawValue), connected \(client.connected))")
                BackScreenCamera.shared.set(running: on)
                if !on { client.setBackPad(false) }
            }
    }

    @ViewBuilder private func presented(_ content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.sceneAccessory {
                CameraCaptureAccessory {
                    BackScreenSurface(client: client)
                }
                .onAvailabilityChange { available in print("backscreen: accessory available \(available)") }
            }
        } else {
            content
        }
    }
}

// MARK: - The surface

struct BackScreenSurface: View {
    @ObservedObject var client: StreamClient
    @AppStorage(BackScreenMode.key) private var raw = BackScreenMode.off.rawValue
    @AppStorage(BackScreenMode.naturalKey) private var natural = true
    @AppStorage("DuoDeck.pointerSensitivity") private var speed = 1.25
    @AppStorage("DuoDeck.haptics") private var haptics = true

    private var mode: BackScreenMode { BackScreenMode(rawValue: raw) ?? .off }

    var body: some View {
        ZStack {
            Color.black
            switch client.connected ? mode : .off {
            case .off:
                if mode != .off { idle }
            case .mirror:
                BackMirror(client: client)
            case .trackpad:
                padBackdrop
                BackPad(client: client, natural: natural, speed: CGFloat(speed))
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onChange(of: mode == .trackpad && client.connected, initial: true) { _, on in client.setBackPad(on) }
        .onDisappear { client.setBackPad(false) }
    }

    /// Before a Mac is connected: the mark, so the screen is plainly DuoDeck's.
    private var idle: some View {
        VStack(spacing: 14) {
            DuoDeckMark(size: 72)
            Text("DuoDeck").font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(.white)
            Text("Connect to your Mac to use this screen").font(.footnote).foregroundStyle(.white.opacity(0.6))
        }
        .padding(24)
    }

    /// Faint, so the pad reads as a surface without lighting the room behind the holder.
    private var padBackdrop: some View {
        ZStack {
            LinearGradient(colors: [Palette.accent.opacity(0.22), .black], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 14) {
                DuoDeckMark(size: 64).opacity(0.55)
                Text("Trackpad")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Text("One finger moves · Two fingers scroll · Tap to click")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .allowsHitTesting(false)
    }
}

// MARK: Mirror

private struct BackMirror: UIViewRepresentable {
    let client: StreamClient

    func makeUIView(context: Context) -> BackMirrorView {
        let view = BackMirrorView()
        view.source = client.displayView
        return view
    }

    func updateUIView(_ view: BackMirrorView, context: Context) { view.source = client.displayView }

    static func dismantleUIView(_ view: BackMirrorView, coordinator: ()) { view.source?.attachMirror(nil) }
}

final class BackMirrorView: UIView {
    override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }
    var displayLayer: AVSampleBufferDisplayLayer { layer as! AVSampleBufferDisplayLayer }
    weak var source: HEVCDisplayView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        displayLayer.videoGravity = .resizeAspect
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        source?.attachMirror(window == nil ? nil : displayLayer)
    }
}

// MARK: Trackpad

private struct BackPad: UIViewRepresentable {
    let client: StreamClient
    let natural: Bool
    let speed: CGFloat

    func makeUIView(context: Context) -> BackPadView {
        let view = BackPadView()
        configure(view)
        return view
    }

    func updateUIView(_ view: BackPadView, context: Context) { configure(view) }

    private func configure(_ view: BackPadView) {
        let client = self.client
        view.natural = natural
        view.inner = { client.displayView.window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .portrait }
        let pad = view.pad
        pad.send = { client.sendInput($0) }
        pad.setPointer = { client.setOwnPointer($0, from: .trackpad) }
        pad.feed = { let f = client.pointerFeedState; return (f.anchor, f.reseeds) }
        pad.onFingers = { client.trackpadFingers($0) }
        pad.latchedModifiers = []
        pad.travel = min(2.3, max(0.65, speed))
        pad.sendGesture = { client.sendGesture($0, fingers: $1) }
        view.setNeedsLayout()
    }
}

/// Holds the pad and keeps its mapping current as either screen turns.
final class BackPadView: UIView {
    let pad = TrackpadSurface(frame: .zero)
    var natural = true
    var inner: () -> UIInterfaceOrientation = { .portrait }
    private var lastKey = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        pad.backgroundColor = .clear
        addSubview(pad)
        NotificationCenter.default.addObserver(self, selector: #selector(turned),
                                               name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func turned() { setNeedsLayout() }

    override func layoutSubviews() {
        super.layoutSubviews()
        pad.frame = bounds
        let orientation = inner()
        let key = "\(orientation.rawValue) \(bounds.size) \(natural)"
        guard key != lastKey else { return }
        lastKey = key
        let (axis, span) = BackPadGeometry.axis(inner: orientation, backBounds: bounds.size, natural: natural)
        pad.axis = axis
        pad.axisSpan = span
    }
}
