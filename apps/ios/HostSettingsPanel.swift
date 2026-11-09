import SwiftUI
import UIKit
import StreamProtocol

/// Native settings for the connected Mac. Everyday choices have their own destinations;
/// detailed streaming and connection controls live under Advanced. Changes still flow
/// through the host settings ledger, so pending values and refusals remain authoritative.
struct HostSettingsPanel: View {
    @ObservedObject var client: StreamClient
    /// Done, Esc or ⌘., and the VoiceOver escape gesture.
    let close: () -> Void
    /// Pair This iPad…: the stream screen puts the panel away and covers the stream with the
    /// pairing overlay.
    var pairThisDevice: () -> Void = {}
    /// Take the Tour: the stream screen puts the panel away and shows the tour of its layout.
    var takeTour: () -> Void = {}

    /// Two seconds on this connection and still no state: the Mac runs a Sill without settings.
    @State private var olderMac = false
    /// Bumped when Low Power Mode toggles, so the frame rate note is read again.
    @State private var powerState = 0
    /// This device's switch for three-finger gestures (docs/trackpad-gestures-plan.md §8): on unless
    /// turned off, read by `StreamClient.sendGesture` at each gesture, never sent.
    @AppStorage(StreamClient.gesturesKey) private var gesturesOn = true
    /// This device's switch for Reverse Scrolling (issue #143): off unless turned on, read by the
    /// picture's input view and the on-screen trackpad as each scroll begins (`ScrollDirection`), never
    /// sent.
    @AppStorage(StreamClient.reverseScrollKey) private var reverseScroll = false
    /// This device's switch for Larger Picture (docs/larger-picture-plan.md): off unless turned on,
    /// read by the stream screen, never sent.
    @AppStorage(StreamClient.largerPictureKey) private var largerPicture = false
    /// Whether the switch is offered here, the stream screen's say (`largerPictureOffered`): only on an
    /// iPhone without a hinge whose picture it makes larger.
    @Environment(\.largerPictureOffered) private var offersLargerPicture
    /// This device's switch for the clipboard (docs/clipboard-plan.md): on unless turned off, read by
    /// StreamClient+Clipboard at each decision; a change subscribes or stops at once.
    @AppStorage(StreamClient.clipboardKey) private var clipboardOn = true
    /// This device's hold before a thumbnail's lights (issue #113, ThumbnailHold): 0.5 s unless changed,
    /// read by every bar's thumbnails at once, never sent. Read for its changes; the length through
    /// `ThumbnailHold.seconds(stored:)`, which takes `-Sill.thumbnailHold 0.3`'s string too.
    @AppStorage(ThumbnailHold.key) private var storedThumbnailHold = ThumbnailHold.standard
    private var thumbnailHold: Double {
        _ = storedThumbnailHold
        return ThumbnailHold.seconds(stored: UserDefaults.standard.object(forKey: ThumbnailHold.key))
    }
    /// Paste on ‹Mac› Right Away (paste right away, ClipboardPolicy.pastesOnReceipt): on unless turned
    /// off, read by StreamClient+Clipboard at each receipt, never sent.
    @AppStorage(StreamClient.pasteRightAwayKey) private var pasteRightAway = true
    /// VoiceOver is on: it keeps three-finger swipes and taps for itself, so the This iPad group says
    /// its rows do the gestures instead.
    @State private var voiceOver = HostSettingsPanel.voiceOverRunning

    private var mac: String { client.macName.isEmpty ? "the Mac" : client.macName }
    private static let gesturesGroupID = "thisDevice"
    private static let sendAudioID = "sendAudio"
    private static let muteID = "mute"
    private static let reverseScrollRowID = "reverseScroll"
    private static let thumbnailHoldRowID = "thumbnailHold"
    private static let clipboardRowsID = "clipboardPaste"
    /// `UIAccessibility.isVoiceOverRunning`; DEBUG `-SillVoiceOver 1` says it is, for the harness's
    /// photos of the group's VoiceOver footnote.
    static var voiceOverRunning: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "SillVoiceOver") { return true }
        #endif
        return UIAccessibility.isVoiceOverRunning
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Connected to", value: mac)
                    if let why = client.lockWhy {
                        Text(LockedMac.line(mac: client.macName, why: why))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if let problem = client.settingsProblem {
                    Section { Label(problem, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                }
                Section {
                    NavigationLink {
                        DuoDeckControlsSettings(standalone: false)
                    } label: {
                        Label("Trackpad", systemImage: "rectangle.and.hand.point.up.left")
                    }
                    NavigationLink {
                        displaySettings
                    } label: {
                        Label("Display & sound", systemImage: "display")
                    }
                    NavigationLink {
                        connectionSettings
                    } label: {
                        Label("Connection", systemImage: "network")
                    }
                    NavigationLink {
                        helpSettings
                    } label: {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                }
                Section {
                    NavigationLink {
                        advancedSettings
                    } label: {
                        Label("Advanced", systemImage: "slider.horizontal.3")
                    }
                }
                Section {
                    Button(role: .destructive) { client.disconnect() } label: {
                        Label("Disconnect", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .accessibilityLabel("Disconnect from \(mac)")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: close).keyboardShortcut(.cancelAction)
                }
            }
        }
        .tint(Palette.accent)
        .accessibilityAction(.escape, close)
        .background(EscapeKey(action: close))
        .sensoryFeedback(.warning, trigger: client.settingsRefusals)
        .onChange(of: client.settingsRefusals) { _, _ in
            AccessibilityNotification.Announcement("\(mac) kept its setting").post()
        }
        .onChange(of: client.settingsProblem) { _, problem in
            if let problem { AccessibilityNotification.Announcement(problem).post() }
        }
        .task(id: client.connectedAt) {
            olderMac = false
            let elapsed = client.connectedAt.map { Date().timeIntervalSince($0) } ?? 0
            if elapsed < 2 { try? await Task.sleep(for: .seconds(2 - elapsed)) }
            if !Task.isCancelled { olderMac = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange).receive(on: RunLoop.main)) { _ in
            powerState += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification).receive(on: RunLoop.main)) { _ in
            voiceOver = Self.voiceOverRunning
        }
    }

    private var displaySettings: some View {
        Form {
            if let state = client.settings.host, let shown = client.settings.displayed {
                Section {
                    Picker("Picture quality", selection: Binding(get: { presetName(shown) }, set: applyPreset)) {
                        Text("Smooth").tag("smooth")
                        Text("Balanced").tag("balanced")
                        Text("Crisp").tag("crisp")
                        if presetName(shown) == "custom" { Text("Custom").tag("custom") }
                    }
                    .pickerStyle(.menu)
                    if offersLargerPicture {
                        Toggle("Larger picture", isOn: $largerPicture)
                    }
                } footer: {
                    Text("Smooth uses less bandwidth. Crisp shows more text detail."
                         + (offersLargerPicture ? " Larger picture hides window thumbnails while a window streams. Use Apps to switch windows; the layout changes when Settings closes." : ""))
                }
                Section {
                    let send = shown.sendAudio
                    Toggle(isOn: binding(send ?? false) { HostSettingsChange(sendAudio: $0) }) {
                        HStack {
                            Text("Send audio")
                            BetaTag()
                            PendingSpinner(since: client.settings.pendingSince(.sendAudio))
                        }
                    }
                    .disabled(send == nil)
                    .accessibilityLabel("Send audio, beta")
                    .id(Self.sendAudioID)
                    if client.macHasSound {
                        Toggle("Mute on this \(device)", isOn: Binding(
                            get: { client.soundMuted }, set: { client.setSoundMuted($0) }))
                            .id(Self.muteID)
                    }
                    if send == true, let note = state.audioNote {
                        Text(note).font(.footnote).foregroundStyle(.orange)
                    }
                } header: {
                    Text("Sound")
                } footer: {
                    Text(Self.sendAudioFooter(shown.sendAudio, muted: client.soundMuted, mac: mac, device: device))
                }
                if state.softwareEncoder {
                    Section {
                        Text("\(mac)’s hardware encoder is busy or not responding. Streaming is limited to 60 fps at Standard resolution for now.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if let callout = AwayCopy.callout(link: state.link, away: state.away, mac: mac) {
                    Section {
                        Text(callout.text).font(.subheadline)
                        if let action = callout.button {
                            Button(action.title) { client.changeSettings(action.change) }
                                .accessibilityLabel(action.spoken)
                        }
                    }
                }
            } else {
                settingsAvailability
            }
        }
        .navigationTitle("Display & sound")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func presetName(_ shown: StreamSettings) -> String {
        guard shown.maxFPS == 60 else { return "custom" }
        if shown.bitrate == QualityPreset.efficient.rawValue && shown.captureScale == 1 && shown.prioritizeSpeed { return "smooth" }
        if shown.bitrate == QualityPreset.balanced.rawValue && shown.captureScale == 1 && !shown.prioritizeSpeed { return "balanced" }
        if shown.bitrate == QualityPreset.high.rawValue && shown.captureScale == 2 && !shown.prioritizeSpeed { return "crisp" }
        return "custom"
    }

    private func applyPreset(_ name: String) {
        let bitrate: Int
        let scale: Double
        let speed: Bool
        switch name {
        case "smooth": bitrate = QualityPreset.efficient.rawValue; scale = 1; speed = true
        case "balanced": bitrate = QualityPreset.balanced.rawValue; scale = 1; speed = false
        case "crisp": bitrate = QualityPreset.high.rawValue; scale = 2; speed = false
        default: return
        }
        client.changeSettings(HostSettingsChange(maxFPS: 60, bitrate: bitrate, captureScale: scale, prioritizeSpeed: speed))
    }

    private var connectionSettings: some View {
        Form {
            Section {
                LabeledContent("Mac", value: mac)
                LabeledContent("Connection", value: remoteRoute.map { $0.phrase } ?? client.route?.word ?? "Connected")
            }
            awayFromHome
            clipboardSettings
        }
        .navigationTitle("Connection")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var helpSettings: some View {
        Form {
            Section {
                NavigationLink {
                    DuoDeckGestureGuide()
                } label: {
                    Label("Gestures & controls", systemImage: "hand.draw")
                }
                Button(action: takeTour) {
                    Label("Show me around", systemImage: "play.circle")
                }
                .accessibilityHint(TourPolicy.takeTourHint(device: device))
            }
            Section {
                Link("Get DuoDeck for Mac", destination: SillLinks.download)
                Link("Support", destination: SillLinks.support)
                Link("Privacy policy", destination: SillLinks.privacy)
            }
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var advancedSettings: some View {
        Form {
            Section {
                NavigationLink {
                    Form { streamingDetails }
                        .navigationTitle("Streaming")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Streaming", systemImage: "video")
                }
                NavigationLink {
                    Form { connectionDetails }
                        .navigationTitle("Connection details")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Connection details", systemImage: "waveform.path")
                }
                NavigationLink {
                    Form { thisDevice }
                        .navigationTitle("Keyboard & gestures")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Keyboard & gestures", systemImage: "keyboard")
                }
            } footer: {
                Text("Streaming changes apply to every device connected to \(mac).")
            }
        }
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var streamingDetails: some View {
        if let state = client.settings.host, let shown = client.settings.displayed {
            Section {
                Picker("Bandwidth", selection: binding(shown.bitrate) { HostSettingsChange(bitrate: $0) }) {
                    ForEach(QualityPreset.allCases) { Text($0.title).tag($0.rawValue) }
                    if QualityPreset(rawValue: shown.bitrate) == nil {
                        Text(QualityPreset.title(forBitrate: shown.bitrate)).tag(shown.bitrate)
                    }
                }
                Picker("Resolution", selection: binding(shown.captureScale) { HostSettingsChange(captureScale: $0) }) {
                    Text("Standard").tag(1.0)
                    Text("Retina").tag(2.0)
                }
                Picker("Frame rate", selection: binding(shown.maxFPS) { HostSettingsChange(maxFPS: $0) }) {
                    Text("60 fps").tag(60)
                    Text("120 fps").tag(120)
                    if shown.maxFPS != 60 && shown.maxFPS != 120 { Text("\(shown.maxFPS) fps").tag(shown.maxFPS) }
                }
            } footer: {
                Text(streamFooter)
            }
            Section {
                Toggle(isOn: binding(shown.prioritizeSpeed) { HostSettingsChange(prioritizeSpeed: $0) }) {
                    RowTitle(title: "Prioritize encoding speed", since: client.settings.pendingSince(.prioritizeSpeed))
                }
            } footer: {
                Text("Reduce latency when the Mac is busy, with a softer picture.")
            }
            Section {
                Toggle(isOn: binding(shown.virtualDisplay) { HostSettingsChange(virtualDisplay: $0) }) {
                    RowTitle(title: "Virtual display", since: client.settings.pendingSince(.virtualDisplay))
                }
                .disabled(!state.virtualDisplayAvailable && !shown.virtualDisplay)
                .accessibilityHint(state.virtualDisplayNote ?? "")
            } footer: {
                Text(state.virtualDisplayNote ?? "Keeps the selected window updating when other windows cover it on your Mac. Changing this briefly restarts the stream.")
            }
            if let note = AwayCopy.footnote(state.away, mac: mac, remoteAccessOn: client.macInfo?.remoteAccess == true) {
                Section { Text(note).font(.footnote).foregroundStyle(.secondary) }
            }
            if let problem = client.settingsProblem {
                Section { Text(problem).foregroundStyle(.orange) }
            }
        } else {
            settingsAvailability
        }
    }

    @ViewBuilder private var connectionDetails: some View {
        if let state = client.settings.host, let shown = client.settings.displayed {
            if let direct = shown.directWireless {
                let locked = Self.directWirelessLock(remote: remoteRoute != nil, takes: state.takesDirectWireless, mac: mac)
                Section {
                    Toggle(isOn: binding(direct) { HostSettingsChange(directWireless: $0) }) {
                        RowTitle(title: "Direct Wireless Connection", since: client.settings.pendingSince(.directWireless))
                    }
                    .disabled(locked != nil)
                    .accessibilityHint(locked == nil && client.connectedDirectly && direct ? "Turning this off disconnects this \(device)." : "")
                } footer: {
                    Text(locked ?? directFooter(on: direct))
                }
            }
            Section("Diagnostics") {
                if let stream = state.stream {
                    Text(Self.readout(stream, route: client.route))
                        .font(.subheadline).monospacedDigit()
                        .accessibilityLabel(Self.spokenReadout(stream, route: client.route, remote: remoteRoute))
                } else {
                    Text("No active stream").foregroundStyle(.secondary)
                }
                if remoteRoute != nil {
                    LabeledContent("Round trip", value: Self.rttText(client.linkStats))
                }
                if !state.persistent {
                    Text("The command-line host keeps these settings until it quits.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        } else {
            settingsAvailability
        }
    }

    @ViewBuilder private var settingsAvailability: some View {
        Section {
            if olderMac {
                Label("Update DuoDeck on \(mac) to change its settings here.", systemImage: "arrow.down.circle")
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading settings…").foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Shows the value the panel displays; moving the control sends that one field. Nothing else
    /// ever sends (not `onChange(of:)`, not a state arriving).
    private func binding<V>(_ value: V, _ change: @escaping (V) -> HostSettingsChange) -> Binding<V> {
        Binding(get: { value }, set: { client.changeSettings(change($0)) })
    }

    // MARK: Away from home

    /// This connection's way in from afar, when it is one.
    private var remoteRoute: RemoteRoute? { client.remoteRoute }

    /// The Mac's last group (docs/remote-access-plan.md §7.11, docs/home-pairing-plan.md §7.6):
    /// whether this device is paired with the Mac and can reach it away from home, from the Mac's
    /// kind 18 (DiscoveryPolicy.awayFromHome). "Paired" for a saved Mac, however it paired; Pair This
    /// iPad… only in an unpaired session: at home over TLS on a Mac that lets any device in (it pairs
    /// at this session's own door, Remote Access on or not), or over a plain door with Remote Access
    /// on (through the remote door, as before). None from an older Mac (no kind 18 on this
    /// connection).
    @ViewBuilder private var awayFromHome: some View {
        if let info = client.macInfo {
            Section("Pairing") {
                switch DiscoveryPolicy.awayFromHome(saved: client.macInfoSaved, remoteSession: remoteRoute != nil,
                                                    remoteAccess: info.remoteAccess, tlsAtHome: client.sessionAtHomeOverTLS) {
                case .paired(let reach):
                    Label("Paired", systemImage: "checkmark.circle")
                    switch reach {
                    case .connected:
                        if let r = remoteRoute { Text("Connected \(r.phrase).").font(.subheadline).foregroundStyle(.secondary) }
                    case .reaches:
                        Text("Away from home, DuoDeck reaches \(mac) \(Self.reach(info)).")
                            .font(.subheadline).foregroundStyle(.secondary)
                    case .turnOnRemoteAccess:
                        Text(Self.turnOnRemoteAccess(mac)).font(.subheadline).foregroundStyle(.secondary)
                    }
                case .pairThisDevice(let atHome):
                    Button("Pair this \(device)…", action: pairThisDevice)
                    Text(atHome ? DiscoveryPolicy.HomeCopy.pairThisDeviceAtHome(mac: mac, device: device)
                                : "Pair once to reach \(mac) through your VPN or the internet. Scan or enter the code shown on your Mac.")
                        .font(.subheadline).foregroundStyle(.secondary)
                case .turnOnRemoteAccess:
                    Text(Self.turnOnRemoteAccess(mac)).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// With Remote Access off on the Mac: how to reach it away from home.
    static func turnOnRemoteAccess(_ mac: String) -> String {
        "To reach \(mac) away from home, turn on Remote Access in DuoDeck Host settings on the Mac."
    }

    // MARK: This device

    /// This device's own group, after the Mac's: on an iPhone its switch for Larger Picture, then Share Clipboard while the Mac shares its clipboard,
    /// with Paste on ‹Mac› (the system's Paste control) under it while on, then Reverse Scrolling (for
    /// every Mac: it only turns this device's own deltas around), then how long a thumbnail is held for
    /// its window's lights (for every Mac: the thumbnails are this device's), then its switch for three-finger
    /// with Paste on ‹Mac› Right Away (whether a Paste also presses ⌘V there) and Paste on ‹Mac› (the
    /// system's Paste control) under it while on, then Reverse Scrolling (for
    /// every Mac: it only turns this device's own deltas around), then its switch for three-finger
    /// gestures, and what each does when the Mac takes them (Take the Tour follows it). After the Mac's
    /// rows because it is the least changed, and the compact halves' 259 pt show the Mac's rows first.
    /// The switches reach nothing on the Mac but the clipboard's, which subscribes or stops; a gesture
    /// row, activated by VoiceOver, Voice Control or Switch Control, does its gesture on the Mac as three
    /// fingers would (`sendGesture`: the switch, the Mac's `gestures`, the Desktop first while a window
    /// streams).
    @ViewBuilder private var clipboardSettings: some View {
        if ClipboardPolicy.hostTakes(client.hostClipboard) {
            Section {
                Toggle(ClipboardPolicy.Copy.switchTitle, isOn: $clipboardOn)
                    .onChange(of: clipboardOn) { _, _ in client.clipboardSwitchChanged() }
                if clipboardOn {
                    Toggle(ClipboardPolicy.Copy.rightAwayTitle(mac: mac), isOn: $pasteRightAway)
                    ClipboardPasteRow(client: client, title: ClipboardPolicy.Copy.rowTitle(mac: mac))
                        .id(Self.clipboardRowsID)
                    if let note = client.clipboardNote {
                        Text(note.text).font(.footnote)
                            .foregroundStyle(note.warning ? Color.orange : Palette.muted)
                            .accessibilityHidden(true)
                    }
                }
            } header: {
                Text("Clipboard")
            } footer: {
                Text(ClipboardPolicy.Copy.footnote(on: clipboardOn, rightAway: pasteRightAway, mac: mac, device: device))
            }
        }
    }

    @ViewBuilder private var thisDevice: some View {
        Section {
            Toggle("Reverse scrolling", isOn: $reverseScroll)
                .id(Self.reverseScrollRowID)
        } footer: {
            Text(Self.reverseScrollFooter(device: device))
        }
        Section {
            ThumbnailHoldRow(seconds: thumbnailHold) { storedThumbnailHold = $0 }
                .id(Self.thumbnailHoldRowID)
        } footer: {
            Text(ThumbnailHold.footnote)
        }
        Section {
            Toggle("Three-finger gestures", isOn: $gesturesOn)
            if gesturesOn, macTakesGestures {
                ForEach(Self.gestureRows, id: \.gesture) { row in
                    GestureRow(symbol: row.symbol, gesture: row.gesture, action: row.action, does: row.does) {
                        _ = client.sendGesture($0, fingers: 3)
                    }
                }
            }
        } footer: {
            Text(gesturesFooter)
        }
        .id(Self.gesturesGroupID)
    }

    /// Under Send Audio's switch and the Mute row below it (docs/audio-plan.md §7.7): on, that every
    /// device hears it and that Mute silences this one alone; off, what turning it on does, and Mute
    /// the same; either way, that this device is muted while it is; for a Mac without sound (nil), what
    /// to update (no Mute row then). Each starts with "Beta.".
    static func sendAudioFooter(_ send: Bool?, muted: Bool, mac: String, device: String) -> String {
        let mute = " Mute silences it on this \(device) alone; \(mac) keeps sending and playing it."
            + (muted ? " This \(device) is muted." : "")
        switch send {
        case true?:
            return "Beta. Every connected device hears what streams, and \(mac) keeps playing it too." + mute
        case false?:
            return "Beta. Turn this on to hear what streams on every connected device; \(mac) keeps playing it too." + mute
        case nil:
            return "Beta. Update DuoDeck Host on \(mac) to hear its sound on this \(device)."
        }
    }

    /// Under Reverse Scrolling's switch: what it turns around, a finger's drag over the picture and two
    /// fingers on the on-screen trackpad, their coast too (`ScrollDirection`); and, on an iPad, that a
    /// trackpad or mouse connected to it keeps the direction iPadOS's own Natural Scrolling gives it
    /// (with the trackpad's and the mouse's settings, under Settings › General), which the switch
    /// leaves alone.
    static func reverseScrollFooter(device: String) -> String {
        "Turns a finger’s drag and the trackpad’s two-finger scroll around."
            + (device == "iPad" ? " A trackpad or mouse connected to the iPad follows its own Natural Scrolling setting." : "")
    }

    /// The Mac's window list said it takes the gestures (`WindowList.gestures`).
    private var macTakesGestures: Bool { (client.hostGestures ?? 0) >= TrackpadGesture.generation }

    /// Under Larger Picture's switch: that it is a window's picture (the Desktop, which Aa never
    /// resizes, keeps the thumbnails: `PhonePortraitLayout.largerPicture(switchOn:streaming:)`), what
    /// it gives up, where windows come from instead, that the Mac fits a window to the taller picture
    /// once Aa sets its text size (or on the virtual display), and that a change applies as the panel
    /// closes (StreamScreen's `largerPictureHeld`).
    static let largerPictureFooter = "Held upright, a window’s picture takes the place of the window thumbnails and reaches down to where the keyboard comes up. The Desktop keeps the thumbnails. Switch windows with Apps: choose an app, then choose its window. To fill the taller picture with a window, set its text size with Aa. A change applies when you close Settings."

    /// What each gesture does on the Mac, and what the row does as an accessibility action: its one
    /// gesture, or, for the Spaces, one action each way (natural direction: a swipe left brings the
    /// Space on the right). The pinch opens Launchpad on macOS 14 and 15, from the same key.
    private static let gestureRows: [(symbol: String, gesture: String, action: String, does: [GestureRow.Action])] = [
        ("arrow.up", "Swipe Up", "Mission Control", [GestureRow.Action(name: "Mission Control", gesture: .swipeUp)]),
        ("arrow.down", "Swipe Down", "App Exposé", [GestureRow.Action(name: "App Exposé", gesture: .swipeDown)]),
        ("arrow.left.and.right", "Swipe Left or Right", "Spaces", [GestureRow.Action(name: "Space on the Right", gesture: .swipeLeft),
                                                                   GestureRow.Action(name: "Space on the Left", gesture: .swipeRight)]),
        ("arrow.down.right.and.arrow.up.left", "Pinch", "Apps", [GestureRow.Action(name: "Apps", gesture: .pinch)]),
        ("arrow.up.left.and.arrow.down.right", "Spread", "Show Desktop", [GestureRow.Action(name: "Show Desktop", gesture: .spread)]),
    ]

    /// Under the switch: where the gestures go and what they do, or why nothing happens.
    private var gesturesFooter: String {
        guard gesturesOn else { return "Three-finger strokes do nothing while this is off." }
        guard macTakesGestures else { return "Update DuoDeck Host on \(mac) to use these." }
        // VoiceOver keeps three-finger swipes and taps for itself, and no touch of them reaches Sill.
        var text = voiceOver ? "VoiceOver keeps three-finger gestures for itself, so the rows above do them on \(mac) instead."
            : "Three fingers on the trackpad or over the stream."
        text += " While a window streams, a gesture shows the Desktop first, and the opposite gesture closes what one opened. \(mac) does these with its own keyboard shortcuts: one turned off in its Keyboard settings does nothing."
        if device == "iPad" { text += " Four-finger swipes and a Magic Keyboard trackpad’s gestures stay with iPadOS." }
        return text
    }

    /// "through Tailscale (mac-mini.tail1234.ts.net)": the first VPN or internet address the Mac
    /// gave; otherwise "through your VPN or the internet".
    static func reach(_ info: MacInfo) -> String {
        guard let a = info.addresses.first(where: { $0.kind == MacAddress.vpn || $0.kind == MacAddress.internet }) else {
            return "through your VPN or the internet"
        }
        if a.kind == MacAddress.internet { return "over the internet (\(a.host))" }
        let name = a.via.isEmpty || a.via.hasPrefix("VPN (") ? "your VPN" : a.via
        return "through \(name) (\(a.host))"
    }

    // MARK: Copy

    /// Under the Mac's name: what actually runs, which confirms a change took effect and shows
    /// what the software encoder caps, then how this device's connection reaches the Mac
    /// ("… · 15 Mbps · Wi-Fi"; StreamClient.route), when its path says (never on a remote session:
    /// its route line says how instead). Whether it runs on the virtual display is a line of its
    /// own (see `header`). A no-break space before each "·" keeps it with the value before it, so a
    /// wrap at larger text never starts a line with one.
    static func readout(_ stream: RunningStream?, route: DiscoveryPolicy.Method? = nil) -> String {
        let values = stream.map { ["\($0.width)×\($0.height)", "\($0.fps)\u{00A0}fps", "\($0.mbps)\u{00A0}Mbps"] } ?? ["Not streaming"]
        return (values + [route?.word].compactMap { $0 }).joined(separator: "\u{00A0}· ")
    }

    /// "48 ms", the last second's median round trip; "–" for a second without a pong.
    static func rttText(_ stats: StreamClient.LinkStats?) -> String {
        stats?.rtt.map { "\($0.median)\u{00A0}ms" } ?? "–"
    }

    /// The readout as VoiceOver says it, ending in how this device reaches the Mac: its link, or
    /// from afar the remote route with the round trip, which wins (a remote session has no link
    /// word; see `header`).
    static func spokenReadout(_ stream: RunningStream?, route: DiscoveryPolicy.Method? = nil, remote: RemoteRoute? = nil,
                              rttMs: Int? = nil) -> String {
        var link = route.map { ", " + spoken($0) } ?? ""
        if let remote {
            link = ", connected \(remote.phrase)" + (rttMs.map { ", \($0) millisecond round trip" } ?? "")
        }
        guard let s = stream else { return "Not streaming" + link }
        return "Streaming \(s.width) by \(s.height), \(s.fps) frames per second, \(s.mbps) megabits per second"
            + (s.onVirtualDisplay ? ", on the virtual display" : "") + link
    }

    /// The route as VoiceOver says it: a sentence's end rather than the bare word.
    private static func spoken(_ route: DiscoveryPolicy.Method) -> String {
        switch route {
        case .wired: return "connected by cable"
        case .wifi: return "connected over Wi-Fi"
        case .direct: return "connected directly"
        }
    }

    /// "iPhone" or "iPad", for copy about this device.
    private var device: String { UIDevice.current.userInterfaceIdiom == .phone ? "iPhone" : "iPad" }

    /// Why the Direct Wireless Connection switch is disabled, as its footnote says it, or nil while
    /// this device may change it: away from home (`remote`) the Mac refuses it from a remote
    /// connection, and on a session it says is not paired (`takes` false:
    /// `HostSettingsState.takesDirectWireless`) from any device it did not pair.
    static func directWirelessLock(remote: Bool, takes: Bool, mac: String) -> String? {
        if remote { return "Change this on \(mac), or from a device near it." }
        if !takes { return "Change this on \(mac), or from a device paired with it." }
        return nil
    }

    /// Under the Direct Wireless Connection row: what it does and costs, and, while the switch shows
    /// on and this device is connected over it, what turning it off does to this device: the Mac
    /// disconnects every device on peer-to-peer Wi-Fi once its listener has changed (1.5 s), and a
    /// device still connected directly shares no network the Mac is listed on (one that does moves
    /// to it by itself), so it cannot come back until it does. Once the switch shows off (turned
    /// off here or on the Mac, with this connection still up for that moment) the warning is moot.
    private func directFooter(on: Bool) -> String {
        var text = "Lets devices reach \(mac) without a shared Wi\u{2011}Fi network, the way AirDrop does. While it’s on, streaming over Wi\u{2011}Fi can stutter."
        if on, client.connectedDirectly { text += " This \(device) is connected directly: turning this off disconnects it." }
        return text
    }

    /// Under the stream rows: what Quality counts and what its top presets need (the Mac's
    /// Settings › Streaming says the same). A frame rate limit above what this screen shows changes
    /// nothing for it, which is worth saying on a 60 Hz device; away from home this device asks
    /// for 60 fps.
    private var streamFooter: String {
        _ = powerState
        var text = "Quality is per 60 fps; a 120 fps stream gets twice as much. " + QualityPreset.fastLinkNote
        let away = client.awayCapsFrameRate
        let wanted = StreamClient.wantedFPS(remote: away)
        guard wanted < 120 else { return text }
        if away, StreamClient.wantedFPS() > wanted {
            text += " Away from home, this \(device) asks for \(wanted) fps, which halves the data your Mac sends."
        } else if ProcessInfo.processInfo.isLowPowerModeEnabled, StreamClient.screenMaximumFPS() >= 120 {
            text += " Low Power Mode holds this \(device) to \(wanted) fps."
        } else {
            text += " This \(device) shows up to \(wanted) fps."
        }
        return text
    }
}

// MARK: - Rows

/// "Beta" after a row's title, for a feature still being tried (Send Audio): small, muted, in a thin
/// capsule, and grows with the text. Hidden from VoiceOver: the row's label says "beta".
private struct BetaTag: View {
    var body: some View {
        Text("Beta")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Palette.muted)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Capsule().strokeBorder(Palette.muted.opacity(0.6), lineWidth: 1))
            .fixedSize()
            .accessibilityHidden(true)
    }
}

/// A row's title with the pending spinner beside it.
private struct RowTitle: View {
    let title: String
    let since: Double?
    var body: some View {
        HStack(spacing: 6) {
            Text(title).foregroundStyle(Palette.text)
            PendingSpinner(since: since)
        }
    }
}

/// One gesture and what it does on the Mac: the words side by side when they fit and stacked when
/// larger text leaves no room, never cut off; one VoiceOver element ("Swipe Up, Mission Control").
/// A touch does nothing here; activated by VoiceOver, Voice Control or Switch Control (which cannot
/// make three-finger strokes, or keep them) it does its gesture: a button for one, a named action
/// each way for the Spaces.
private struct GestureRow: View {
    struct Action { let name: String; let gesture: TrackpadGestures.Gesture }
    let symbol: String
    let gesture: String
    let action: String
    let does: [Action]
    let perform: (TrackpadGestures.Gesture) -> Void
    /// Measured afresh when the text size changes, as `AdaptiveRow` is.
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        if let only = does.first, does.count == 1 {
            row.accessibilityAddTraits(.isButton).accessibilityAction { perform(only.gesture) }
        } else {
            row.accessibilityActions {
                ForEach(does, id: \.name) { item in Button(item.name) { perform(item.gesture) } }
            }
        }
    }
    private var row: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                icon
                Text(gesture).foregroundStyle(Palette.text)
                Spacer(minLength: 8)
                Text(action).foregroundStyle(Palette.muted)
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                icon
                VStack(alignment: .leading, spacing: 2) {
                    Text(gesture).foregroundStyle(Palette.text)
                    Text(action).foregroundStyle(Palette.muted)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
        }
        .id(typeSize)
        .rowFrame()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(gesture), \(action)")
    }
    private var icon: some View {
        Image(systemName: symbol)
            .foregroundStyle(Palette.muted)
            .frame(width: 24)
            .accessibilityHidden(true)
    }
}

/// Hold to Show Window Controls (issue #113; ThumbnailHold): the title, the length beside it ("0.5 s")
/// and the system's stepper, − and + a tenth of a second a press from 0.2 to 2 s (the capsule on iOS 26
/// and later), counting whole tenths so no sum of presses drifts off the grid. The title wraps beside the
/// stepper, as a switch's does, rather than the row stacking: in a panel 340 or 360 pt wide it never fits
/// on one line beside the value and the stepper (two lines there, three at the larger text sizes). It stays
/// beside them only while it has room for three lines with every word whole (`ThumbnailHold.titleLines`):
/// in a narrower panel (a 320 pt iPhone with Display Zoom, an iPad window as narrow as Slide Over) the row
/// stacks, the title over the length and the stepper, as `AdaptiveRow` does; beside them it ran to four
/// lines there, and at the larger text sizes to seven, "Win-dow" and "Con-trols" broken (the review,
/// 2026-10-29).
///
/// For VoiceOver one adjustable element: "Hold to show window controls, 0.5 seconds", a swipe up or down a
/// tenth (`ThumbnailHold.adjusted`). The system's stepper on iOS 27 is two buttons instead, each read with
/// the whole label and the visible "0.5 s" ("…, 0.5 s, Hold to show window controls, Decrement"), which
/// says neither the value in words nor what the row is.
private struct ThumbnailHoldRow: View {
    let seconds: Double
    let set: (Double) -> Void
    /// Measured afresh when the text size changes, as `AdaptiveRow` is.
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        ViewThatFits(in: .horizontal) {
            stepper {
                HStack(spacing: 8) {
                    WrappingTitle {
                        // Never shown: what the title must have room for beside the stepper.
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(ThumbnailHold.titleLines, id: \.self) { Text($0) }
                        }
                        .hidden()
                        title
                    }
                    Spacer(minLength: 8)
                    value
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                title.fixedSize(horizontal: false, vertical: true)
                stepper { value }
            }
            .padding(.vertical, 8)
        }
        .id(typeSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ThumbnailHold.spokenTitle)
        .accessibilityValue(ThumbnailHold.spokenValue(seconds))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: set(ThumbnailHold.adjusted(seconds, up: true))
            case .decrement: set(ThumbnailHold.adjusted(seconds, up: false))
            @unknown default: break
            }
        }
        .padding(.vertical, 4)
        // Never wider than the panel offers it. At the edge of fitting the title beside the stepper, its lines'
        // widths, rounded to the pixel, can come to a third of a point more than the row was offered (the Duo's
        // cover upright at xxLarge: 298.333 pt in 298), and `rowFrame`'s frame, a maximum alone, passes that on:
        // every row of the panel grew by it and the panel's edge moved a pixel past main's (the review,
        // 2026-10-29). With a minimum too, the frame takes what it is offered, whatever the row asks.
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .rowFrame()
    }

    private var title: some View { Text(ThumbnailHold.title).foregroundStyle(Palette.text) }

    private var value: some View {
        Text(ThumbnailHold.valueText(seconds))
            .monospacedDigit()
            .foregroundStyle(Palette.muted)
            .fixedSize()
    }

    /// The system's stepper over whole tenths, with its label beside it.
    private func stepper<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        Stepper(value: Binding(get: { ThumbnailHold.tenths(seconds) }, set: { set(ThumbnailHold.seconds(tenths: $0)) }),
                in: ThumbnailHold.tenthsRange, label: label)
    }
}

/// A title that wraps in the width it is given, as a Text does (the second view), but whose ideal width,
/// which `ViewThatFits` measures a row by, is the first view's (never shown): the narrowest it may be.
private struct WrappingTitle: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        guard let width = proposal.width else {
            let floor = subviews[0].sizeThatFits(.unspecified).width
            return CGSize(width: floor, height: subviews[1].sizeThatFits(ProposedViewSize(width: floor, height: nil)).height)
        }
        return subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        subviews[0].place(at: bounds.origin, proposal: .zero)
        subviews[1].place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}

/// "Paste on ‹Mac›" with the system's Paste button (ClipboardPasteButton): beside it when they fit,
/// under it when larger text leaves no room, as `AdaptiveRow` does. The title is the row's words for
/// VoiceOver; the button reads "Paste" with its hint.
private struct ClipboardPasteRow: View {
    @ObservedObject var client: StreamClient
    let title: String
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                Text(title).foregroundStyle(Palette.text)
                Spacer(minLength: 8)
                ClipboardPasteButton(client: client)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(title).foregroundStyle(Palette.text).fixedSize(horizontal: false, vertical: true)
                ClipboardPasteButton(client: client)
            }
            .padding(.vertical, 8)
        }
        .id(typeSize)
        .rowFrame()
    }
}

/// A hairline between rows, inset like the system's.
/// Shows when the host has not yet acknowledged a setting change.
private struct PendingSpinner: View {
    let since: Double?
    @State private var shown = false
    var body: some View {
        ZStack {
            if shown { ProgressView().controlSize(.small).tint(Palette.muted) }
        }
        .frame(width: shown ? nil : 0)
        .accessibilityHidden(true)
        .task(id: since) {
            shown = false
            guard let since else { return }
            let wait = 0.3 - (ProcessInfo.processInfo.systemUptime - since)
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            if !Task.isCancelled { shown = true }
        }
    }
}

/// A group's footer: small, muted, from the leading edge; orange with a warning sign for a problem.
/// `top` 0 continues the footer above it.
private extension View {
    /// A row inside a group: at least 44 pt tall, inset 14 pt.
    func rowFrame() -> some View {
        frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.horizontal, 14)
    }
}

/// Whether the Settings panel offers Larger Picture (This iPhone's first switch, or its second after
/// Mute while the Mac has sound): the stream screen's say, true on an iPhone without a hinge whose
/// picture Larger Picture makes larger (`PhonePortraitLayout.offersLargerPicture`); false everywhere
/// else, the iPhone Duo and an iPad included, and on an iPhone that Display Zoom makes 320 pt wide.
private struct LargerPictureOfferedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var largerPictureOffered: Bool {
        get { self[LargerPictureOfferedKey.self] }
        set { self[LargerPictureOfferedKey.self] = newValue }
    }
}
