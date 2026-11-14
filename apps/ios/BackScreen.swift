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
                #if DEBUG
                print("backscreen: camera access denied")
                #endif
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
        #if DEBUG
        print("backscreen: camera \(session.isRunning ? "running" : "not running") · multitasking \(session.isMultitaskingCameraAccessEnabled) · inputs \(session.inputs.count)")
        #endif
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
        client.connected && mode != .off && phase != .background
            && (duo.hinge == .partiallyOpen || duo.hinge == .fullyOpen)
    }

    func body(content: Content) -> some View {
        presented(content)
            .onChange(of: wanted, initial: true) { _, on in
                #if DEBUG
                print("backscreen: wanted \(on) (mode \(mode.rawValue), hinge \(duo.hinge.rawValue), connected \(client.connected))")
                #endif
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
                .onAvailabilityChange { available in
                    #if DEBUG
                    print("backscreen: accessory available \(available)")
                    #endif
                }
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
                VStack(spacing: 8) {
                    Spacer()
                    HStack(spacing: 8) {
                        DuoDeckMark(size: 22)
                        Text(client.macName.isEmpty ? "Your Mac" : client.macName)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.bottom, 28)
                }
                BackMirror(client: client)
            case .trackpad:
                padBackdrop
                BackPad(client: client, natural: natural, speed: CGFloat(speed))
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onChange(of: mode == .trackpad && client.connected, initial: true) { _, on in
            client.setBackPad(on)
            // The first time, learn how this back screen sits (two strokes); later on request.
            if on, !BackCalibration.calibrated, !BackCalibration.shared.active { BackCalibration.shared.start() }
        }
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
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                RadialGradient(colors: [Palette.accent.opacity(0.28 + 0.12 * sin(t * 1.1)), .clear],
                               center: UnitPoint(x: 0.5 + 0.25 * cos(t * 0.35), y: 0.45 + 0.2 * sin(t * 0.27)),
                               startRadius: 0, endRadius: 360)
                    .blendMode(.plusLighter)
            }
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
        backgroundColor = .clear
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
        view.innerWindow = { client.displayView.window }
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

/// How the back screen's and the front's coordinates relate, from what UIKit says of each screen.
///
/// Each view converts its own directions into its screen's fixed coordinate space (the panel's own,
/// upright-native axes, which never turn), so every one of the four ways the phone is held is
/// accounted for by UIKit itself. The one hardware constant left is how the back panel's native axes
/// sit against the front's when you look at the front: the back's native x runs the other way (it is
/// seen from behind), its y the same way (`panelToFront`).
enum BackPadMapping {
    @MainActor static var panelToFront: CGAffineTransform { BackCalibration.matrix }

    /// The linear map from a delta in `back` to a delta in `front`, or nil when UIKit cannot tell the
    /// two screens apart.
    @MainActor static func axis(back: UIView, front: UIWindow?) -> CGAffineTransform? {
        guard let backWindow = back.window, let front else { return nil }
        let backScreen = backWindow.windowScene?.screen ?? backWindow.screen
        let frontScreen = front.windowScene?.screen ?? front.screen
        guard backScreen !== frontScreen else { return nil }
        let backFixed = backScreen.fixedCoordinateSpace
        let frontFixed = frontScreen.fixedCoordinateSpace
        func map(_ v: CGPoint) -> CGPoint {
            let panel = vector(v, from: back, to: backFixed)
            let device = panel.applying(panelToFront)
            return vector(device, from: frontFixed, to: front)
        }
        let ex = map(CGPoint(x: 1, y: 0)), ey = map(CGPoint(x: 0, y: 1))
        func unit(_ v: CGFloat) -> CGFloat { abs(v) < 0.5 ? 0 : (v > 0 ? 1 : -1) }
        return CGAffineTransform(a: unit(ex.x), b: unit(ex.y), c: unit(ey.x), d: unit(ey.y), tx: 0, ty: 0)
    }
}

extension BackPadMapping {
    static func vector(_ v: CGPoint, from a: UICoordinateSpace, to b: UICoordinateSpace) -> CGPoint {
        let o = a.convert(CGPoint.zero, to: b)
        let p = a.convert(v, to: b)
        return CGPoint(x: p.x - o.x, y: p.y - o.y)
    }

    /// `v` in `view`'s screen's fixed axes.
    static func fixed(_ v: CGPoint, in view: UIView) -> CGPoint? {
        guard let window = view.window else { return nil }
        let screen = window.windowScene?.screen ?? window.screen
        return vector(v, from: view, to: screen.fixedCoordinateSpace)
    }
}

/// Holds the pad, keeps its mapping current as either screen turns, and draws the glow under fingers.
final class BackPadView: UIView, UIGestureRecognizerDelegate {
    let pad = TrackpadSurface(frame: .zero)
    var natural = true
    var innerWindow: () -> UIWindow? = { nil }
    private var lastKey = ""
    private let glow = CALayer()
    private let watcher = BackTouchWatcher()
    private var lastSpark: [ObjectIdentifier: CGPoint] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        pad.backgroundColor = .clear
        isMultipleTouchEnabled = true
        layer.addSublayer(glow)
        addSubview(pad)
        watcher.cancelsTouchesInView = false
        watcher.delaysTouchesBegan = false
        watcher.delaysTouchesEnded = false
        watcher.delegate = self
        watcher.onTouch = { [weak self] touch, phase in self?.spark(touch, phase) }
        pad.addGestureRecognizer(watcher)
        NotificationCenter.default.addObserver(self, selector: #selector(turned),
                                               name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(turned),
                                               name: BackCalibration.changed, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    @objc private func turned() { lastKey = ""; setNeedsLayout() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        lastKey = ""
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        pad.frame = bounds
        glow.frame = bounds
        refreshAxis()
    }

    private func refreshAxis() {
        let front = innerWindow()
        let orientation = front?.windowScene?.effectiveGeometry.interfaceOrientation ?? .portrait
        let backOrientation = window?.windowScene?.effectiveGeometry.interfaceOrientation
        let key = "\(orientation.rawValue) \(backOrientation?.rawValue ?? -1) \(bounds.size) \(natural)"
        guard key != lastKey, bounds.width > 0 else { return }
        lastKey = key
        var axis: CGAffineTransform
        var source = "screens"
        if !natural {
            axis = .identity
            source = "raw"
        } else if let measured = BackPadMapping.axis(back: self, front: front) {
            axis = measured
        } else {
            axis = BackPadGeometry.axis(inner: orientation, backBounds: bounds.size, natural: true).0
            source = "shape"
        }
        // One measure for both axes and every orientation: the back panel's short side. A centimetre
        // of finger travel then moves the pointer the same distance however the phone is held.
        let along = min(bounds.width, bounds.height)
        pad.axis = axis
        pad.axisSpan = CGSize(width: along, height: along / 1.6)
        #if DEBUG
        print("backscreen: pad \(Int(bounds.width))×\(Int(bounds.height)) front \(orientation.rawValue) back \(backOrientation?.rawValue ?? -1) device \(UIDevice.current.orientation.rawValue) axis [\(axis.a) \(axis.b) \(axis.c) \(axis.d)] from \(source)")
        #endif
    }

    // MARK: Glow

    private func spark(_ touch: UITouch, _ phase: UITouch.Phase) {
        if phase == .began { refreshAxis() }
        let id = ObjectIdentifier(touch)
        let p = touch.location(in: self)
        switch phase {
        case .began:
            lastSpark[id] = p
            ring(at: p)
            dot(at: p, size: 46, life: 0.7)
        case .moved:
            let previous = touch.previousLocation(in: self)
            feedCalibration(CGPoint(x: p.x - previous.x, y: p.y - previous.y))
            let last = lastSpark[id] ?? p
            let distance = hypot(p.x - last.x, p.y - last.y)
            guard distance > 5 else { return }
            let steps = min(6, Int(distance / 8) + 1)
            for i in 1...steps {
                let t = CGFloat(i) / CGFloat(steps)
                dot(at: CGPoint(x: last.x + (p.x - last.x) * t, y: last.y + (p.y - last.y) * t), size: 30, life: 0.55)
            }
            lastSpark[id] = p
        default:
            lastSpark[id] = nil
            dot(at: p, size: 60, life: 0.5)
        }
    }

    /// A stroke behind the phone while calibration asks for one, in both panels' fixed axes.
    private func feedCalibration(_ delta: CGPoint) {
        let calibration = BackCalibration.shared
        guard calibration.active, let front = innerWindow(),
              let panel = BackPadMapping.fixed(delta, in: self) else { return }
        let asked = calibration.step == .right ? CGPoint(x: 1, y: 0) : CGPoint(x: 0, y: -1)
        let frontScreen = front.windowScene?.screen ?? front.screen
        let expected = BackPadMapping.vector(asked, from: front, to: frontScreen.fixedCoordinateSpace)
        calibration.feed(panel: panel, front: expected)
    }

    private static let tint = UIColor(red: 196 / 255, green: 181 / 255, blue: 253 / 255, alpha: 1)

    private func dot(at p: CGPoint, size: CGFloat, life: CFTimeInterval) {
        let d = CALayer()
        d.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        d.position = p
        d.cornerRadius = size / 2
        d.backgroundColor = Self.tint.withAlphaComponent(0.85).cgColor
        d.shadowColor = Self.tint.cgColor
        d.shadowRadius = size * 0.6
        d.shadowOpacity = 1
        d.shadowOffset = .zero
        glow.addSublayer(d)
        animateOut(d, life: life, to: 0.15)
    }

    private func ring(at p: CGPoint) {
        let r = CAShapeLayer()
        r.path = UIBezierPath(ovalIn: CGRect(x: -40, y: -40, width: 80, height: 80)).cgPath
        r.position = p
        r.fillColor = UIColor.clear.cgColor
        r.strokeColor = Self.tint.cgColor
        r.lineWidth = 3
        r.shadowColor = Self.tint.cgColor
        r.shadowRadius = 12
        r.shadowOpacity = 1
        r.shadowOffset = .zero
        glow.addSublayer(r)
        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 0.3
        grow.toValue = 1.6
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        let group = CAAnimationGroup()
        group.animations = [grow, fade]
        group.duration = 0.6
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        r.opacity = 0
        CATransaction.begin()
        CATransaction.setCompletionBlock { r.removeFromSuperlayer() }
        r.add(group, forKey: "ring")
        CATransaction.commit()
    }

    private func animateOut(_ layer: CALayer, life: CFTimeInterval, to scale: CGFloat) {
        let shrink = CABasicAnimation(keyPath: "transform.scale")
        shrink.fromValue = 1
        shrink.toValue = scale
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        let group = CAAnimationGroup()
        group.animations = [shrink, fade]
        group.duration = life
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.opacity = 0
        CATransaction.begin()
        CATransaction.setCompletionBlock { layer.removeFromSuperlayer() }
        layer.add(group, forKey: "fade")
        CATransaction.commit()
    }
}

/// Watches every touch on the pad and takes none.
private final class BackTouchWatcher: UIGestureRecognizer {
    var onTouch: (UITouch, UITouch.Phase) -> Void = { _, _ in }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) { touches.forEach { onTouch($0, .began) } }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) { touches.forEach { onTouch($0, .moved) } }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        touches.forEach { onTouch($0, .ended) }
        if event.allTouches?.allSatisfy({ $0.phase == .ended || $0.phase == .cancelled }) ?? true { state = .failed }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        touches.forEach { onTouch($0, .cancelled) }
        state = .failed
    }
    override func reset() {}
}

// MARK: - Calibration

/// How the back panel's own axes sit against the front panel's, learned from two strokes behind the
/// phone (right, then up) and kept. UIKit gives each screen's fixed axes; only this relation between
/// the two panels is hardware, so it is measured once instead of assumed.
@MainActor
final class BackCalibration: ObservableObject {
    static let shared = BackCalibration()
    static let key = "DuoDeck.backPanelMatrix"
    static let changed = Notification.Name("DuoDeck.backPanelChanged")

    enum Step: Equatable { case idle, right, up, done }
    @Published private(set) var step: Step = .idle
    @Published private(set) var progress: CGFloat = 0

    private var accumulated = CGPoint.zero
    private var first: (panelAxis: Int, frontAxis: Int, sign: Int)?
    private let haptic = UINotificationFeedbackGenerator()

    /// a, b, c, d: front.x = a·p.x + c·p.y, front.y = b·p.x + d·p.y. Default: x mirrored, y kept.
    static var matrix: CGAffineTransform {
        guard let m = UserDefaults.standard.array(forKey: key) as? [Int], m.count == 4 else {
            return CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
        }
        return CGAffineTransform(a: CGFloat(m[0]), b: CGFloat(m[1]), c: CGFloat(m[2]), d: CGFloat(m[3]), tx: 0, ty: 0)
    }

    static var calibrated: Bool { UserDefaults.standard.array(forKey: key) != nil }

    var active: Bool { step == .right || step == .up }

    func start() {
        accumulated = .zero
        progress = 0
        first = nil
        step = .right
        haptic.prepare()
    }

    func cancel() { step = .idle }

    /// One finger moved `panel` points behind the phone (the back panel's fixed axes); `front` is the
    /// direction asked for, in the front panel's fixed axes.
    func feed(panel: CGPoint, front: CGPoint) {
        guard active else { return }
        accumulated.x += panel.x
        accumulated.y += panel.y
        let length = hypot(accumulated.x, accumulated.y)
        progress = min(1, length / 160)
        guard length >= 160 else { return }
        let panelAxis = abs(accumulated.x) >= abs(accumulated.y) ? 0 : 1
        let panelValue = panelAxis == 0 ? accumulated.x : accumulated.y
        let frontAxis = abs(front.x) >= abs(front.y) ? 0 : 1
        let frontValue = frontAxis == 0 ? front.x : front.y
        let sign = (panelValue > 0) == (frontValue > 0) ? 1 : -1
        accumulated = .zero
        progress = 0
        if step == .right {
            first = (panelAxis, frontAxis, sign)
            step = .up
            haptic.notificationOccurred(.success)
            return
        }
        guard let f = first, f.panelAxis != panelAxis, f.frontAxis != frontAxis else {
            // Both strokes went along the same axis: start over.
            first = nil
            step = .right
            haptic.notificationOccurred(.warning)
            return
        }
        var m = [0, 0, 0, 0]
        func put(_ panelAxis: Int, _ frontAxis: Int, _ sign: Int) {
            m[frontAxis == 0 ? (panelAxis == 0 ? 0 : 2) : (panelAxis == 0 ? 1 : 3)] = sign
        }
        put(f.panelAxis, f.frontAxis, f.sign)
        put(panelAxis, frontAxis, sign)
        UserDefaults.standard.set(m, forKey: Self.key)
        NotificationCenter.default.post(name: Self.changed, object: nil)
        haptic.notificationOccurred(.success)
        step = .done
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            if self.step == .done { self.step = .idle }
        }
    }
}

/// The front's half of calibration: what to do, with an arrow that points the way.
struct BackCalibrationCard: View {
    @ObservedObject var calibration = BackCalibration.shared

    var body: some View {
        if calibration.step != .idle {
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea()
                VStack(spacing: 18) {
                    Image(systemName: symbol)
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(Palette.accent)
                        .symbolEffect(.pulse, isActive: calibration.active)
                        .contentTransition(.symbolEffect(.replace))
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if calibration.active {
                        ProgressView(value: calibration.progress).tint(Palette.accent).frame(maxWidth: 220)
                        Button("Cancel") { calibration.cancel() }.buttonStyle(.bordered)
                    }
                }
                .padding(28)
                .frame(maxWidth: 360)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(24)
            }
            .transition(.opacity)
        }
    }

    private var symbol: String {
        switch calibration.step {
        case .right: return "arrow.right"
        case .up: return "arrow.up"
        default: return "checkmark.circle.fill"
        }
    }

    private var title: String {
        switch calibration.step {
        case .right: return "Behind the phone, slide one finger to the right"
        case .up: return "Now slide it up"
        default: return "Back trackpad ready"
        }
    }

    private var detail: String {
        switch calibration.step {
        case .right, .up: return "Right and up as you see this screen. This teaches DuoDeck how your back screen sits, once."
        default: return "It moves the way you feel it, in every pose."
        }
    }
}
