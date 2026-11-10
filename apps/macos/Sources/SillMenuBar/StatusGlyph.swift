import AppKit

/// DuoDeck's seated-Duo mark, drawn as a template with small connection-state indicators.
enum StatusGlyph {
    enum State: Equatable, CaseIterable { case idle, connected, streaming, attention }
    static let size = NSSize(width: 22, height: 18)

    /// Keep the fallback/preview identity consistent with the app's mark.
    static let symbolFallback: NSImage? = image(.idle)

    static func image(_ state: State) -> NSImage {
        let image = NSImage(size: size, flipped: true) { _ in
            guard let c = NSGraphicsContext.current?.cgContext else { return false }
            c.setFillColor(NSColor.black.cgColor)
            c.addPath(seatedMark())
            c.drawPath(using: .eoFill)
            switch state {
            case .idle:
                break
            case .connected:
                c.fillEllipse(in: CGRect(x: 9.75, y: 15, width: 2.5, height: 2.5))
            case .streaming:
                c.addPath(CGPath(roundedRect: CGRect(x: 7.25, y: 15.25, width: 7.5, height: 2),
                                 cornerWidth: 1, cornerHeight: 1, transform: nil))
                c.fillPath()
            case .attention:
                // A clear halo keeps the badge separate from the mark at menu-bar scale.
                c.setBlendMode(.clear)
                c.fillEllipse(in: CGRect(x: 15.5, y: 10.5, width: 6.5, height: 6.5))
                c.setBlendMode(.normal)
                c.fillEllipse(in: CGRect(x: 16.5, y: 11.5, width: 4.5, height: 4.5))
                c.setBlendMode(.clear)
                c.fill(CGRect(x: 18.35, y: 12.15, width: 0.8, height: 1.7))
                c.fillEllipse(in: CGRect(x: 18.35, y: 14.45, width: 0.8, height: 0.8))
                c.setBlendMode(.normal)
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "DuoDeck Host"
        return image
    }

    /// The seated-Duo mark at menu-bar scale: an upright half over a flared deck with one key slot.
    private static func seatedMark() -> CGPath {
        let p = CGMutablePath()
        p.addPath(CGPath(roundedRect: CGRect(x: 5.75, y: 0.75, width: 10.5, height: 7),
                         cornerWidth: 2.2, cornerHeight: 2.2, transform: nil))
        let deck = [CGPoint(x: 6.4, y: 8.75), CGPoint(x: 15.6, y: 8.75),
                    CGPoint(x: 18.75, y: 13.25), CGPoint(x: 3.25, y: 13.25)]
        let radius: CGFloat = 1.2
        p.move(to: CGPoint(x: 11, y: 8.75))
        for i in 1...4 {
            p.addArc(tangent1End: deck[i % 4], tangent2End: deck[(i + 1) % 4], radius: radius)
        }
        p.closeSubpath()
        p.addPath(CGPath(roundedRect: CGRect(x: 8.75, y: 10.75, width: 4.5, height: 1.1),
                         cornerWidth: 0.55, cornerHeight: 0.55, transform: nil))
        return p
    }
}
