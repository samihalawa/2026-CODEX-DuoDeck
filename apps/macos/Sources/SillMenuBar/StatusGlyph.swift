import AppKit

/// Folded-display glyph for DuoDeck. Unlike the old iMac-with-tablet design,
/// this reflects the actual product: two panels joined by a hinge and a cursor.
enum StatusGlyph {
    enum State: Equatable, CaseIterable { case idle, connected, streaming, attention }
    static let size = NSSize(width: 22, height: 18)

    static let symbolFallback: NSImage? = {
        let image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "DuoDeck Host")
        image?.isTemplate = true
        return image
    }()

    static func image(_ state: State) -> NSImage {
        let image = NSImage(size: size, flipped: true) { _ in
            guard let c = NSGraphicsContext.current?.cgContext else { return false }
            c.setStrokeColor(NSColor.black.cgColor)
            c.setFillColor(NSColor.black.cgColor)
            c.setLineWidth(1.65)
            let top = CGRect(x: 2, y: 1, width: 18, height: 7)
            let bottom = CGRect(x: 2, y: 10, width: 18, height: 7)
            c.addPath(CGPath(roundedRect: top, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil))
            c.strokePath()
            c.addPath(CGPath(roundedRect: bottom, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil))
            c.strokePath()
            c.fill(CGRect(x: 5, y: 8.4, width: 12, height: 0.9))
            switch state {
            case .idle: break
            case .connected:
                c.fillEllipse(in: CGRect(x: 9.25, y: 12, width: 3.5, height: 3.5))
            case .streaming:
                c.fill(CGRect(x: 5.2, y: 3.1, width: 11.6, height: 2.9))
                c.fillEllipse(in: CGRect(x: 9.25, y: 12, width: 3.5, height: 3.5))
            case .attention:
                c.setBlendMode(.clear)
                c.fillEllipse(in: CGRect(x: 16, y: 11, width: 6, height: 6))
                c.setBlendMode(.normal)
                c.fillEllipse(in: CGRect(x: 17.4, y: 12, width: 4, height: 4))
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "DuoDeck Host"
        return image
    }
}
