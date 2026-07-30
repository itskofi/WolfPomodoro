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

/// Wolf's visual language.
///
/// Warm charcoal pelt and bone off-white carry the surfaces; **green is the app's colour**
/// and drives every accent — the wolf mark, the dial, controls and charts — with a paler
/// green marking breaks. Every colour is dynamic, so the same tokens serve light and dark.
enum Theme {
    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }

    private static func srgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green:   CGFloat((hex >> 8) & 0xFF) / 255,
                blue:    CGFloat(hex & 0xFF) / 255,
                alpha:   alpha)
    }

    /// Panel base. Warm charcoal at night, cool bone by day — never pure black or white.
    static let background = dynamic(light: srgb(0xEDEDEA), dark: srgb(0x191A1C))
    /// Cards and raised surfaces.
    static let surface    = dynamic(light: srgb(0xFFFFFF), dark: srgb(0x222326))
    /// Hairlines and inactive marks.
    static let surfaceRim = dynamic(light: srgb(0xDCDBD6), dark: srgb(0x33353A))
    /// Green: the app's colour, used for the focus phase and every accent.
    static let accent     = dynamic(light: srgb(0x1E7F4F), dark: srgb(0x4ED18A))
    /// A paler, cooler green for breaks, so the two phases stay distinguishable.
    static let mint       = dynamic(light: srgb(0x2C7A6B), dark: srgb(0x86DCC4))
    static let text       = dynamic(light: srgb(0x1C1D20), dark: srgb(0xECEAE5))
    static let textDim    = dynamic(light: srgb(0x6C6E73), dark: srgb(0x97948D))
    static let textFaint  = dynamic(light: srgb(0x9B9C9F), dark: srgb(0x63656A))
    /// Fill behind ghost buttons and pressed states.
    static let wash       = dynamic(light: srgb(0x000000, 0.05), dark: srgb(0xFFFFFF, 0.06))

    /// Text on top of an accent fill. Paired with the accent shade in use — the light
    /// accent is a deep green (needs white), the dark accent is a bright green (needs ink)
    /// — so the label always has contrast.
    static let onAccent = dynamic(light: srgb(0xFFFFFF), dark: srgb(0x16171A))

    static let controlWidth: CGFloat = 138
    static let popoverWidth: CGFloat = 320

    static func accent(forBreak isBreak: Bool) -> Color { isBreak ? mint : accent }

    /// Countdown type: monospaced, so the panel reads as an instrument and the digits
    /// never shift width as the numbers change.
    static func clockFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    /// Small all-caps label with wide tracking, used for every eyebrow in the app.
    static func eyebrow(_ size: CGFloat = 9) -> Font {
        .system(size: size, weight: .semibold)
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

/// A full-width card. All groups use this, so they share identical edges and padding.
struct Card<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let title {
                Text(title.uppercased())
                    .font(Theme.eyebrow())
                    .tracking(1.4)
                    .foregroundStyle(Theme.textFaint)
            }
            content
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(Theme.surfaceRim, lineWidth: 1)
                )
        )
    }
}

/// One settings line: label left, control in a shared right-hand column.
struct Row<Control: View>: View {
    let label: String
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Spacer(minLength: 6)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                control
            }
            .frame(width: Theme.controlWidth)
        }
        .frame(height: 22)
    }
}

struct WolfPrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(tint.opacity(configuration.isPressed ? 0.78 : 1))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct WolfGhostButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(hovering ? Theme.text : Theme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(configuration.isPressed || hovering ? Theme.wash : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(Theme.surfaceRim, lineWidth: 1)
                    )
            )
            // Without this the clear background takes no clicks and only the label works.
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

/// Panel chrome button: quiet by default, colouring only under the pointer — the macOS
/// traffic-light behaviour, without shouting when idle.
struct ChromeButtonStyle: ButtonStyle {
    var hoverTint: Color
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 7.5, weight: .black))
            .foregroundStyle(hovering ? Theme.onAccent : Theme.textFaint)
            .frame(width: 15, height: 15)
            .background(
                Circle().fill(hovering ? hoverTint.opacity(configuration.isPressed ? 0.7 : 1) : Theme.wash)
            )
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
    }
}
