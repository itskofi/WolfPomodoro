import AppKit
import SwiftUI

/// Full-screen break screen: one borderless window per display, above everything
/// including the menu bar, dismissible with Esc or the buttons.
final class OverlayController {
    private var windows: [NSWindow] = []
    private var escMonitor: Any?

    var isVisible: Bool { !windows.isEmpty }

    func show(timer: PomodoroTimer, settings: Settings, store: SessionStore, onSkip: @escaping () -> Void) {
        guard windows.isEmpty else { return }

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isOpaque = true
            window.backgroundColor = .black
            window.appearance = NSAppearance(named: .darkAqua)
            window.hasShadow = false
            window.contentView = NSHostingView(
                rootView: OverlayView(
                    timer: timer,
                    settings: settings,
                    store: store,
                    onSkip: onSkip,
                    onDismiss: { [weak self] in self?.hide() }
                )
            )
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            windows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)

        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                self?.hide()
                return nil
            }
            return event
        }
    }

    func hide() {
        if let escMonitor {
            NSEvent.removeMonitor(escMonitor)
            self.escMonitor = nil
        }
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}

/// The break as one colour field that drains until the break is over.
private struct OverlayView: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var settings: Settings
    @ObservedObject var store: SessionStore
    let onSkip: () -> Void
    let onDismiss: () -> Void

    private let padding: CGFloat = 56
    private let buttonHeight: CGFloat = 44

    var body: some View {
        GeometryReader { geo in
            let fraction = fillFraction(timer, settings)
            let fillHeight = geo.size.height * fraction
            let digitSize = min(geo.size.height * 0.4, geo.size.width * 0.24)
            DrainingField(fraction: fraction, isBreak: timer.phase.isBreak) { layer in
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center) {
                        Text(timer.phase.title)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(layer.text.opacity(0.65))
                            .opacity(layer.showsText ? 1 : 0)
                        Spacer()
                        buttons(layer, onFill: fillHeight > geo.size.height - padding - buttonHeight / 2)
                    }
                    .frame(height: buttonHeight)

                    Spacer(minLength: 0)

                    BigDigits(text: timer.remaining.bigClockString, size: digitSize, color: layer.text)
                        .opacity(layer.showsText ? 1 : 0)
                    Text(timer.phase.isBreak ? "Stand up and look away until it's empty." : "Back to focus.")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(layer.text.opacity(0.6))
                        .opacity(layer.showsText ? 1 : 0)
                        .padding(.top, 14)
                    Text(todayLine)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(layer.text.opacity(0.45))
                        .opacity(layer.showsText ? 1 : 0)
                        .padding(.top, 8)
                }
                .padding(padding)
            }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }

    private var todayLine: String {
        let sessions = store.todayFocusSessions
        let count = "\(sessions) \(sessions == 1 ? "session" : "sessions") today"
        return store.todayFocusSeconds >= 60 ? "\(store.todayFocusSeconds.durationString) focused · \(count)" : count
    }

    @ViewBuilder
    private func buttons(_ layer: DrainLayer, onFill: Bool) -> some View {
        if layer == .controls {
            let palette = ControlPalette.on(fill: onFill, isBreak: timer.phase.isBreak)
            HStack(spacing: 10) {
                Button("Skip Break") { onSkip(); onDismiss() }
                    .buttonStyle(PillButtonStyle(background: palette.softBackground,
                                                 foreground: palette.softForeground,
                                                 height: buttonHeight, fontSize: 15))
                Button("Hide") { onDismiss() }
                    .buttonStyle(PillButtonStyle(background: palette.primaryBackground,
                                                 foreground: palette.primaryForeground,
                                                 height: buttonHeight, fontSize: 15))
            }
            .fixedSize()
        }
    }
}
