import Foundation
import SillHostCore
import StreamProtocol

/// User-facing profiles shared by the overview, menu, and streaming preferences.
/// Applying a profile publishes one config change, avoiding several stream restarts.
enum DuoDeckStreamingPreset: String, CaseIterable, Identifiable {
    case smooth, balanced, crisp
    var id: String { rawValue }

    var title: String {
        switch self {
        case .smooth: "Smooth"
        case .balanced: "Balanced"
        case .crisp: "Crisp"
        }
    }

    var symbol: String {
        switch self {
        case .smooth: "hare"
        case .balanced: "slider.horizontal.3"
        case .crisp: "viewfinder"
        }
    }

    var detail: String {
        switch self {
        case .smooth: "Responsive on busy networks"
        case .balanced: "Everyday work"
        case .crisp: "More detail on fast connections"
        }
    }

    var bitrate: Int {
        switch self {
        case .smooth: QualityPreset.efficient.rawValue
        case .balanced: QualityPreset.balanced.rawValue
        case .crisp: QualityPreset.high.rawValue
        }
    }
    var scale: CGFloat { self == .crisp ? 2 : 1 }
    var prioritizeSpeed: Bool { self == .smooth }

    func matches(_ config: HostConfig) -> Bool {
        config.maxFPS == 60 && config.bitrate == bitrate && config.captureScale == scale
            && config.prioritizeSpeed == prioritizeSpeed
    }

    func applying(to config: HostConfig) -> HostConfig {
        var next = config
        next.maxFPS = 60
        next.bitrate = bitrate
        next.captureScale = scale
        next.prioritizeSpeed = prioritizeSpeed
        return next
    }

    static func current(in config: HostConfig) -> Self? { allCases.first { $0.matches(config) } }
}
