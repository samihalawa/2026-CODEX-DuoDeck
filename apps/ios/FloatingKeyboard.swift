import SwiftUI
import UIKit
import StreamProtocol

// The floating keyboard: DuoDeck's own small keyboard over the stream, for a phone above all. iOS's
// keyboard is fixed to the bottom and covers a third of the picture; this one is a panel the person
// drags wherever the Mac's text is not, sees through when they want, and closes from its own bar. It
// is no input view: nothing becomes first responder, so iOS shows no keyboard, the layouts never move
// for it, and a hardware keyboard keeps working beside it.
//
// What a key sends is what the key row sends (StreamClient.sendFromKeyRow): a character as text, so
// the Mac's own layout is never guessed, or, with ⌃, ⌥ or ⌘ latched, the key with those modifiers.
// Delete, Return and the arrows go down at the touch and up at its release, so the Mac repeats a held
// one at its own rate (KeyRepeat on the host).

enum FloatingKeyboard {
    /// The Keyboard button brings this up instead of iOS's keyboard.
    static let key = "DuoDeck.floatingKeyboard"
    static let xKey = "DuoDeck.floatingKeyboard.x"
    static let yKey = "DuoDeck.floatingKeyboard.y"
    static let clearKey = "DuoDeck.floatingKeyboard.clear"
    static let sizeKey = "DuoDeck.floatingKeyboard.size"

    static var enabled: Bool { UserDefaults.standard.bool(forKey: key) }

    /// The panel's width in a container this wide: a phone's width less a margin, 400 pt at most,
    /// times the person's size step, always fitting inside `container` even during narrow transitions.
    static func width(in container: CGFloat, step: Double) -> CGFloat {
        guard container.isFinite, container > 0 else { return 320 }
        let safeStep = (step.isFinite && step >= 0.7 && step <= 1.35) ? CGFloat(step) : 1.0
        let maxAllowed = max(220, container - 8)
        let base = min(max(220, container - 16), 400)
        return min(maxAllowed, max(min(260, maxAllowed), base * safeStep))
    }

    /// The panel's centre kept inside the container, whole on screen, clear of the top & bottom safe
    /// areas and any active iPhone Duo fold band.
    static func clamp(_ center: CGPoint, panel: CGSize, in container: CGSize,
                      topInset: CGFloat = 0, bottomInset: CGFloat = 0,
                      fold: FoldInfo = .inferred) -> CGPoint {
        guard container.width.isFinite, container.height.isFinite,
              container.width > 0, container.height > 0 else {
            return CGPoint(x: 180, y: 240)
        }
        let safeW = (panel.width.isFinite && panel.width > 0) ? min(panel.width, container.width - 8) : min(340, container.width - 8)
        let safeH = (panel.height.isFinite && panel.height > 0) ? min(panel.height, max(120, container.height - topInset - bottomInset - 8)) : 230
        let halfW = safeW / 2, halfH = safeH / 2
        let minX = halfW + 4, maxX = max(minX, container.width - halfW - 4)
        let topClear = max(8, topInset + 4)
        let bottomClear = max(8, bottomInset + 4)
        let minY = halfH + topClear
        let maxY = max(minY, container.height - halfH - bottomClear)
        let cx = center.x.isFinite ? center.x : container.width * 0.5
        let cy = center.y.isFinite ? center.y : container.height * 0.62
        var x = min(max(cx, minX), maxX)
        var y = min(max(cy, minY), maxY)
        if let band = fold.verticalBand, x - halfW < band.maxX, x + halfW > band.minX {
            let leadingMax = band.minX - halfW - 4
            let trailingMin = band.maxX + halfW + 4
            let fitsLeading = leadingMax >= minX
            let fitsTrailing = trailingMin <= maxX
            if x <= band.midX {
                if fitsLeading { x = leadingMax }
                else if fitsTrailing { x = trailingMin }
            } else {
                if fitsTrailing { x = trailingMin }
                else if fitsLeading { x = leadingMax }
            }
        }
        if let band = fold.horizontalBand, y - halfH < band.maxY, y + halfH > band.minY {
            let belowMin = band.maxY + halfH + 4
            let aboveMax = band.minY - halfH - 4
            let fitsBelow = belowMin <= maxY
            let fitsAbove = aboveMax >= minY
            if y >= band.midY {
                if fitsBelow { y = belowMin }
                else if fitsAbove { y = aboveMax }
            } else {
                if fitsAbove { y = aboveMax }
                else if fitsBelow { y = belowMin }
            }
        }
        return CGPoint(x: x, y: y)
    }
}

/// Whether the floating keyboard shows on a stream screen. One per screen, as its InputOverlayProxy.
final class FloatingKeyboardState: ObservableObject {
    @Published var shown = false
}

struct FloatingKeyboardPanel: View {
    let client: StreamClient
    let container: CGSize
    var topInset: CGFloat = 0
    var bottomInset: CGFloat = 0
    var switchToSystemKeyboard: (() -> Void)? = nil
    let close: () -> Void

    @AppStorage(FloatingKeyboard.xKey) private var storedX = 0.5
    @AppStorage(FloatingKeyboard.yKey) private var storedY = 0.62
    @AppStorage(FloatingKeyboard.clearKey) private var clear = false
    @AppStorage(FloatingKeyboard.sizeKey) private var sizeStep = 1.0
    @AppStorage("DuoDeck.haptics") private var haptics = true
    @Environment(\.duoFold) private var duoFold
    @Environment(\.scenePhase) private var scenePhase

    @State private var layer = Layer.letters
    @State private var shift = Shift.off
    @State private var latched: KeyModifiers = []
    @State private var held: Set<UInt16> = []
    @State private var panelSize = CGSize(width: 360, height: 250)
    @GestureState private var drag = CGSize.zero
    @GestureState private var activeHoldUsage: UInt16? = nil

    private enum Layer { case letters, numbers, symbols }
    private enum Shift { case off, once, locked }

    private static let letters = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
    private static let numbers = ["1234567890", "-/:;()$&@\"", ".,?!'"]
    private static let symbols = ["[]{}#%^*+=", "_\\|~<>€£¥•", ".,?!'"]

    private var safeStoredX: Double { (storedX.isFinite && storedX >= 0 && storedX <= 1) ? storedX : 0.5 }
    private var safeStoredY: Double { (storedY.isFinite && storedY >= 0 && storedY <= 1) ? storedY : 0.62 }
    private var width: CGFloat { FloatingKeyboard.width(in: container.width, step: sizeStep) }
    private var gap: CGFloat { width < 290 ? 3.5 : 5 }
    private var keyWidth: CGFloat { max(18, (width - 16 - 9 * gap) / 10) }
    private var keyHeight: CGFloat {
        let base = min(44, max(32, keyWidth * 1.22))
        // Ensure the full 6-row keyboard always fits inside short landscape / half-folded screens
        // without clipping its drag handle or bottom row off-screen.
        let usableH = max(160, container.height - max(8, topInset) - max(8, bottomInset) - 16)
        let maxKeyH = max(24, (usableH - 16 - 28 - 5 * gap) / 4.82)
        return min(base, maxKeyH)
    }

    var body: some View {
        let stored = CGPoint(x: safeStoredX * container.width, y: safeStoredY * container.height)
        let center = FloatingKeyboard.clamp(CGPoint(x: stored.x + drag.width, y: stored.y + drag.height),
                                            panel: panelSize, in: container,
                                            topInset: topInset, bottomInset: bottomInset, fold: duoFold)
        VStack(spacing: gap) {
            handle
            modifierRow
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                keyRow(row, index: index)
            }
            bottomRow
        }
        .padding(8)
        .frame(width: width)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
        .opacity(clear ? 0.58 : 1)
        .background(GeometryReader { geo in
            Color.clear.onChange(of: geo.size, initial: true) { _, size in
                if size.width > 0, size.height > 0 { panelSize = size }
            }
        })
        .position(center)
        .zIndex(100)
        .animation(drag == .zero ? .spring(response: 0.3, dampingFraction: 0.82) : nil, value: center)
        .transition(.scale(scale: 0.86).combined(with: .opacity))
        .onAppear { sanitizeStoredState() }
        .onChange(of: container) { _, _ in clampStoredToContainer() }
        .onChange(of: activeHoldUsage) { oldUsage, newUsage in
            // SwiftUI always resets @GestureState when a gesture ends OR is cancelled by a system
            // gesture, second touch, or layout change — guaranteeing held keys never stick down.
            if let oldUsage, oldUsage != newUsage, held.remove(oldUsage) != nil {
                KeyChord.up(oldUsage, with: latched).forEach { client.sendFromKeyRow($0) }
                latched = []
            }
            if let newUsage, !held.contains(newUsage) {
                held.insert(newUsage)
                tick()
                KeyChord.down(newUsage, with: latched).forEach { client.sendFromKeyRow($0) }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { releaseAll() }
        }
        .onDisappear(perform: releaseAll)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Floating keyboard")
    }

    private func sanitizeStoredState() {
        if !storedX.isFinite || storedX < 0 || storedX > 1 { storedX = 0.5 }
        if !storedY.isFinite || storedY < 0 || storedY > 1 { storedY = 0.62 }
        if !sizeStep.isFinite || sizeStep < 0.7 || sizeStep > 1.35 { sizeStep = 1.0 }
        clampStoredToContainer()
    }

    private func clampStoredToContainer() {
        guard container.width > 120, container.height > 120 else { return }
        let kept = FloatingKeyboard.clamp(
            CGPoint(x: safeStoredX * container.width, y: safeStoredY * container.height),
            panel: panelSize, in: container,
            topInset: topInset, bottomInset: bottomInset, fold: duoFold)
        storedX = kept.x / container.width
        storedY = kept.y / container.height
    }

    // MARK: Rows

    private var rows: [String] {
        switch layer {
        case .letters: return Self.letters
        case .numbers: return Self.numbers
        case .symbols: return Self.symbols
        }
    }

    /// The bar the panel is dragged by, with what changes the panel itself.
    /// Buttons stay outside the drag gesture so taps never get swallowed as drags; double-tapping
    /// the central grip recenters and resets the keyboard size.
    private var handle: some View {
        HStack(spacing: 6) {
            barButton(clear ? "circle.lefthalf.filled" : "circle.fill", label: clear ? "Make solid" : "Make see-through") {
                clear.toggle()
            }
            barButton("textformat.size", label: "Change keyboard size") {
                sizeStep = sizeStep < 0.9 ? 1.0 : (sizeStep < 1.1 ? 1.2 : 0.8)
            }
            ZStack {
                Color.clear
                Capsule().fill(.secondary.opacity(0.65)).frame(width: 48, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                tick()
                sizeStep = 1.0
                storedX = 0.5
                storedY = 0.68
            }
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .global)
                    .updating($drag) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        let moved = CGPoint(x: safeStoredX * container.width + value.translation.width,
                                            y: safeStoredY * container.height + value.translation.height)
                        let kept = FloatingKeyboard.clamp(moved, panel: panelSize, in: container,
                                                          topInset: topInset, bottomInset: bottomInset, fold: duoFold)
                        if container.width > 0 { storedX = kept.x / container.width }
                        if container.height > 0 { storedY = kept.y / container.height }
                    }
            )
            .accessibilityLabel("Move floating keyboard")
            .accessibilityHint("Drag to move, double-tap to recenter")
            if let switchToSystemKeyboard {
                barButton("keyboard", label: "Switch to standard keyboard", action: switchToSystemKeyboard)
            }
            barButton("keyboard.chevron.compact.down", label: "Hide the keyboard", action: close)
        }
        .frame(height: 28)
    }

    private func barButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// esc, tab, the latching modifiers and the arrows.
    private var modifierRow: some View {
        HStack(spacing: gap) {
            cap("esc") { press(HIDKey.escape) }
            cap("tab") { press(HIDKey.tab) }
            latch("⌃", .control, "Control")
            latch("⌥", .option, "Option")
            latch("⌘", .command, "Command")
            holdKey(symbol: "arrow.left", usage: HIDKey.leftArrow, label: "Left")
            holdKey(symbol: "arrow.down", usage: HIDKey.downArrow, label: "Down")
            holdKey(symbol: "arrow.up", usage: HIDKey.upArrow, label: "Up")
            holdKey(symbol: "arrow.right", usage: HIDKey.rightArrow, label: "Right")
        }
        .frame(height: keyHeight * 0.82)
    }

    private func keyRow(_ row: String, index: Int) -> some View {
        HStack(spacing: gap) {
            if index == 2 {
                if layer == .letters {
                    wideKey(symbol: shift == .locked ? "capslock.fill" : (shift == .once ? "shift.fill" : "shift"),
                            on: shift != .off, label: "Shift") {
                        shift = shift == .off ? .once : (shift == .once ? .locked : .off)
                    }
                } else {
                    wideKey(text: layer == .numbers ? "#+=" : "123", on: false, label: "More symbols") {
                        layer = layer == .numbers ? .symbols : .numbers
                    }
                }
            }
            ForEach(Array(row), id: \.self) { character in
                let shown = layer == .letters && shift != .off ? Character(character.uppercased()) : character
                Button { type(shown) } label: {
                    Text(String(shown))
                        .font(.system(size: min(20, keyHeight * 0.48), weight: .regular))
                        .frame(maxWidth: index == 2 ? keyWidth * 1.08 : .infinity, maxHeight: .infinity)
                        .background(Palette.control, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(FloatingKeyStyle())
            }
            if index == 2 {
                holdKey(symbol: "delete.left", usage: HIDKey.deleteBackward, label: "Delete", wide: true)
            }
        }
        .frame(height: keyHeight)
        .padding(.horizontal, index == 1 ? keyWidth / 2 : 0)
    }

    private var bottomRow: some View {
        HStack(spacing: gap) {
            wideKey(text: layer == .letters ? "123" : "ABC", on: false, label: layer == .letters ? "Numbers" : "Letters") {
                layer = layer == .letters ? .numbers : .letters
            }
            Button { type(" ") } label: {
                Text("space")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.control, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(FloatingKeyStyle())
            .accessibilityLabel("Space")
            holdKey(symbol: "return", usage: 0x28, label: "Return", wide: true, accent: true)
        }
        .frame(height: keyHeight)
    }

    // MARK: Keys

    private func cap(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.control, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(FloatingKeyStyle())
    }

    private func latch(_ title: String, _ modifier: KeyModifiers, _ name: String) -> some View {
        let on = latched.contains(modifier)
        return Button {
            tick()
            if on { latched.remove(modifier) } else { latched.insert(modifier) }
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(on ? Palette.onAccent : Palette.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(on ? Palette.accent : Palette.control, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(FloatingKeyStyle())
        .accessibilityLabel(name)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func wideKey(symbol: String? = nil, text: String? = nil, on: Bool, label: String,
                         action: @escaping () -> Void) -> some View {
        Button { tick(); action() } label: {
            Group {
                if let symbol { Image(systemName: symbol).font(.system(size: 16, weight: .medium)) }
                if let text { Text(text).font(.system(size: 13, weight: .medium)) }
            }
            .foregroundStyle(on ? Palette.onAccent : Palette.text)
            .frame(width: keyWidth * 1.45)
            .frame(maxHeight: .infinity)
            .background(on ? Palette.accent : Color(uiColor: .secondarySystemFill), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(FloatingKeyStyle())
        .accessibilityLabel(label)
    }

    /// A key that is down while the finger is: the Mac repeats it. VoiceOver's activation presses it once.
    /// Uses `@GestureState` so any gesture interruption/cancellation automatically sends key-up and
    /// never leaves a key stuck down.
    private func holdKey(symbol: String, usage: UInt16, label: String, wide: Bool = false, accent: Bool = false) -> some View {
        let down = held.contains(usage) || activeHoldUsage == usage
        return Image(systemName: symbol)
            .font(.system(size: wide ? 16 : 13, weight: .medium))
            .foregroundStyle(accent ? Palette.onAccent : Palette.text)
            .frame(width: wide ? keyWidth * 1.45 : nil)
            .frame(maxWidth: wide ? nil : .infinity, maxHeight: .infinity)
            .background(accent ? Palette.accent : Palette.control, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .opacity(down ? 0.55 : 1)
            .scaleEffect(down ? 0.94 : 1)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($activeHoldUsage) { _, state, _ in
                        state = usage
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { press(usage) }
    }

    // MARK: Sending

    private func tick() {
        if haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6) }
    }

    private func press(_ usage: UInt16) {
        tick()
        KeyChord.press(usage, with: latched).forEach { client.sendFromKeyRow($0) }
        latched = []
    }

    /// A character: text, as the Mac's own keyboard layout need not match this one; with ⌃, ⌥ or ⌘
    /// latched, its key with them (⌘S), which no text can say.
    private func type(_ character: Character) {
        tick()
        if !latched.isDisjoint(with: .shortcutMakers), let usage = HIDKey.usage(for: character) {
            let modifiers = shift != .off && layer == .letters ? latched.union(.shift) : latched
            KeyChord.press(usage, with: modifiers).forEach { client.sendFromKeyRow($0) }
        } else {
            client.sendFromKeyRow(.text(String(character)))
        }
        latched = []
        if shift == .once { shift = .off }
    }

    /// The panel going with a key still down: every held key comes up on the Mac.
    private func releaseAll() {
        for usage in held { KeyChord.up(usage, with: latched).forEach { client.sendFromKeyRow($0) } }
        held = []
    }
}

private struct FloatingKeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Palette.text)
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
