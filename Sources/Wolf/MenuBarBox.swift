import AppKit

/// Draws the menu bar indicator: a rounded box whose fill tracks the phase, with the
/// remaining time set large inside it. The box hugs the text so it never looks empty.
enum MenuBarBox {

    struct Model {
        var remaining: TimeInterval
        var progress: Double
        var direction: BoxDirection
        var isBreak: Bool
        var isPaused: Bool
    }

    private static let height: CGFloat = 16
    private static let horizontalPadding: CGFloat = 5
    private static let cornerRadius: CGFloat = 3.5

    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)

    static func image(_ model: Model) -> NSImage {
        let tint: NSColor = model.isBreak ? breakGreen : labelColor()
        let alpha: CGFloat = model.isPaused ? 0.55 : 1.0

        let text = model.remaining.clockString as NSString
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: tint.withAlphaComponent(alpha)
        ]
        let textSize = text.size(withAttributes: textAttributes)
        let width = ceil(textSize.width) + horizontalPadding * 2

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            let box = rect.insetBy(dx: 0.5, dy: 0.5)
            let path = NSBezierPath(roundedRect: box, xRadius: cornerRadius, yRadius: cornerRadius)

            // Fill proportion, per the user's chosen direction.
            let fraction = model.direction == .emptiesOut ? 1 - model.progress : model.progress
            if fraction > 0.001 {
                NSGraphicsContext.saveGraphicsState()
                path.addClip()
                let fillWidth = box.width * CGFloat(min(max(fraction, 0), 1))
                tint.withAlphaComponent(0.22 * alpha).setFill()
                NSRect(x: box.minX, y: box.minY, width: fillWidth, height: box.height).fill()
                NSGraphicsContext.restoreGraphicsState()
            }

            tint.withAlphaComponent(0.65 * alpha).setStroke()
            path.lineWidth = 1
            path.stroke()

            text.draw(
                at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2),
                withAttributes: textAttributes
            )

            return true
        }

        // Template rendering lets the system tint for light/dark menu bars, but would
        // discard the green, so it is only used for the neutral focus state.
        image.isTemplate = !model.isBreak
        return image
    }

    private static let breakGreen = NSColor(srgbRed: 0.525, green: 0.863, blue: 0.769, alpha: 1)

    private static func labelColor() -> NSColor {
        var color = NSColor.labelColor
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            color = NSColor.labelColor.usingColorSpace(.sRGB) ?? .labelColor
        }
        return color
    }
}
