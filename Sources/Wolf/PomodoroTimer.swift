import Foundation
import Combine

enum Phase: String, Codable {
    case focus, shortBreak, longBreak

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    var isBreak: Bool { self != .focus }
}

enum RunState { case idle, running, paused }

/// Phase state machine. The countdown is derived from a wall-clock deadline so it never
/// drifts; the tick timer only drives republishing. Actual time spent per phase is tracked
/// separately (across pauses) so history can record partial sessions.
final class PomodoroTimer: ObservableObject {
    @Published private(set) var phase: Phase = .focus
    @Published private(set) var state: RunState = .idle
    @Published private(set) var remaining: TimeInterval
    /// Focus sessions finished in the current long-break cycle.
    @Published private(set) var completedFocusSessions: Int = 0

    /// Called on every phase transition with (phase that just ended, phase now starting).
    var onPhaseEnd: ((Phase, Phase) -> Void)?

    private let settings: Settings
    private let store: SessionStore
    private var deadline: Date?
    private var ticker: Timer?

    /// Minimum time spent before a phase is worth recording.
    private let minimumRecordedSeconds: TimeInterval = 30

    private var phaseStartedAt: Date?      // first moment this phase ran
    private var accumulatedElapsed: TimeInterval = 0  // completed running segments
    private var segmentStart: Date?        // start of the current running segment

    init(settings: Settings = .shared, store: SessionStore = .shared) {
        self.settings = settings
        self.store = store
        self.remaining = settings.duration(for: .focus)
    }

    var totalForCurrentPhase: TimeInterval { settings.duration(for: phase) }

    var progress: Double {
        let total = totalForCurrentPhase
        guard total > 0 else { return 0 }
        return min(max(1 - remaining / total, 0), 1)
    }

    private var elapsedInPhase: TimeInterval {
        accumulatedElapsed + (segmentStart.map { -$0.timeIntervalSinceNow } ?? 0)
    }

    // MARK: - Controls

    func start() {
        switch state {
        case .running: return
        case .paused: deadline = Date().addingTimeInterval(remaining)
        case .idle:
            remaining = settings.duration(for: phase)
            deadline = Date().addingTimeInterval(remaining)
        }
        if phaseStartedAt == nil {
            phaseStartedAt = Date()
            accumulatedElapsed = 0
        }
        segmentStart = Date()
        state = .running
        startTicker()
    }

    func pause() {
        guard state == .running else { return }
        remaining = max(0, deadline?.timeIntervalSinceNow ?? 0)
        accumulatedElapsed = elapsedInPhase
        segmentStart = nil
        deadline = nil
        state = .paused
        stopTicker()
    }

    func toggle() { state == .running ? pause() : start() }

    /// End the current phase immediately and advance, recorded as a partial session.
    func skip() { advance(completed: false) }

    func reset() {
        stopTicker()
        state = .idle
        phase = .focus
        completedFocusSessions = 0
        deadline = nil
        remaining = settings.duration(for: .focus)
        clearElapsedTracking()
    }

    /// Re-arm an idle phase after its duration changed in Settings.
    func refreshIdleDuration() {
        guard state == .idle else { return }
        remaining = settings.duration(for: phase)
    }

    // MARK: - Ticking

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        tick()
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard state == .running, let deadline else { return }
        let left = deadline.timeIntervalSinceNow
        if left <= 0 {
            remaining = 0
            advance(completed: true)
        } else {
            remaining = left
        }
    }

    private func clearElapsedTracking() {
        phaseStartedAt = nil
        accumulatedElapsed = 0
        segmentStart = nil
    }

    private func recordEndedPhase(_ ended: Phase, completed: Bool) {
        guard let started = phaseStartedAt else { return }
        let spent = elapsedInPhase
        guard spent >= minimumRecordedSeconds else { return }
        store.add(SessionRecord(
            phase: ended,
            start: started,
            end: Date(),
            plannedSeconds: settings.duration(for: ended),
            actualSeconds: spent,
            wasCompleted: completed
        ))
    }

    /// Move to the next phase in the cycle and decide whether it auto-starts.
    private func advance(completed: Bool) {
        let ended = phase
        recordEndedPhase(ended, completed: completed)
        clearElapsedTracking()

        if ended == .focus {
            completedFocusSessions += 1
            let isLong = completedFocusSessions >= max(1, settings.intervals)
            if isLong { completedFocusSessions = 0 }
            phase = isLong ? .longBreak : .shortBreak
        } else {
            phase = .focus
        }

        let next = phase
        remaining = settings.duration(for: next)
        let autoStart = next.isBreak ? settings.autoStartBreaks : settings.autoStartFocus

        if autoStart {
            deadline = Date().addingTimeInterval(remaining)
            phaseStartedAt = Date()
            segmentStart = Date()
            state = .running
            startTicker()
        } else {
            deadline = nil
            state = .idle
            stopTicker()
        }

        onPhaseEnd?(ended, next)
    }
}

extension TimeInterval {
    /// "MM:SS", rounding up so a fresh 25 min phase reads 25:00 rather than 24:59.
    var clockString: String {
        let total = Int(rounded(.up))
        return String(format: "%02d:%02d", max(0, total) / 60, max(0, total) % 60)
    }

    /// Large-display form without the leading zero: "4:59", "24:12", "100:00".
    var bigClockString: String {
        let total = Int(rounded(.up))
        return String(format: "%d:%02d", max(0, total) / 60, max(0, total) % 60)
    }
}
