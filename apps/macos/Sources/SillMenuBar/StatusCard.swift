import AppKit
import SwiftUI

/// A single accent for actions and selection; native surfaces and status colors do the rest.
enum DuoDeckHostStyle {
    static let accent = Color(nsColor: NSColor(name: NSColor.Name("DuoDeckAccent")) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(srgbRed: 167.0 / 255, green: 139.0 / 255, blue: 250.0 / 255, alpha: 1)   // violet 400
        }
        return NSColor(srgbRed: 109.0 / 255, green: 40.0 / 255, blue: 217.0 / 255, alpha: 1)   // #6D28D9, the mark's violet
    })

    /// Summary rows hide the standard model suffix. Details keep the complete stored name.
    static func deviceName(_ name: String) -> String {
        name.replacingOccurrences(of: #" \((iPad|iPhone|iPod)[0-9]+,[0-9]+\)$"#,
                                  with: "", options: .regularExpression)
    }

    static func statusColor(_ state: StatusGlyph.State) -> Color {
        switch state {
        case .attention: .orange
        case .streaming, .connected: .green
        case .idle: .secondary
        }
    }

    static func statusSymbol(_ state: StatusGlyph.State) -> String {
        switch state {
        case .attention: "exclamationmark.circle.fill"
        case .streaming, .connected: "checkmark.circle.fill"
        case .idle: "circle.dotted"
        }
    }
}

/// The menu leads with the Mac's actual state. Branding belongs in the app and window chrome.
struct StatusCard: View {
    let presentation: StatusPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let name = presentation.advertisedName {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Image(systemName: DuoDeckHostStyle.statusSymbol(presentation.glyph))
                    .foregroundStyle(DuoDeckHostStyle.statusColor(presentation.glyph))
                    .accessibilityHidden(true)
                Text(presentation.header)
                    .font(.system(size: 13, weight: .semibold))
            }
            if let subtitle = presentation.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let source = presentation.source { DuoDeckStatusRow(row: source, showDetails: false) }
            ForEach(presentation.devices) { DuoDeckStatusRow(row: $0, showDetails: false) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 300, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

struct LiveStatusCard: View {
    let model: AppModel
    var body: some View { StatusCard(presentation: model.presentation) }
}

struct DuoDeckStatusRow: View {
    let row: StatusPresentation.Row
    var showDetails = true

    private var title: String {
        guard !showDetails, row.id != "source" else { return row.title }
        return DuoDeckHostStyle.deviceName(row.title)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: row.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 17)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let detail = showDetails ? row.detail : row.issue {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(!showDetails && row.issue != nil ? Color.orange : Color.secondary)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
