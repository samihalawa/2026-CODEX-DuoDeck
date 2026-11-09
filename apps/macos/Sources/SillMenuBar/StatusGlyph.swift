import AppKit

/// DuoDeck's paired-D mark, drawn as a template with small connection-state indicators.
enum StatusGlyph {
    enum State: Equatable, CaseIterable { case idle, connected, streaming, attention }
    static let size = NSSize(width: 22, height: 18)

    /// Keep the fallback/preview identity consistent with the app's mark.
    static let symbolFallback: NSImage? = image(.idle)

    static func image(_ state: State) -> NSImage {
        let image = NSImage(size: size, flipped: true) { _ in
            guard let c = NSGraphicsContext.current?.cgContext else { return false }
            c.setFillColor(NSColor.black.cgColor)
            for x: CGFloat in [1.25, 11.5] {
                c.addPath(letterD(in: CGRect(x: x, y: 1.75, width: 8.75, height: 11.75)))
                c.drawPath(using: .eoFill)
            }
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
                // A clear halo keeps the badge separate from the D at menu-bar scale.
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

    private static func letterD(in r: CGRect) -> CGPath {
        let p = CGMutablePath()
        let x = r.minX, y = r.minY, w = r.width, h = r.height, stroke: CGFloat = 2.15
        p.move(to: CGPoint(x: x, y: y))
        p.addLine(to: CGPoint(x: x + w * 0.4, y: y))
        p.addCurve(to: CGPoint(x: x + w, y: y + h * 0.5),
                   control1: CGPoint(x: x + w * 0.8, y: y),
                   control2: CGPoint(x: x + w, y: y + h * 0.22))
        p.addCurve(to: CGPoint(x: x + w * 0.4, y: y + h),
                   control1: CGPoint(x: x + w, y: y + h * 0.78),
                   control2: CGPoint(x: x + w * 0.8, y: y + h))
        p.addLine(to: CGPoint(x: x, y: y + h))
        p.closeSubpath()

        p.move(to: CGPoint(x: x + stroke, y: y + stroke))
        p.addLine(to: CGPoint(x: x + w * 0.4, y: y + stroke))
        p.addCurve(to: CGPoint(x: x + w - stroke, y: y + h * 0.5),
                   control1: CGPoint(x: x + w * 0.7, y: y + stroke),
                   control2: CGPoint(x: x + w - stroke, y: y + h * 0.32))
        p.addCurve(to: CGPoint(x: x + w * 0.4, y: y + h - stroke),
                   control1: CGPoint(x: x + w - stroke, y: y + h * 0.68),
                   control2: CGPoint(x: x + w * 0.7, y: y + h - stroke))
        p.addLine(to: CGPoint(x: x + stroke, y: y + h - stroke))
        p.closeSubpath()
        return p
    }
}
