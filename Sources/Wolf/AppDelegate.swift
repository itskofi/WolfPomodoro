import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let settings = Settings.shared
    private let store = SessionStore.shared
    private lazy var timer = PomodoroTimer(settings: settings, store: store)
    private let notifier = Notifier()
    private let overlay = OverlayController()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellables = Set<AnyCancellable>()
    private var appearanceObservation: NSKeyValueObservation?
    private var appliedAppearance: AppearanceMode?

    func applicationDidFinishLaunching(_ notification: Notification) {
        notifier.requestAuthorization()
        setUpStatusItem()
        setUpPopover()

        timer.onPhaseEnd = { [weak self] ended, next in
            self?.handlePhaseEnd(ended: ended, next: next)
        }

        // Repaint the menu bar box on every published change of the engine, and whenever
        // the direction setting changes.
        timer.objectWillChange
            .merge(with: settings.objectWillChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.updateStatusItem()
                self?.applyAppearanceIfNeeded()
            }
            .store(in: &cancellables)

        // Keep the drawn colours correct when the system switches light/dark.
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            DispatchQueue.main.async {
                AppearanceBridge.shared.refresh()
                self?.updateStatusItem()
            }
        }

        updateStatusItem()
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
        statusItem.button?.imagePosition = .imageOnly
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = MenuBarBox.image(
            MenuBarBox.Model(
                remaining: timer.remaining,
                progress: timer.progress,
                direction: settings.boxDirection,
                isBreak: timer.phase.isBreak,
                isPaused: timer.state == .paused
            )
        )
    }

    // MARK: - Popover

    private func setUpPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        // Without this the popover animates its own resize when the tab height changes,
        // which reads as the content sliding down the panel.
        popover.animates = false
        popover.delegate = self
        popover.appearance = settings.appearance.nsAppearance
        appliedAppearance = settings.appearance

        let controller = NSHostingController(
            rootView: PopoverView(
                timer: timer,
                settings: settings,
                store: store,
                onClose: { [weak self] in self?.popover.performClose(nil) },
                onQuit: { NSApp.terminate(nil) }
            )
        )
        // Sizing follows the content, so no tab is padded out with dead space.
        controller.sizingOptions = [.preferredContentSize]
        popover.contentViewController = controller
    }

    /// Reassigning NSAppearance forces a relayout, so only do it on a real change —
    /// doing it on every publish is what made the panel jump.
    private func applyAppearanceIfNeeded() {
        guard appliedAppearance != settings.appearance else { return }
        appliedAppearance = settings.appearance
        popover.appearance = settings.appearance.nsAppearance
        popover.contentViewController?.view.appearance = settings.appearance.nsAppearance
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Phase transitions

    private func handlePhaseEnd(ended: Phase, next: Phase) {
        let message = ended == .focus ? settings.focusEndMessage : settings.breakEndMessage
        let detail = "\(next.title): \(settings.duration(for: next).clockString)"

        notifier.notify(title: message, body: detail)

        if settings.playSound {
            notifier.playSound(named: ended == .focus ? "Glass" : "Ping")
        }

        if ended == .focus, settings.showOverlay {
            overlay.show(timer: timer, settings: settings, store: store) { [weak self] in
                self?.timer.skip()
            }
        } else {
            overlay.hide()
        }

        updateStatusItem()
    }
}
