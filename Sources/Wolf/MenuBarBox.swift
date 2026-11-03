import AppKit

/// Draws the menu bar indicator in the Füllstand style: a well-rounded box that fills with
/// the phase colour (green for focus, blue for breaks). The time sits on top in the menu
/// bar's label colour, switching to ink where it overlaps the fill so it stays legible.
enum MenuBarBox {

    struct Model {
        var remaining: TimeInterval
        var progress: Double
        var direction: BoxDirection
        var isBreak: Bool
        var isPaused: Bool
    }

    private static let height: CGFloat = 16
    private static let horizontalPadding: CGFloat = 6
    private static let cornerRadius: CGFloat = 5.5

    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)
    private static let ink = Theme.srgb(0x0B0B0B)

    static func image(_ model: Model) -> NSImage {
        let fillColor = model.isBreak ? Theme.breakFill : Theme.focusFill
        let alpha: CGFloat = model.isPaused ? 0.5 : 1.0
        let fraction = min(max(model.direction == .emptiesOut ? 1 - model.progress : model.progress, 0), 1)

        let text = model.remaining.clockString as NSString
        let textSize = text.size(withAttributes: [.font: font])
        let width = ceil(textSize.width) + horizontalPadding * 2

        // The handler runs at draw time under the menu bar's own appearance, so
        // `labelColor` resolves to the right colour on light and dark menu bars.
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            let box = rect.insetBy(dx: 0.5, dy: 0.5)
            let path = NSBezierPath(roundedRect: box, xRadius: cornerRadius, yRadius: cornerRadius)
            let label = NSColor.labelColor
            let textOrigin = NSPoint(x: rect.midX - textSize.width / 2,
                                     y: rect.midY - textSize.height / 2)
            let fillRect = NSRect(x: box.minX, y: box.minY,
                                  width: box.width * CGFloat(fraction), height: box.height)

            // Text on the empty part.
            text.draw(at: textOrigin, withAttributes: [
                .font: font, .foregroundColor: label.withAlphaComponent(alpha)
            ])

            // Fill, then the same text in ink clipped to the filled part.
            if fraction > 0.001 {
                NSGraphicsContext.saveGraphicsState()
                path.addClip()
                fillColor.withAlphaComponent(alpha).setFill()
                fillRect.fill()
                NSBezierPath(rect: fillRect).addClip()
                text.draw(at: textOrigin, withAttributes: [.font: font, .foregroundColor: ink])
                NSGraphicsContext.restoreGraphicsState()
            }

            label.withAlphaComponent(0.5 * alpha).setStroke()
            path.lineWidth = 1
            path.stroke()
            return true
        }

        // Not a template: the fill keeps its colour.
        image.isTemplate = false
        return image
    }
}
