import SwiftUI

enum Tab: String, CaseIterable {
    case timer = "Timer", history = "History", settings = "Settings"

    /// Full panel height per tab. The panel window is resized to this, anchored at the top.
    var panelHeight: CGFloat {
        switch self {
        case .timer:    return 392
        case .history:  return 352
        case .settings: return 480
        }
    }
}

/// Fraction of the field still filled, following the menu bar box direction setting.
func fillFraction(_ timer: PomodoroTimer, _ settings: Settings) -> Double {
    settings.boxDirection == .emptiesOut ? 1 - timer.progress : timer.progress
}

struct PopoverView: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var settings: Settings
    @ObservedObject var store: SessionStore
    let onTabChange: (Tab) -> Void
    let onQuit: () -> Void

    @State var tab: Tab = .timer

    var body: some View {
        // All three stay mounted; switching only changes which one is visible.
        ZStack(alignment: .top) {
            pane(.timer) {
                TimerTab(timer: timer, settings: settings, store: store, active: tab == .timer) { go($0) }
            }
            pane(.history) {
                SubPage(title: "History", active: tab == .history, back: { go(.timer) }) {
                    HistoryView(store: store)
                }
            }
            pane(.settings) {
                SubPage(title: "Settings", active: tab == .settings, back: { go(.timer) }) {
                    SettingsView(settings: settings, timer: timer, store: store, onQuit: onQuit)
                }
            }
        }
        .frame(width: Theme.panelWidth, height: tab.panelHeight, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .tint(Theme.accent)
        // The Füllstand look is dark by design.
        .environment(\.colorScheme, .dark)
    }

    private func go(_ next: Tab) {
        tab = next
        onTabChange(next)
    }

    @ViewBuilder
    private func pane<Content: View>(_ item: Tab, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: Theme.panelWidth, height: item.panelHeight, alignment: .top)
            .opacity(tab == item ? 1 : 0)
            .allowsHitTesting(tab == item)
    }
}

/// History and Settings: a back button, a title, and the page on a quiet surface.
private struct SubPage<Content: View>: View {
    let title: String
    let active: Bool
    let back: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: back) { Image(systemName: "chevron.left") }
                    .buttonStyle(CircleIconStyle(background: Theme.onGround.opacity(0.1),
                                                 foreground: Theme.onGround, size: 28))
                    .keyboardShortcut(.escape, modifiers: [])
                    .disabled(!active)
                    .help("Back")
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.onGround.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surface)
    }
}

struct TimerTab: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var settings: Settings
    @ObservedObject var store: SessionStore
    /// Only the visible tab may own keyboard shortcuts.
    let active: Bool
    let open: (Tab) -> Void

    @State private var hovering = false

    private let padding: CGFloat = 22
    private let headerButton: CGFloat = 28
    private let controlHeight: CGFloat = 48

    private var isBreak: Bool { timer.phase.isBreak }
    private var fraction: Double { fillFraction(timer, settings) }
    private var fillHeight: CGFloat { Tab.timer.panelHeight * fraction }

    var body: some View {
        DrainingField(fraction: fraction, isBreak: isBreak) { layer in
            VStack(alignment: .leading, spacing: 0) {
                header(layer)
                Spacer(minLength: 0)
                BigDigits(text: timer.remaining.bigClockString, size: 86, color: layer.text)
                    .opacity(layer.showsText ? 1 : 0)
                Text(statusLine)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(layer.text.opacity(0.6))
                    .opacity(layer.showsText ? 1 : 0)
                    .padding(.top, 6)
                controls(layer)
                    .padding(.top, 22)
            }
            .padding(padding)
        }
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.15)) { hovering = inside }
        }
    }

    private func header(_ layer: DrainLayer) -> some View {
        HStack(spacing: 8) {
            Text(timer.phase.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(layer.text.opacity(0.7))
                .opacity(layer.showsText ? 1 : 0)
            Spacer()
            // History and Settings only show while the pointer is over the panel.
            if layer == .controls {
                let palette = ControlPalette.on(
                    fill: fillHeight > Tab.timer.panelHeight - padding - headerButton / 2,
                    isBreak: isBreak)
                ForEach([(Tab.history, "chart.bar.fill"), (Tab.settings, "gearshape.fill")], id: \.0) { item in
                    Button { open(item.0) } label: { Image(systemName: item.1) }
                        .buttonStyle(CircleIconStyle(background: palette.softBackground,
                                                     foreground: palette.softForeground,
                                                     size: headerButton))
                        .help(item.0.rawValue)
                }
                .opacity(hovering ? 1 : 0)
                .allowsHitTesting(hovering)
            }
            Text(cycle)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(layer.text.opacity(0.7))
                .opacity(layer.showsText ? 1 : 0)
                .padding(.leading, 4)
        }
        .frame(height: headerButton)
    }

    @ViewBuilder
    private func controls(_ layer: DrainLayer) -> some View {
        if layer == .controls {
            let palette = ControlPalette.on(fill: fillHeight > padding + controlHeight / 2,
                                            isBreak: isBreak)
            HStack(spacing: 10) {
                Button(primaryLabel, action: timer.toggle)
                    .buttonStyle(PillButtonStyle(background: palette.primaryBackground,
                                                 foreground: palette.primaryForeground))
                    .keyboardShortcut(.space, modifiers: [])
                Button(action: timer.reset) { Image(systemName: "arrow.counterclockwise") }
                    .buttonStyle(CircleIconStyle(background: palette.softBackground,
                                                 foreground: palette.softForeground))
                    .help("Reset")
                Button(action: timer.skip) { Image(systemName: "forward.fill") }
                    .buttonStyle(CircleIconStyle(background: palette.softBackground,
                                                 foreground: palette.softForeground))
                    .help("Skip")
            }
            .disabled(!active)
        } else {
            Color.clear.frame(height: controlHeight)
        }
    }

    /// Position in the long-break cycle, e.g. "2 / 4".
    private var cycle: String {
        let current = min(timer.completedFocusSessions + (isBreak ? 0 : 1), settings.intervals)
        return "\(max(current, 1)) / \(settings.intervals)"
    }

    private var statusLine: String {
        let today = "\(store.todayFocusSeconds < 60 ? "0m" : store.todayFocusSeconds.durationString) today"
        switch timer.state {
        case .running: return "ends \(Date().addingTimeInterval(timer.remaining).shortTime) · \(today)"
        case .paused:  return "paused · \(today)"
        case .idle:    return "\(Int(timer.totalForCurrentPhase / 60)) min · \(today)"
        }
    }

    private var primaryLabel: String {
        switch timer.state {
        case .running: return "Pause"
        case .paused:  return "Resume"
        case .idle:    return "Start"
        }
    }
}
