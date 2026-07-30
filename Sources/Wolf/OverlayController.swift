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
            window.appearance = settings.appearance.nsAppearance
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

private struct OverlayView: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var settings: Settings
    @ObservedObject var store: SessionStore
    let onSkip: () -> Void
    let onDismiss: () -> Void

    @ObservedObject private var appearance = AppearanceBridge.shared

    private var accent: Color { Theme.accent(forBreak: timer.phase.isBreak) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Solid, not translucent: the break screen is its own surface.
            Theme.background.ignoresSafeArea()
            RadialGradient(
                colors: [accent.opacity(0.10), .clear],
                center: .center, startRadius: 40, endRadius: 700
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(timer.phase.isBreak ? "Time for a break" : "Back to focus")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Theme.textDim)

                Text(timer.remaining.clockString)
                    .font(Theme.clockFont(84))
                    .foregroundStyle(Theme.text)

                HStack(spacing: 9) {
                    ForEach(0..<max(1, settings.intervals), id: \.self) { index in
                        Circle()
                            .fill(index < timer.completedFocusSessions ? accent : Theme.surfaceRim)
                            .frame(width: 9, height: 9)
                    }
                }

                Text("\(store.todayFocusSeconds.durationString) focused today  ·  \(store.todayFocusSessions) sessions")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textDim)

                HStack(spacing: 12) {
                    Button("Skip break") { onSkip(); onDismiss() }
                    Button("Dismiss screen") { onDismiss() }
                }
                .buttonStyle(OverlayButtonStyle())
                .padding(.top, 6)

                Text("Esc to dismiss")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: onDismiss) { Text("✕") }
                .buttonStyle(ChromeButtonStyle(hoverTint: Color(red: 0.91, green: 0.35, blue: 0.31)))
                .help("Close the break screen")
                .padding(22)
        }
        .environment(\.colorScheme, appearance.scheme(for: settings.appearance))
    }
}

private struct OverlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(configuration.isPressed ? Theme.wash : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(Theme.surfaceRim, lineWidth: 1)
                    )
            )
    }
}
