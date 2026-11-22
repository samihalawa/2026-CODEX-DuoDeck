import CoreGraphics
import Foundation
import StreamProtocol

/// Session-only macOS display resolution switcher and vertical-desktop mirror manager.
///
/// Safety guarantees:
/// - Always uses `kCGConfigureForSession` (`.forSession`) so macOS reverts automatically if the process exits unexpectedly.
/// - Never persists a chosen mode across launches; `restoreSync()` unmirrors and restores the original physical mode on
///   `"native"`, when the last client disconnects (`clientCount == 0`), and on process exit (`shutdownForExit` / signal).
@MainActor
final class DisplayResolutionManager {
    private static let mirrorVendorID: UInt32 = 0x5112
    private static let mirrorProductID: UInt32 = 0x0001
    private static let mirrorSerial: UInt32 = 0x4456_0001

    private let hardwareEnabled: Bool
    private var physicalDisplayID: CGDirectDisplayID?
    private var originalMode: CGDisplayMode?
    private var mirrorDisplay: VirtualDisplay?
    private var mirrorActive = false
    private(set) var appliedModeID: String?
    private var activeVerticalSize: (width: Int, height: Int)?

    /// Non-nil when a portrait mirror virtual display is currently the active desktop render target.
    var captureDisplayID: CGDirectDisplayID? {
        guard mirrorActive, let d = mirrorDisplay, d.displayID != 0 else { return nil }
        return d.displayID
    }

    init(hardwareEnabled: Bool = true) {
        self.hardwareEnabled = hardwareEnabled
    }

    deinit {
        // Best-effort failsafe if released outside explicit shutdown.
        let pid = physicalDisplayID
        let orig = originalMode
        let mirrored = mirrorActive
        if mirrored || orig != nil {
            var cfg: CGDisplayConfigRef?
            if CGBeginDisplayConfiguration(&cfg) == .success, let cfg {
                if mirrored, let pid {
                    CGConfigureDisplayMirrorOfDisplay(cfg, pid, kCGNullDirectDisplay)
                }
                if let pid, let orig {
                    CGConfigureDisplayWithDisplayMode(cfg, pid, orig, nil)
                }
                CGCompleteDisplayConfiguration(cfg, .forSession)
            }
        }
    }

    static func isMirrorVirtualDisplay(_ id: CGDirectDisplayID) -> Bool {
        CGDisplayVendorNumber(id) == mirrorVendorID
    }

    private func resolvePhysicalDisplay() -> CGDirectDisplayID? {
        if let pid = physicalDisplayID, CGDisplayIsOnline(pid) != 0 || CGDisplayCopyDisplayMode(pid) != nil {
            return pid
        }
        let main = CGMainDisplayID()
        if main != 0, !Self.isMirrorVirtualDisplay(main), CGDisplayVendorNumber(main) != 0x5111 {
            physicalDisplayID = main
            return main
        }
        var count: UInt32 = 0
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        // Use online displays so mirrored physical displays remain discoverable while vertical mirror is active.
        guard CGGetOnlineDisplayList(16, &ids, &count) == .success else { return nil }
        let found = ids.prefix(Int(count)).first { id in
            id != 0 && !Self.isMirrorVirtualDisplay(id) && CGDisplayVendorNumber(id) != 0x5111
        }
        physicalDisplayID = found
        return found
    }

    private func ensureBaselineCaptured(for displayID: CGDirectDisplayID) {
        if physicalDisplayID == nil { physicalDisplayID = displayID }
        if originalMode == nil {
            originalMode = CGDisplayCopyDisplayMode(displayID)
        }
    }

    /// Advertises Default, Vertical Desktop presets, and all usable resolutions of the Mac's primary physical display.
    func options(virtualDisplaySupported: Bool = true) -> [DisplayResolutionOption] {
        guard let pid = resolvePhysicalDisplay() else {
            return [DisplayResolutionOption(id: "native", label: "Default", detail: "Current Mac display",
                                            isVertical: false, isDefault: true)]
        }
        let baseline = originalMode ?? CGDisplayCopyDisplayMode(pid)
        let defaultDetail = baseline.map { "\($0.width) × \($0.height)" }

        var result: [DisplayResolutionOption] = [
            DisplayResolutionOption(id: "native", label: "Default", detail: defaultDetail,
                                    isVertical: false, isDefault: true)
        ]

        if hardwareEnabled, virtualDisplaySupported {
            result.append(contentsOf: [
                DisplayResolutionOption(id: "vertical:auto", label: "Vertical (Match Device)",
                                        detail: "Whole desktop · portrait", isVertical: true, isDefault: false),
                DisplayResolutionOption(id: "vertical:640x1140", label: "Vertical 640 × 1140",
                                        detail: "Large text · 9:16 portrait", isVertical: true, isDefault: false),
                DisplayResolutionOption(id: "vertical:756x1344", label: "Vertical 756 × 1344",
                                        detail: "Balanced · 9:16 portrait", isVertical: true, isDefault: false),
                DisplayResolutionOption(id: "vertical:900x1600", label: "Vertical 900 × 1600",
                                        detail: "Spacious · 9:16 portrait", isVertical: true, isDefault: false),
            ])
        }

        let modes = bestModesBySize(for: pid, baseline: baseline)
        for mode in modes {
            let id = "\(mode.width)x\(mode.height)"
            let isHiDPI = mode.pixelWidth > mode.width
            let isDefault = baseline.map { $0.width == mode.width && $0.height == mode.height } ?? false
            result.append(DisplayResolutionOption(
                id: id,
                label: "\(mode.width) × \(mode.height)",
                detail: isHiDPI ? (isDefault ? "Default · HiDPI" : "HiDPI") : "1×",
                isVertical: false,
                isDefault: isDefault
            ))
        }
        return result
    }

    func acceptedIDs(virtualDisplaySupported: Bool = true) -> Set<String> {
        Set(options(virtualDisplaySupported: virtualDisplaySupported).map(\.id))
    }

    /// Computes even portrait dimensions matching `viewport`'s aspect ratio (`CGVirtualDisplay` requires `max >= 800`).
    static func autoVerticalSize(for viewport: Viewport?) -> (width: Int, height: Int) {
        let baseWidth = 720
        guard let v = viewport, v.width > 0, v.height > 0 else {
            return (width: 720, height: 1280)
        }
        // Keep aspect inside a sane portrait band [1.33, 2.35].
        let rawRatio = v.height >= v.width ? (v.height / v.width) : (v.width / v.height)
        let aspect = min(max(rawRatio, 1.33), 2.35)
        var w = baseWidth
        var h = Int((Double(w) * aspect).rounded())
        if h < 960 {
            h = 960
            w = Int((Double(h) / aspect).rounded())
        }
        w = max(600, w - (w % 2))
        h = max(960, h - (h % 2))
        return (width: w, height: h)
    }

    /// Applies `modeID` (`nil` or `"native"` restores default). Returns `true` when display state actually changed.
    @discardableResult
    func apply(modeID: String?, viewport: Viewport? = nil) async -> Bool {
        let target = (modeID == nil || modeID == "native" || modeID?.isEmpty == true) ? nil : modeID
        guard let target else {
            return restoreSync()
        }
        guard hardwareEnabled, let pid = resolvePhysicalDisplay() else { return false }

        if target.hasPrefix("vertical:") {
            let size = parseVerticalSize(target, viewport: viewport)
            if appliedModeID == target, let current = activeVerticalSize,
               abs(current.width - size.width) <= 16, abs(current.height - size.height) <= 16,
               mirrorActive, mirrorDisplay?.isAlive == true {
                return false
            }
            return await applyVerticalMirror(modeID: target, size: size, physicalID: pid)
        }

        if appliedModeID == target && !mirrorActive {
            return false
        }
        return await applyPhysicalResolution(modeID: target, physicalID: pid)
    }

    /// Synchronously unmirrors any vertical display and restores the original physical resolution.
    @discardableResult
    func restoreSync() -> Bool {
        let hadChanges = appliedModeID != nil || mirrorActive || mirrorDisplay != nil || originalMode != nil
        guard hadChanges else { return false }

        if mirrorActive || originalMode != nil, let pid = physicalDisplayID ?? resolvePhysicalDisplay() {
            var cfg: CGDisplayConfigRef?
            if CGBeginDisplayConfiguration(&cfg) == .success, let cfg {
                if mirrorActive {
                    CGConfigureDisplayMirrorOfDisplay(cfg, pid, kCGNullDirectDisplay)
                }
                if let orig = originalMode {
                    CGConfigureDisplayWithDisplayMode(cfg, pid, orig, nil)
                }
                let err = CGCompleteDisplayConfiguration(cfg, .forSession)
                if err != .success {
                    CGCancelDisplayConfiguration(cfg)
                    print("Display restore failed: CGError \(err.rawValue)")
                } else if appliedModeID != nil {
                    print("Display restored to \(originalMode.map { "\($0.width) × \($0.height)" } ?? "default").")
                }
            }
        }

        mirrorDisplay?.destroy()
        mirrorDisplay = nil
        mirrorActive = false
        appliedModeID = nil
        activeVerticalSize = nil
        originalMode = nil
        return true
    }

    // MARK: - Helpers

    private func parseVerticalSize(_ modeID: String, viewport: Viewport?) -> (width: Int, height: Int) {
        if modeID == "vertical:auto" {
            return Self.autoVerticalSize(for: viewport)
        }
        let dims = modeID.replacingOccurrences(of: "vertical:", with: "").split(separator: "x")
        if dims.count == 2, let w = Int(dims[0]), let h = Int(dims[1]), w >= 480, h >= 800 {
            return (w - (w % 2), h - (h % 2))
        }
        return (756, 1344)
    }

    private func applyPhysicalResolution(modeID: String, physicalID: CGDirectDisplayID) async -> Bool {
        let dims = modeID.split(separator: "x")
        guard dims.count == 2, let w = Int(dims[0]), let h = Int(dims[1]) else { return false }

        ensureBaselineCaptured(for: physicalID)
        let baseline = originalMode ?? CGDisplayCopyDisplayMode(physicalID)
        let candidates = bestModesBySize(for: physicalID, baseline: baseline)
        guard let chosen = candidates.first(where: { $0.width == w && $0.height == h }) else {
            print("Display mode \(modeID) is not supported on display \(physicalID).")
            return false
        }

        var cfg: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&cfg) == .success, let cfg else { return false }
        if mirrorActive {
            CGConfigureDisplayMirrorOfDisplay(cfg, physicalID, kCGNullDirectDisplay)
        }
        CGConfigureDisplayWithDisplayMode(cfg, physicalID, chosen, nil)
        let err = CGCompleteDisplayConfiguration(cfg, .forSession)
        guard err == .success else {
            CGCancelDisplayConfiguration(cfg)
            print("Could not switch display to \(modeID): CGError \(err.rawValue)")
            return false
        }

        mirrorDisplay?.destroy()
        mirrorDisplay = nil
        mirrorActive = false
        activeVerticalSize = nil
        appliedModeID = modeID
        let deadline = Date().addingTimeInterval(1.5)
        while Date() < deadline {
            if let cur = CGDisplayCopyDisplayMode(physicalID),
               cur.width == w, cur.height == h,
               CGDisplayMirrorsDisplay(physicalID) == kCGNullDirectDisplay {
                break
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        print("Display switched to \(w) × \(h)\(chosen.pixelWidth > chosen.width ? " (HiDPI)" : "").")
        return true
    }

    private func applyVerticalMirror(modeID: String, size: (width: Int, height: Int),
                                     physicalID: CGDirectDisplayID) async -> Bool {
        ensureBaselineCaptured(for: physicalID)

        // Tear down an earlier mirror virtual display cleanly before replacing its geometry.
        if mirrorActive {
            var cfg: CGDisplayConfigRef?
            if CGBeginDisplayConfiguration(&cfg) == .success, let cfg {
                CGConfigureDisplayMirrorOfDisplay(cfg, physicalID, kCGNullDirectDisplay)
                CGCompleteDisplayConfiguration(cfg, .forSession)
            }
            mirrorActive = false
        }
        mirrorDisplay?.destroy()
        mirrorDisplay = nil

        do {
            let vd = try VirtualDisplay(
                name: "DuoDeck Vertical",
                widthPt: size.width,
                heightPt: size.height,
                scale: 2,
                refreshHz: 60,
                vendorID: Self.mirrorVendorID,
                productID: Self.mirrorProductID,
                serialNum: Self.mirrorSerial
            )
            let online = await vd.waitUntilOnline(timeout: 3.0)
            guard online, vd.displayID != 0 else {
                vd.destroy()
                print("Vertical desktop virtual display did not come online in time.")
                return false
            }

            var cfg: CGDisplayConfigRef?
            guard CGBeginDisplayConfiguration(&cfg) == .success, let cfg else {
                vd.destroy()
                return false
            }
            // Mirror the physical Mac display onto the portrait virtual display (hidpi-mirror pattern).
            CGConfigureDisplayMirrorOfDisplay(cfg, physicalID, vd.displayID)
            let err = CGCompleteDisplayConfiguration(cfg, .forSession)
            guard err == .success else {
                CGCancelDisplayConfiguration(cfg)
                vd.destroy()
                print("Could not mirror display to vertical \(size.width) × \(size.height): CGError \(err.rawValue)")
                return false
            }

            mirrorDisplay = vd
            mirrorActive = true
            appliedModeID = modeID
            activeVerticalSize = size
            let mirrorDeadline = Date().addingTimeInterval(1.0)
            while Date() < mirrorDeadline {
                if CGDisplayMirrorsDisplay(physicalID) == vd.displayID,
                   Int(CGDisplayBounds(vd.displayID).width) == size.width,
                   Int(CGDisplayBounds(vd.displayID).height) == size.height {
                    break
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
            print("Display verticalized to \(size.width) × \(size.height) (mirroring display \(physicalID) → \(vd.displayID)).")
            return true
        } catch {
            print("Vertical desktop failed: \(error)")
            return false
        }
    }

    private func bestModesBySize(for displayID: CGDirectDisplayID, baseline: CGDisplayMode?) -> [CGDisplayMode] {
        let opts = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
        guard let all = CGDisplayCopyAllDisplayModes(displayID, opts) as? [CGDisplayMode] else { return [] }
        let targetHz = baseline?.refreshRate ?? 60

        var best: [String: CGDisplayMode] = [:]
        for mode in all {
            guard mode.width >= 640, mode.height >= 480, mode.isUsableForDesktopGUI() else { continue }
            let key = "\(mode.width)x\(mode.height)"
            if let existing = best[key] {
                if Self.isBetterMode(mode, than: existing, targetHz: targetHz) {
                    best[key] = mode
                }
            } else {
                best[key] = mode
            }
        }
        return best.values.sorted {
            if $0.width != $1.width { return $0.width < $1.width }
            return $0.height < $1.height
        }
    }

    private static func isBetterMode(_ lhs: CGDisplayMode, than rhs: CGDisplayMode, targetHz: Double) -> Bool {
        let lhsHiDPI = lhs.pixelWidth > lhs.width
        let rhsHiDPI = rhs.pixelWidth > rhs.width
        if lhsHiDPI != rhsHiDPI { return lhsHiDPI }
        let lhsHzDiff = abs(lhs.refreshRate - targetHz)
        let rhsHzDiff = abs(rhs.refreshRate - targetHz)
        if abs(lhsHzDiff - rhsHzDiff) > 0.5 { return lhsHzDiff < rhsHzDiff }
        return lhs.refreshRate > rhs.refreshRate
    }
}
