import SwiftUI
import AppKit

/// Which appearance the panel uses.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Match system"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light:  return NSAppearance(named: .aqua)
        case .dark:   return NSAppearance(named: .darkAqua)
        }
    }
}

/// Wolf's visual language: "Füllstand". The panel is one colour field that drains as the
/// phase runs out — green for focus, sky blue for breaks — with heavy ink digits on top.
/// Text that the fill line crosses is drawn twice and masked, so it is always legible.
enum Theme {
    static func srgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green:   CGFloat((hex >> 8) & 0xFF) / 255,
                blue:    CGFloat(hex & 0xFF) / 255,
                alpha:   alpha)
    }

    static let focusFill = srgb(0x3DDC84)
    static let breakFill = srgb(0x7FD3F0)

    /// Ink on top of the fill. The fills are bright in both appearances, so it is fixed.
    static let ink = Color(nsColor: srgb(0x0B0B0B))
    /// The colour of the drained part of the field: deep green / deep blue, always dark.
    static func ground(forBreak isBreak: Bool) -> Color {
        Color(nsColor: isBreak ? srgb(0x1A2730) : srgb(0x1E2A23))
    }
    static func fill(forBreak isBreak: Bool) -> Color {
        Color(nsColor: isBreak ? breakFill : focusFill)
    }
    /// Text on the drained ground.
    static let onGround = Color.white
    /// History and Settings sit on the focus ground.
    static let surface  = Color(nsColor: srgb(0x1E2A23))
    static let accent   = Color(nsColor: focusFill)

    static let panelWidth: CGFloat = 300
    static let panelRadius: CGFloat = 22

    /// Heavy, tightly tracked, fixed-width digits.
    static func digits(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).monospacedDigit()
    }
}

/// Heavy countdown digits, tightened with kerning between the glyphs.
struct BigDigits: View {
    let text: String
    let size: CGFloat
    let color: Color

    var body: some View {
        // Longer strings ("100:00") step down so they still fit the same width.
        let fitted = text.count > 5 ? size * 0.8 : size
        // Kerning also applies after the last glyph, which would shrink the frame and clip
        // it — so the last character is appended unkerned.
        (Text(String(text.dropLast())).kerning(-fitted * 0.04) + Text(String(text.suffix(1))))
            .font(Theme.digits(fitted))
            .fixedSize()
            .foregroundStyle(color)
    }
}

/// Which copy of a two-tone layout is being drawn.
enum DrainLayer {
    case ground, fill, controls
    var text: Color { self == .fill ? Theme.ink : Theme.onGround }
    var showsText: Bool { self != .controls }
}

/// A colour field drained to `fraction` (1 = full). `layout` is drawn three times on
/// identical geometry: text on the ground, text on the fill (each masked to its region),
/// and the interactive controls on top.
struct DrainingField<Layout: View>: View {
    let fraction: Double
    let isBreak: Bool
    @ViewBuilder let layout: (DrainLayer) -> Layout

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let fillHeight = height * min(max(fraction, 0), 1)
            ZStack {
                Theme.ground(forBreak: isBreak)
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Theme.fill(forBreak: isBreak)
                        .frame(height: fillHeight)
                        .animation(.linear(duration: 0.5), value: fraction)
                }
                layout(.ground)
                    .mask(alignment: .top) {
                        // 1 pt overlap hides the anti-aliasing seam at the fill line;
                        // the fill copy is drawn on top, so the overlap never shows.
                        Rectangle().frame(height: min(height, height - fillHeight + 1))
                            .animation(.linear(duration: 0.5), value: fraction)
                    }
                    .allowsHitTesting(false)
                layout(.fill)
                    .mask(alignment: .bottom) {
                        Rectangle().frame(height: fillHeight)
                            .animation(.linear(duration: 0.5), value: fraction)
                    }
                    .allowsHitTesting(false)
                layout(.controls)
            }
        }
    }
}

/// Button colours for a control sitting on the fill or on the drained ground.
struct ControlPalette {
    let primaryBackground: Color
    let primaryForeground: Color
    let softBackground: Color
    let softForeground: Color

    static func on(fill isOnFill: Bool, isBreak: Bool) -> ControlPalette {
        let fill = Theme.fill(forBreak: isBreak)
        return isOnFill
            ? ControlPalette(primaryBackground: Theme.ink, primaryForeground: fill,
                             softBackground: Theme.ink.opacity(0.12), softForeground: Theme.ink)
            : ControlPalette(primaryBackground: fill, primaryForeground: Theme.ink,
                             softBackground: Theme.onGround.opacity(0.12), softForeground: Theme.onGround)
    }
}

/// Tracks the system appearance so the panel can resolve its colours explicitly.
final class AppearanceBridge: ObservableObject {
    static let shared = AppearanceBridge()
    @Published var systemIsDark: Bool = AppearanceBridge.currentIsDark()

    static func currentIsDark() -> Bool {
        NSApp?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    func refresh() {
        let now = AppearanceBridge.currentIsDark()
        if now != systemIsDark { systemIsDark = now }
    }

    func scheme(for mode: AppearanceMode) -> ColorScheme {
        switch mode {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return systemIsDark ? .dark : .light
        }
    }
}

/// Filled pill: the main action.
struct PillButtonStyle: ButtonStyle {
    var background: Color
    var foreground: Color
    var height: CGFloat = 48
    var fontSize: CGFloat = 15
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 20)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(background))
            .opacity(configuration.isPressed ? 0.8 : (hovering ? 0.92 : 1))
            .contentShape(Capsule())
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

/// Round icon button on a soft tint.
struct CircleIconStyle: ButtonStyle {
    var background: Color
    var foreground: Color
    var size: CGFloat = 48
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.36, weight: .bold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(Circle().fill(background))
            .brightness(hovering ? 0.06 : 0)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Circle())
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

extension Date {
    var shortTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: self)
    }
}
