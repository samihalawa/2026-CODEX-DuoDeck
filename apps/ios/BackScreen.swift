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
// The trackpad goes the way the holder feels it. Both screens turn with gravity, each upright for
// whoever looks at it, so the back is the front seen from behind in every pose: left and right swap,
// up stays up (`BackPadView.refreshAxis`). Swipes and scrolling follow the same mapping.

/// What the back screen does during a session.
enum BackScreenMode: String, CaseIterable, Identifiable {
    case off, mirror, trackpad, zoom

    static let key = "DuoDeck.backScreen"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .mirror: return "Mirror Mac"
        case .trackpad: return "Trackpad"
        case .zoom: return "Zoom"
        }
    }

    var symbol: String {
        switch self {
        case .off: return "rectangle.slash"
        case .mirror: return "rectangle.on.rectangle"
        case .trackpad: return "rectangle.and.hand.point.up.left"
        case .zoom: return "plus.magnifyingglass"
        }
    }

    static var current: BackScreenMode {
        BackScreenMode(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .off
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
                BackPad(client: client, speed: CGFloat(speed), zoom: false)
            case .zoom:
                zoomBackdrop
                BackPad(client: client, speed: CGFloat(speed), zoom: true)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onChange(of: mode == .trackpad && client.connected, initial: true) { _, on in
            client.setBackPad(on)
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

    /// The zoom dial: how far in the front picture is, live, and how to drive it.
    private var zoomBackdrop: some View {
        ZStack {
            LinearGradient(colors: [Palette.accent.opacity(0.18), .black], startPoint: .bottom, endPoint: .top)
            TimelineView(.animation(minimumInterval: 1 / 30)) { _ in
                let scale = client.pictureZoom?.zoom.scale ?? 1
                let level = (scale - 1) / (StreamZoom.maxScale - 1)
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.12), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: max(0.02, level))
                            .stroke(Palette.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .shadow(color: Palette.accent.opacity(0.9), radius: 14)
                        Text(String(format: "%.1f×", scale))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(width: 132, height: 132)
                    Text("Slide up to zoom in · down to zoom out")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("Pinch works too · Double-tap for the whole screen\nThe zoom follows the pointer you move on the front")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
        }
        .allowsHitTesting(false)
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
    let speed: CGFloat
    /// Zoom: the back drives the front picture's zoom instead of the pointer (BackZoomDriver).
    let zoom: Bool

    func makeUIView(context: Context) -> BackPadView {
        let view = BackPadView()
        configure(view)
        return view
    }

    func updateUIView(_ view: BackPadView, context: Context) { configure(view) }

    private func configure(_ view: BackPadView) {
        let client = self.client
        let pad = view.pad
        pad.send = { client.sendInput($0) }
        pad.setPointer = { client.setOwnPointer($0, from: .trackpad) }
        pad.feed = { let f = client.pointerFeedState; return (f.anchor, f.reseeds) }
        pad.onFingers = { client.trackpadFingers($0) }
        pad.latchedModifiers = []
        pad.travel = min(2.3, max(0.65, speed))
        pad.sendGesture = { client.sendGesture($0, fingers: $1) }
        view.setZoom(zoom ? client : nil)
        view.setNeedsLayout()
    }

    static func dismantleUIView(_ view: BackPadView, coordinator: ()) { view.setZoom(nil) }
}

/// Holds the pad, keeps its mapping current as either screen turns, and draws the glow under fingers.
final class BackPadView: UIView, UIGestureRecognizerDelegate {
    let pad = TrackpadSurface(frame: .zero)
    private var lastKey = ""
    private let glow = CALayer()
    private let watcher = BackTouchWatcher()
    private var lastSpark: [ObjectIdentifier: CGPoint] = [:]
    #if DEBUG
    private var strokeStart: [ObjectIdentifier: CGPoint] = [:]
    #endif

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
        // On this view, not the pad: it sees the pad's touches and, in Zoom, the dial's.
        addGestureRecognizer(watcher)
        zoomPinch.delegate = self
        zoomPan.delegate = self
        zoomPan.maximumNumberOfTouches = 1
        zoomReset.numberOfTapsRequired = 2
        for g in [zoomPinch, zoomPan, zoomReset] as [UIGestureRecognizer] {
            g.isEnabled = false
            addGestureRecognizer(g)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(turned),
                                               name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    @objc private func turned() { lastKey = ""; setNeedsLayout() }

    // MARK: Zoom

    private lazy var zoomPinch = UIPinchGestureRecognizer(target: self, action: #selector(pinched))
    private lazy var zoomPan = UIPanGestureRecognizer(target: self, action: #selector(slid))
    private lazy var zoomReset = UITapGestureRecognizer(target: self, action: #selector(wholePicture))
    private var driver: BackZoomDriver?
    private var zoomFrom: CGFloat = 1
    private let detent = UISelectionFeedbackGenerator()
    private var lastWhole = 1

    /// A client: the back is the front picture's zoom dial; nil: the trackpad (and the zoom, if this
    /// view had it, goes back to the whole picture).
    func setZoom(_ client: StreamClient?) {
        let on = client != nil
        pad.isHidden = on
        pad.isUserInteractionEnabled = !on
        [zoomPinch, zoomPan, zoomReset].forEach { $0.isEnabled = on }
        if let client {
            if driver == nil || driver?.client !== client {
                driver?.stop(reset: false)
                driver = BackZoomDriver(client: client)
                driver?.start()
            }
        } else if let driver {
            driver.stop(reset: true)
            self.driver = nil
        }
    }

    @objc private func pinched(_ g: UIPinchGestureRecognizer) {
        guard let driver else { return }
        switch g.state {
        case .began: zoomFrom = driver.target
        case .changed: steer(zoomFrom * g.scale)
        default: break
        }
    }

    /// One finger, up and down: a dial. Up is in (up stays up on the back), a 240 pt slide is e×.
    @objc private func slid(_ g: UIPanGestureRecognizer) {
        guard let driver else { return }
        switch g.state {
        case .began: zoomFrom = driver.target
        case .changed: steer(zoomFrom * exp(-g.translation(in: self).y / 240))
        default: break
        }
    }

    @objc private func wholePicture() { steer(1) }

    private func steer(_ scale: CGFloat) {
        guard let driver else { return }
        driver.setTarget(scale)
        let whole = Int(driver.target.rounded(.down))
        if whole != lastWhole {
            lastWhole = whole
            if UserDefaults.standard.object(forKey: "DuoDeck.haptics") as? Bool ?? true { detent.selectionChanged() }
        }
    }

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
        guard bounds.width > 0 else { return }
        let key = "\(bounds.size)"
        guard key != lastKey else { return }
        lastKey = key
        // Both screens turn with gravity, each the right way up for whoever looks at it (measured on
        // the Duo: the back screen follows the phone's orientation 1:1, the front follows it a
        // quarter turn over because its panel sits sideways in the body, and both reach all four).
        // So in their own coordinates the back is always the front seen from behind: left and right
        // swap, up stays up — upright, upside down, either side, book or L shape alike.
        pad.axis = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
        // One measure for both axes and every orientation: the back panel's short side, so the same
        // finger travel moves the pointer as far however the phone is held.
        let along = min(bounds.width, bounds.height)
        pad.axisSpan = CGSize(width: along, height: along / 1.6)
    }

    // MARK: Glow

    private func spark(_ touch: UITouch, _ phase: UITouch.Phase) {
        let id = ObjectIdentifier(touch)
        let p = touch.location(in: self)
        switch phase {
        case .began:
            #if DEBUG
            strokeStart[id] = p
            #endif
            lastSpark[id] = p
            ring(at: p)
            dot(at: p, size: 46, life: 0.7)
        case .moved:
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
            #if DEBUG
            if let start = strokeStart[id] {
                print("backscreen: stroke on the back \(Int(p.x - start.x)),\(Int(p.y - start.y)) in \(Int(bounds.width))×\(Int(bounds.height)) → pointer \(Int(start.x - p.x)),\(Int(p.y - start.y))")
            }
            strokeStart[id] = nil
            #endif
            lastSpark[id] = nil
            dot(at: p, size: 60, life: 0.5)
        }
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

// MARK: - The session's View menu

/// How big the Mac's pointer is drawn on this device (HEVCDisplayView), about its tip.
enum PointerSize: String, CaseIterable, Identifiable {
    case normal, large, huge

    static let key = "DuoDeck.pointerSize"
    /// Large: on a phone the Mac's own arrow is a speck, so a session starts with it bigger.
    static let fallback = PointerSize.large
    static var current: PointerSize {
        PointerSize(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? fallback
    }

    var id: String { rawValue }
    var scale: CGFloat {
        switch self {
        case .normal: return 1
        case .large: return 1.8
        case .huge: return 2.6
        }
    }
    var title: String {
        switch self {
        case .normal: return "Normal"
        case .large: return "Large"
        case .huge: return "Extra large"
        }
    }
}

/// The session's live view options, beside Keyboard and Shortcuts rather than in Settings: the back
/// screen (iPhone Duo), the pointer's size, the window's text size (bigger text means a smaller Mac
/// window, as Aa) and the stream's resolution (Standard is lighter and quicker than Retina).
struct SessionViewMenu<Label: View>: View {
    @ObservedObject var client: StreamClient
    @Binding var textScale: Double?
    let label: () -> Label
    @AppStorage(BackScreenMode.key) private var backScreen = BackScreenMode.off.rawValue
    @AppStorage(PointerSize.key) private var pointer = PointerSize.fallback.rawValue
    @AppStorage("DuoDeck.pointerSensitivity") private var speed = 1.25
    @Environment(\.duoEnvironment) private var duo
    /// Settings keeps the fine slider; these are its usual stops.
    private static var speeds: [(title: String, value: Double)] { [
        ("Slow", 0.85), ("Normal", 1.25), ("Fast", 1.7), ("Fastest", 2.2)] }

    init(client: StreamClient, textScale: Binding<Double?>, @ViewBuilder label: @escaping () -> Label) {
        self.client = client
        _textScale = textScale
        self.label = label
    }

    var body: some View {
        Menu {
            if duo.hinge != .unknown {
                Picker(selection: $backScreen) {
                    ForEach(BackScreenMode.allCases) { SwiftUI.Label($0.title, systemImage: $0.symbol).tag($0.rawValue) }
                } label: {
                    SwiftUI.Label("Back screen", systemImage: "iphone.gen3")
                }
                .pickerStyle(.menu)
            }
            Picker(selection: $pointer) {
                ForEach(PointerSize.allCases) { Text($0.title).tag($0.rawValue) }
            } label: {
                SwiftUI.Label("Pointer size", systemImage: "cursorarrow")
            }
            .pickerStyle(.menu)
            Picker(selection: Binding(
                get: { Self.speeds.min(by: { abs($0.value - speed) < abs($1.value - speed) })?.value ?? 1.25 },
                set: { speed = $0 })) {
                ForEach(Self.speeds, id: \.value) { Text($0.title).tag($0.value) }
            } label: {
                SwiftUI.Label("Pointer speed", systemImage: "gauge.with.dots.needle.67percent")
            }
            .pickerStyle(.menu)
            if client.textScaleSelectable {
                let offered = client.textScaleOffersOff
                Picker(selection: Binding(
                    get: { TextScale.position(of: textScale, offered: offered) },
                    set: { textScale = TextScale.scale(at: $0) })) {
                    ForEach(TextScale.detents(offered: offered), id: \.self) { Text(TextScale.title(at: $0)).tag($0) }
                } label: {
                    SwiftUI.Label("Text size", systemImage: "textformat.size")
                }
                .pickerStyle(.menu)
            }
            if let shown = client.settings.displayed {
                Picker(selection: Binding(
                    get: { shown.captureScale >= 1.5 ? 2.0 : 1.0 },
                    set: { client.changeSettings(HostSettingsChange(captureScale: $0)) })) {
                    Text("Retina (sharpest)").tag(2.0)
                    Text("Standard (lighter, faster)").tag(1.0)
                } label: {
                    SwiftUI.Label("Resolution", systemImage: "display")
                }
                .pickerStyle(.menu)
            }
        } label: {
            label()
        }
        .accessibilityLabel("View options")
    }
}

// MARK: - Zoom from the back

/// Eases the front picture's zoom (StreamClient.pictureZoom) toward the back's dial and keeps the
/// pointer in its middle, every frame, so zooming in, out and aiming are one smooth motion while the
/// front's trackpad and picture keep driving the Mac. A pinch on the front wins: its scale becomes the
/// dial's.
@MainActor
final class BackZoomDriver: NSObject {
    weak var client: StreamClient?
    private(set) var target: CGFloat = 1
    private var link: CADisplayLink?
    private var lastSet: StreamZoom?

    init(client: StreamClient) {
        self.client = client
        super.init()
        target = client.pictureZoom?.zoom.scale ?? 1
    }

    func setTarget(_ scale: CGFloat) {
        target = min(StreamZoom.maxScale, max(StreamZoom.minScale, scale))
    }

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop(reset: Bool) {
        link?.invalidate()
        link = nil
        if reset { client?.pictureZoom?.reset() }
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard let client, let model = client.pictureZoom else { return }
        var z = model.zoom
        if let lastSet, lastSet != z { target = z.scale }       // the front pinched
        let pane = z.pane
        guard pane.width > 0, pane.height > 0 else { return }
        let dt = max(1 / 240, min(1 / 20, link.targetTimestamp - link.timestamp))
        let ease = 1 - exp(-dt * 14)
        let follow = 1 - exp(-dt * 9)
        let scale = abs(target - z.scale) < 0.0005 ? target : z.scale + (target - z.scale) * ease
        let mid = CGPoint(x: pane.width / 2, y: pane.height / 2)
        var want = CGSize(width: z.offset.width * scale / max(1, z.scale),
                          height: z.offset.height * scale / max(1, z.scale))
        if let p = client.shownPointer, client.videoSize.width > 0 {
            let r = HEVCDisplayView.videoRect(in: CGRect(origin: .zero, size: pane), videoSize: client.videoSize)
            let at = CGPoint(x: r.minX + p.x * r.width, y: r.minY + p.y * r.height)
            want = CGSize(width: -(at.x - mid.x) * scale, height: -(at.y - mid.y) * scale)
        }
        let offset = CGSize(width: z.offset.width + (want.width - z.offset.width) * follow,
                            height: z.offset.height + (want.height - z.offset.height) * follow)
        if target <= StreamZoom.minScale + 0.001 && scale < StreamZoom.minScale + 0.004 {
            z.reset()
        } else {
            z.aim(scale: scale, offset: offset, in: pane)
        }
        model.set(z)
        lastSet = model.zoom
    }
}
