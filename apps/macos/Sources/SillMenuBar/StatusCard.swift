import AppKit
import SwiftUI

/// One restrained accent; system materials and text colors provide the rest of the interface.
enum DuoDeckHostStyle {
    static let accent = Color(nsColor: NSColor(name: NSColor.Name("DuoDeckAccent")) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua { return .systemTeal }
        return NSColor(srgbRed: 0, green: 127.0 / 255, blue: 120.0 / 255, alpha: 1)
    })
}

struct DuoDeckHostMark: View {
    var size: CGFloat = 43

    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let icon = NSImage(contentsOf: url) {
                Image(nsImage: icon).resizable().interpolation(.high)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.23)
                        .fill(DuoDeckHostStyle.accent.opacity(0.12))
                    VStack(spacing: size * 0.08) {
                        RoundedRectangle(cornerRadius: size * 0.06)
                            .strokeBorder(DuoDeckHostStyle.accent, lineWidth: size * 0.045)
                        RoundedRectangle(cornerRadius: size * 0.06)
                            .fill(DuoDeckHostStyle.accent.opacity(0.24))
                    }
                    .padding(size * 0.2)
                    Image(systemName: "cursorarrow")
                        .font(.system(size: size * 0.35, weight: .medium))
                        .foregroundStyle(DuoDeckHostStyle.accent)
                        .offset(x: size * 0.11, y: size * 0.12)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Quiet product identity in the overview; readiness is presented from the live host below.
struct DuoDeckHostBanner: View {
    var body: some View {
        HStack(spacing: 13) {
            DuoDeckHostMark(size: 54)
            VStack(alignment: .leading, spacing: 3) {
                Text("DuoDeck Host")
                    .font(.system(size: 21, weight: .semibold))
                Text("Your Mac, within reach.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
    }
}

/// A compact native menu header. Its content follows the actual host, including failure states.
struct StatusCard: View {
    let presentation: StatusPresentation

    private var statusColor: Color {
        presentation.glyph == .attention ? .orange : DuoDeckHostStyle.accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                DuoDeckHostMark(size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("DuoDeck Host")
                        .font(.system(size: 13, weight: .semibold))
                    if let name = presentation.advertisedName {
                        Text(name)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: presentation.glyph == .attention ? "exclamationmark.circle.fill" :
                        presentation.devices.isEmpty ? "circle.dotted" : "checkmark.circle.fill")
                    .foregroundStyle(statusColor)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.header)
                    .font(.system(size: 12, weight: .medium))
                if let subtitle = presentation.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let source = presentation.source { DuoDeckStatusRow(row: source, showDetails: false) }
            ForEach(presentation.devices) { DuoDeckStatusRow(row: $0, showDetails: false) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
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

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: row.symbol)
                .foregroundStyle(DuoDeckHostStyle.accent)
                .frame(width: 17)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if showDetails, let detail = row.detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
