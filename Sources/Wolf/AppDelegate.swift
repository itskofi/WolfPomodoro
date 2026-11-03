import AppKit
import SwiftUI
import Combine

/// Borderless panel that can take keyboard focus without activating the app.
final class WolfPanel: NSPanel {
    init() {
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovable = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings.shared
    private let store = SessionStore.shared
    private lazy var timer = PomodoroTimer(settings: settings, store: store)
    private let notifier = Notifier()
    private let overlay = OverlayController()

    private var statusItem: NSStatusItem!
    private let panel = WolfPanel()
    private var currentTab: Tab = .timer
    private var outsideClickMonitor: Any?
    private var escMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private var appearanceObservation: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        notifier.requestAuthorization()
        setUpStatusItem()
        setUpPanel()

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
            }
            .store(in: &cancellables)

        // Keep the drawn colours correct when the system switches light/dark.
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            DispatchQueue.main.async {
                AppearanceBridge.shared.refresh()
                self?.updateStatusItem()
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(closePanel),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)

        updateStatusItem()
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.action = #selector(togglePanel)
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

    // MARK: - Panel

    private func setUpPanel() {
        let host = NSHostingView(
            rootView: PopoverView(
                timer: timer,
                settings: settings,
                store: store,
                onTabChange: { [weak self] tab in self?.tabChanged(tab) },
                onQuit: { NSApp.terminate(nil) }
            )
        )
        host.sizingOptions = []
        panel.contentView = host
        // The Füllstand look is dark by design, whatever the system appearance.
        panel.appearance = NSAppearance(named: .darkAqua)
    }

    /// The panel's frame for the current tab: centred under the status item, kept on screen.
    private func panelFrame() -> NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        let size = NSSize(width: Theme.panelWidth, height: currentTab.panelHeight)
        var x = anchor.midX - size.width / 2
        if let visible = (window.screen ?? NSScreen.main)?.visibleFrame {
            x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        }
        return NSRect(x: x, y: anchor.minY - 6 - size.height, width: size.width, height: size.height)
    }

    private func tabChanged(_ tab: Tab) {
        currentTab = tab
        guard panel.isVisible, let frame = panelFrame() else { return }
        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
    }

    @objc private func togglePanel() {
        panel.isVisible ? closePanel() : openPanel()
    }

    private func openPanel() {
        guard let frame = panelFrame() else { return }
        panel.setFrame(frame, display: true)
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()

        // Close on any click in another app (or the desktop), like a popover would.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in self?.closePanel() }

        // Esc closes from the timer; on a sub-page it goes back (handled in the view).
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == 53, event.window === self.panel,
                  self.currentTab == .timer,
                  // While a text field is being edited, Esc belongs to the field (cancel).
                  !(self.panel.firstResponder is NSText) else { return event }
            self.closePanel()
            return nil
        }
    }

    @objc private func closePanel() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let escMonitor { NSEvent.removeMonitor(escMonitor) }
        outsideClickMonitor = nil
        escMonitor = nil
        panel.orderOut(nil)
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
            closePanel()
            overlay.show(timer: timer, settings: settings, store: store) { [weak self] in
                self?.timer.skip()
            }
        } else {
            overlay.hide()
        }

        updateStatusItem()
    }
}
