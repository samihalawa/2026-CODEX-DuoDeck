import SwiftUI
import DuoDeckHostCore
import StreamProtocol

/// Presets and audio first; precise tuning remains available without overwhelming daily use.
struct StreamingPane: View {
    let model: AppModel
    @Bindable var settings: HostSettings
    @State private var showCustom = false
    @State private var showAway = false

    var body: some View {
        Form {
            Section {
                Picker("Quality", selection: profile) {
                    ForEach(DuoDeckStreamingPreset.allCases) { preset in
                        Text(preset.title).tag(preset.rawValue)
                    }
                    if DuoDeckStreamingPreset.current(in: settings.config) == nil {
                        Text("Custom").tag("custom")
                    }
                }
                .pickerStyle(.radioGroup)
                Text(selectedDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Stream quality")
            } footer: {
                Footnote("Settings apply immediately. Your Mac may restart the current stream briefly.")
            }

            Section {
                Toggle("Send audio (beta)", isOn: $settings.config.sendAudio)
                if settings.config.sendAudio, let problem = model.coordinator?.status.snapshot.audio?.problem {
                    Warning("DuoDeck Host \(problem). The picture is unaffected.")
                }
            } footer: {
                Footnote("Play the streamed app’s sound on your devices. Your Mac keeps playing it too.")
            }

            Section {
                DisclosureGroup("Custom quality", isExpanded: $showCustom) {
                    Picker("Frame rate limit", selection: $settings.config.maxFPS) {
                        Text("60 fps").tag(60)
                        Text("120 fps").tag(120)
                    }
                    Picker("Quality", selection: $settings.config.bitrate) {
                        ForEach(QualityPreset.allCases) { Text($0.title).tag($0.rawValue) }
                        if QualityPreset(rawValue: settings.config.bitrate) == nil {
                            Text(QualityPreset.title(forBitrate: settings.config.bitrate)).tag(settings.config.bitrate)
                        }
                    }
                    Picker("Resolution", selection: $settings.config.captureScale) {
                        Text("Standard").tag(CGFloat(1))
                        Text("Retina").tag(CGFloat(2))
                    }
                    Toggle("Prioritize encoding speed", isOn: $settings.config.prioritizeSpeed)
                    Footnote("Higher frame rates and resolutions need a faster connection. Prioritizing speed reduces latency with a softer picture. \(QualityPreset.fastLinkNote)")
                }
                DisclosureGroup("Away from home", isExpanded: $showAway) {
                    Picker("Away quality", selection: $settings.config.awayBitrate) {
                        ForEach(QualityPreset.allCases) { Text($0.title).tag($0.rawValue) }
                        if QualityPreset(rawValue: settings.config.awayBitrate) == nil {
                            Text(QualityPreset.title(forBitrate: settings.config.awayBitrate)).tag(settings.config.awayBitrate)
                        }
                    }
                    Picker("Away resolution", selection: $settings.config.awayCaptureScale) {
                        Text("Standard").tag(CGFloat(1))
                        Text("Retina").tag(CGFloat(2))
                    }
                    Footnote("Used while every connected device is away through a VPN or the internet. Your home quality stays unchanged."
                             + (model.coordinator?.status.snapshot.away == true ? " Using these settings now." : ""))
                }
            } header: {
                Text("Advanced")
            }

            if let snapshot = model.coordinator?.status.snapshot, snapshot.softwareEncoder {
                Section {
                    Warning(snapshot.hardwareEncoderStuck
                            ? "The hardware encoder is unavailable. Using software up to 60 fps at Standard resolution. Restart your Mac to try the hardware encoder again."
                            : "Using software up to 60 fps at Standard resolution while the hardware encoder is busy. DuoDeck returns to hardware automatically.")
                }
            }
        }
    }

    private var selectedDescription: String {
        if let preset = DuoDeckStreamingPreset.current(in: settings.config) { return preset.detail }
        return "Custom settings · \(settings.config.maxFPS) fps · \(QualityPreset.shortTitle(bitrate: settings.config.bitrate, captureScale: Double(settings.config.captureScale)))"
    }

    private var profile: Binding<String> {
        Binding(get: { DuoDeckStreamingPreset.current(in: settings.config)?.rawValue ?? "custom" },
                set: { value in
                    if let preset = DuoDeckStreamingPreset(rawValue: value) {
                        settings.config = preset.applying(to: settings.config)
                    }
                })
    }
}
