import AppKit
import SwiftUI
import SillHostCore
import StreamProtocol

/// Settings › Devices, live: Require pairing, which the model keeps in the identity store beside
/// the trust list (never in UserDefaults), the pairing window's switch for screen sharing (in
/// UserDefaults, HostSettings), and the paired devices from the host's status (pushed, so nothing
/// polls), with the model's actions.
struct LiveDevicesPane: View {
    let model: AppModel
    @Bindable var settings: HostSettings

    var body: some View {
        DevicesPane(status: model.coordinator?.status.snapshot.remote ?? RemoteStatus(),
                    requirePairing: Binding(get: { settings.config.requirePairing }, set: { model.setRequirePairing($0) }),
                    showPairingWindowToScreenSharing: $settings.showPairingWindowToScreenSharing,
                    requirePairingProblem: model.requirePairingProblem,
                    actions: DevicesPane.Actions(pair: { model.pairDevice() },
                                                 remove: { model.removeDevice($0) },
                                                 rename: { model.renameDevice($0, to: $1) }))
    }
}

/// The Devices pane (docs/home-pairing-plan.md §6.1): Require pairing; Show the pairing window to
/// screen sharing (issue #108, PairingWindowSharing); and the devices paired with this Mac at home
/// and from afar (one trust list), each with how it paired and how it last connected, Remove, rename
/// and Pair iPhone or iPad…. Values in, actions out, so the previews can draw every state. Errors
/// show inline, never in alerts.
struct DevicesPane: View {
    struct Actions {
        var pair: () -> Void = {}
        /// Nil when the device was removed; otherwise why it is still paired.
        var remove: (String) -> String? = { _ in nil }
        var rename: (String, String) -> Void = { _, _ in }
    }

    let status: RemoteStatus
    @Binding var requirePairing: Bool
    /// Screen Sharing and other remote desktop apps show the pairing window (off by default).
    @Binding var showPairingWindowToScreenSharing: Bool
    /// The last Require pairing change the identity store did not keep.
    var requirePairingProblem: AppModel.RequirePairingProblem?
    let actions: Actions
    /// "Last connected 2 minutes ago" counts from here (fixed in the previews).
    var now: Date?

    @State private var removedName: String?
    @State private var showPairingOptions = false
    /// A Remove the keychain did not keep: the device's name and why.
    @State private var removeProblem: (name: String, reason: String)?

    /// Why devices can't connect at all: the identity (the key, the trust list) could not be used,
    /// so the home door has no listener. Nil when it works.
    private var unavailable: String? {
        if let problem = status.identityProblem { return problem }
        if case .unavailable(let why) = status.homeDoor { return why }
        return nil
    }

    var body: some View {
        Form {
            pairedDevices
            if let problem = unavailable {
                Section {
                    Warning("Devices can’t connect because DuoDeck Host couldn’t use its keychain key (\(withoutFullStop(problem))). Reopen DuoDeck Host and choose Always Allow if the keychain asks.")
                }
            } else if let p = requirePairingProblem {
                Section {
                    Warning(p.wanted
                            ? "Pairing is required until DuoDeck Host quits. The keychain couldn’t be updated (\(withoutFullStop(p.reason))). Try again."
                            : "Pairing is still required. The keychain couldn’t be updated (\(withoutFullStop(p.reason))). Try again.")
                }
            }
            if !requirePairing {
                Section {
                    Warning("Pairing is off. Any device on your network can see and control this Mac.")
                }
            }
            Section {
                DisclosureGroup("Pairing options", isExpanded: $showPairingOptions) {
                    Toggle("Require pairing", isOn: $requirePairing)
                        .disabled(unavailable != nil)
                    Footnote("Pair each device once with the Mac’s code or over USB. Connections are encrypted.")
                    Toggle("Show pairing to screen sharing", isOn: $showPairingWindowToScreenSharing)
                        .padding(.top, 6)
                    Footnote("For setup through Screen Sharing or another remote desktop app. Anyone viewing that remote screen can read the code. Devices streaming this Mac never show it.")
                }
            }
        }
    }

    private var pairedDevices: some View {
        Section {
            if let removedName {
                Text("\(removedName) can no longer connect. To use it again, pair it again.")
            }
            if let removeProblem {
                Warning("\(removeProblem.name) is still paired: DuoDeck Host couldn’t update the keychain (\(withoutFullStop(removeProblem.reason))). Try again.")
            }
            if unavailable != nil {
                // The trust list lives with the key: unread, not empty.
                Text("Your paired devices show here once DuoDeck Host can use its key again.").foregroundStyle(.secondary)
            } else if status.paired.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "ipad.and.iphone")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No paired devices").fontWeight(.medium)
                        Text("Pair your iPhone or iPad to stream and control this Mac.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 8)
            }
            ForEach(status.paired) { device in
                PairedDeviceRow(device: device, now: now,
                                remove: {
                                    // Said only once the keychain kept it: otherwise the device
                                    // would be trusted again at the next launch.
                                    if let reason = actions.remove(device.id) {
                                        removedName = nil
                                        removeProblem = (device.name, reason)
                                    } else {
                                        removedName = device.name
                                        removeProblem = nil
                                    }
                                },
                                rename: { actions.rename(device.id, $0) })
            }
            Button("Pair iPhone or iPad…") { actions.pair() }
                .buttonStyle(.borderedProminent)
                .disabled(unavailable != nil)
        } header: {
            Text("Paired Devices")
        } footer: {
            Footnote("A paired device can see and control this Mac on your network, nearby, and from afar while Remote Access is on. If one is lost, remove it here.")
        }
    }
}

/// One paired device: its name (double-click to rename: Return saves, Esc cancels), how it paired,
/// when and how it last connected (at home or from away), and Remove, with no confirmation since
/// it only takes access away.
struct PairedDeviceRow: View {
    let device: PairedDeviceSummary
    let now: Date?
    let remove: () -> Void
    let rename: (String) -> Void

    @State private var editing = false
    @State private var showDetails = false
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        LabeledContent {
            Menu {
                Button("Details…") { showDetails = true }
                Button("Rename…") { startEditing() }
                Divider()
                Button(role: .destructive, action: remove) {
                    Label("Remove Device", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Details, rename, or remove \(device.name)")
            .accessibilityLabel("Options for \(device.name)")
            .popover(isPresented: $showDetails) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(device.name).font(.headline)
                    Text(Self.detail(device, now: now ?? Date()))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(width: 300, alignment: .leading)
            }
        } label: {
            if editing {
                TextField("Name", text: $text)
                    .focused($focused)
                    .onSubmit {
                        rename(text)
                        editing = false
                    }
                    .onExitCommand { editing = false }
            } else {
                Text(DuoDeckHostStyle.deviceName(device.name))
                    .onTapGesture(count: 2) { startEditing() }
                    .accessibilityAction(named: "Rename") { startEditing() }
            }
            Text(Self.lastConnection(device, now: now ?? Date()))
        }
    }

    private func startEditing() {
        text = device.name
        editing = true
        focused = true
    }

    private static func lastConnection(_ device: PairedDeviceSummary, now: Date) -> String {
        guard let seen = device.lastSeen else { return "Paired · not connected yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        let when = now.timeIntervalSince(seen) < 60 ? "just now" : formatter.localizedString(for: seen, relativeTo: now)
        return "Last connected \(when)"
    }

    /// "Paired Sep 25 over the USB cable · last connected 2 minutes ago over Wi‑Fi", "Paired Sep 24
    /// with the QR code · last connected yesterday through Tailscale".
    static func detail(_ device: PairedDeviceSummary, now: Date) -> String {
        var out = "Paired \(day(device.pairedAt, now: now))"
        if let method = device.displayMethod { out += " \(method)" }
        if let seen = device.lastSeen {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            formatter.dateTimeStyle = .named
            let when = now.timeIntervalSince(seen) < 60 ? "just now" : formatter.localizedString(for: seen, relativeTo: now)
            out += " · last connected \(when)"
            if let route = device.lastRoute { out += " \(route)" }
        }
        return out
    }

    static func day(_ date: Date, now: Date) -> String {
        let sameYear = Calendar.current.component(.year, from: date) == Calendar.current.component(.year, from: now)
        return sameYear ? date.formatted(.dateTime.month(.abbreviated).day()) : date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}
