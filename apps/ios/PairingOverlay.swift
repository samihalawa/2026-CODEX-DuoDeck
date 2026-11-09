import SwiftUI
import StreamProtocol

/// Pair This iPad… (docs/remote-access-plan.md §7.7, §7.10): over the stream while this device is
/// connected at home, in the view hierarchy (never a presentation, which the Duo harness could not
/// hold and which could cross the crease). Opening it asks the Mac to show its code (kind 21); the
/// scanner reads it, or the code is typed (the address comes from this connection's kind 18). A
/// pairing here never moves the session: the pairing connection closes and the home session goes
/// on. Also where an outside sill://pair link is confirmed while connected, and its pairing then
/// runs to its end.
struct PairingOverlay: View {
    @ObservedObject var client: StreamClient
    let scannerMode: CodeScanner.Mode
    let close: () -> Void
    @State private var typed: Bool
    @State private var code = ""
    @State private var asked = false
    /// An outside link confirmed here: the name of its Mac, whose pairing this overlay now shows.
    @State private var linkName: String?
    @FocusState private var codeFocused: Bool
    @AccessibilityFocusState private var titleFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The Duo's fold across the stream screen (StreamScreen, iOS 27.1): the overlay keeps off it.
    @Environment(\.duoFold) private var duoFold

    init(client: StreamClient, scannerMode: CodeScanner.Mode, typed: Bool = false, close: @escaping () -> Void) {
        self.client = client
        self.scannerMode = scannerMode
        self.close = close
        _typed = State(initialValue: typed || (scannerMode == .live && !CodeScanner.isSupported))
    }

    private var mac: String { client.macName.isEmpty ? "your Mac" : client.macName }
    private var working: Bool { if case .working = client.pairing { return true }; return false }

    var body: some View {
        GeometryReader { geo in
            let layout = ConnectLayout(size: geo.size, fold: duoFold)
            NavigationStack {
                Form {
                    if let link = client.pendingLink {
                        Section {
                            LinkConfirmation(link: link, pair: {
                                linkName = link.name
                                client.confirmPendingLink()
                            }, cancel: cancel)
                        }
                    } else if linkName != nil {
                        Section { status }
                    } else {
                        Section {
                            Text(client.overlayAskLine ?? DiscoveryPolicy.HomeCopy.overlayShowing(mac: mac))
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                            if CodeScanner.isSupported || scannerMode != .live {
                                Picker("Pairing method", selection: Binding(get: { typed }, set: { value in
                                    client.pairing = .idle
                                    codeFocused = false
                                    typed = value
                                })) {
                                    Text("Scan code").tag(false)
                                    Text("Enter code").tag(true)
                                }
                                .pickerStyle(.segmented)
                                .disabled(working)
                            }
                        }
                        Section {
                            if typed {
                                codeField
                            } else if !working {
                                CodeScanner(mode: scannerMode,
                                            onLink: { client.scanned($0, tapped: $1, overlay: true) },
                                            retryNeedsTap: client.scanRetryNeedsTap)
                                    .frame(height: layout.short ? 210 : 280)
                                    .listRowInsets(EdgeInsets())
                            }
                        } footer: {
                            Text(typed ? "Enter the 12-digit code shown on your Mac." : "Point the camera at the pairing code on your Mac.")
                        }
                        Section { status }
                    }
                }
                .navigationTitle("Pair with \(linkName ?? client.pendingLink?.name ?? mac)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                    }
                }
            }
            .frame(width: min(layout.leadingPage ?? geo.size.width, 720),
                   height: layout.roomAboveFold ?? geo.size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: layout.leadingPage == nil ? .top : .topLeading)
        }
        .background(Palette.canvas)
        .tint(Palette.accent)
        .transition(.opacity)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, cancel)
        .background(EscapeKey(action: cancel))
        .onAppear {
            titleFocused = true
            // "Show your pairing code": the Mac opens its pairing window by itself (a plain door), or
            // its ask rule says whether it does (a door that speaks TLS: the line under the title).
            if !asked, client.pendingLink == nil, client.connected { asked = true; client.requestPairingCode(mac: mac) }
        }
        // The Mac's answer to that ask, spoken: VoiceOver's focus is on the title, and a line that
        // says no code is showing, or why, must be heard.
        .onChange(of: client.overlayAskLine) { _, line in
            if let line, line != DiscoveryPolicy.HomeCopy.overlayAsking(mac: mac) { AccessibilityNotification.Announcement(line).post() }
        }
        .task(id: client.pairing) {
            // Paired: says so, then fades after a second; the stream never stopped.
            guard case .paired = client.pairing else { return }
            try? await Task.sleep(for: .seconds(1))
            if !Task.isCancelled {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { close() }
                client.pairing = .idle
                client.endOverlayAsk(withdraw: false)      // its window closed as used
            }
        }
    }

    /// Cancel, Esc and the escape gesture: a pairing still dialing stops (as the connect screen's
    /// card does), an outside link waiting here is dropped rather than shown again later, and a code
    /// the Mac showed for this overlay's ask is withdrawn rather than left up for its 5 minutes.
    private func cancel() {
        client.cancelPendingLink()
        client.cancelPairing()
        client.endOverlayAsk(withdraw: true)
        close()
    }

    private var codeField: some View {
        VStack(alignment: .leading, spacing: 8) {
            PairingField(prompt: "0000 0000 0000", label: "Code", text: $code, keyboard: PairingField.codeKeyboard, submit: .go, monospaced: true)
                .focused($codeFocused)
                .onSubmit(pairTyped)
                .onChange(of: code) { _, typed in
                    let grouped = PairingField.grouped(typed)
                    if grouped != typed { code = grouped }
                }
            Button("Pair Mac", action: pairTyped)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(working)
                .frame(maxWidth: .infinity)
        }
        .disabled(working)
    }

    /// The typed path here needs only the code: over a session at home that speaks TLS it goes to
    /// the session's own row, pinned to the key the session saw (docs/home-pairing-plan.md §7.5);
    /// over any other, to the address from this connection's kind 18 (StreamClient.pairOverlayTyped).
    private func pairTyped() {
        guard !working else { return }
        codeFocused = false
        client.pairOverlayTyped(code: code, mac: mac)
    }

    @ViewBuilder private var status: some View {
        switch client.pairing {
        case .working(let text):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(Palette.muted)
                Text(text)
            }
            .font(.footnote)
            .foregroundStyle(Palette.muted)
            .accessibilityElement(children: .combine)
        case .paired(let name):
            Label("Paired with \(name).", systemImage: "checkmark.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.text)
                .onAppear { AccessibilityNotification.Announcement("Paired with \(name).").post() }
        case .failed(let p):
            ProblemLine(text: p.text)
        case .idle:
            EmptyView()
        }
    }

}
