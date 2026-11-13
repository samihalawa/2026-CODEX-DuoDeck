// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DuoDeck",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "StreamProtocol", targets: ["StreamProtocol"]),
        // The CLI keeps the product name DuoDeckHost, so `swift run -c release DuoDeckHost …` and
        // .build/release/DuoDeckHost are what they always were.
        .executable(name: "DuoDeckHost", targets: ["DuoDeckHostCLI"]),
        // DuoDeck.app's executable. Scripts/make-app.sh wraps it into the bundle and signs it.
        .executable(name: "DuoDeckMenuBar", targets: ["DuoDeckMenuBar"]),
        // No product for DuoDeckHostCore: the iOS project links this package and must never see it.
    ],
    targets: [
        .target(name: "StreamProtocol", path: "packages/stream-protocol/Sources/StreamProtocol"),
        // The Mac host itself (capture, encode, network, input, virtual display), shared by the CLI
        // and the menu bar app; they reach it through `package` access. The folder keeps its old
        // name (Sources/DuoDeckHost) so the paths in the docs and the VirtualDisplayProbe symlink to
        // ../DuoDeckHost/VirtualDisplay.swift stay valid.
        .target(name: "DuoDeckHostCore", dependencies: ["StreamProtocol"], path: "apps/macos/Sources/DuoDeckHost"),
        // The command-line host: flags, the run loop, the Terminal permission hint.
        .executableTarget(name: "DuoDeckHostCLI", dependencies: ["DuoDeckHostCore", "StreamProtocol"], path: "apps/macos/Sources/DuoDeckHostCLI"),
        // The menu bar app: status item, Settings and Log windows (AppKit lifecycle, SwiftUI panes).
        .executableTarget(name: "DuoDeckMenuBar", dependencies: ["DuoDeckHostCore", "StreamProtocol"], path: "apps/macos/Sources/DuoDeckMenuBar"),
        // Milestone 3 spike: virtual display + window move + capture. Its VirtualDisplay.swift
        // is a symlink to the host's copy. Not shipped.
        .executableTarget(name: "CaptureProbe", path: "apps/macos/Sources/CaptureProbe"),
        .executableTarget(name: "VirtualDisplayProbe", path: "apps/macos/Sources/VirtualDisplayProbe"),
    ]
)
