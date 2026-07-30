import Foundation
import Combine

/// Which way the menu bar box tracks the phase.
enum BoxDirection: String, CaseIterable, Identifiable {
    case emptiesOut, fillsUp
    var id: String { rawValue }

    var label: String {
        switch self {
        case .emptiesOut: return "Empties out"
        case .fillsUp: return "Fills up"
        }
    }

    var explanation: String {
        switch self {
        case .emptiesOut: return "Box starts full and drains as time runs out."
        case .fillsUp: return "Box starts empty and fills as time is spent."
        }
    }
}

/// UserDefaults-backed settings. Every property change republishes so views refresh.
final class Settings: ObservableObject {
    static let shared = Settings()

    static let focusPresets = [15, 25, 30, 45, 50, 60, 90]
    static let shortBreakPresets = [3, 5, 10, 15, 20]
    static let longBreakPresets = [10, 15, 20, 30, 45]

    private let defaults = UserDefaults.standard

    private func int(_ key: String, _ fallback: Int) -> Int {
        defaults.object(forKey: key) == nil ? fallback : defaults.integer(forKey: key)
    }
    private func bool(_ key: String, _ fallback: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
    }
    private func string(_ key: String, _ fallback: String) -> String {
        defaults.string(forKey: key) ?? fallback
    }

    @Published var focusMinutes: Int { didSet { defaults.set(focusMinutes, forKey: "focusMinutes") } }
    @Published var shortBreakMinutes: Int { didSet { defaults.set(shortBreakMinutes, forKey: "shortBreakMinutes") } }
    @Published var longBreakMinutes: Int { didSet { defaults.set(longBreakMinutes, forKey: "longBreakMinutes") } }
    @Published var intervals: Int { didSet { defaults.set(intervals, forKey: "intervals") } }

    @Published var autoStartBreaks: Bool { didSet { defaults.set(autoStartBreaks, forKey: "autoStartBreaks") } }
    @Published var autoStartFocus: Bool { didSet { defaults.set(autoStartFocus, forKey: "autoStartFocus") } }
    @Published var playSound: Bool { didSet { defaults.set(playSound, forKey: "playSound") } }
    @Published var showOverlay: Bool { didSet { defaults.set(showOverlay, forKey: "showOverlay") } }

    @Published var boxDirection: BoxDirection { didSet { defaults.set(boxDirection.rawValue, forKey: "boxDirection") } }
    @Published var appearance: AppearanceMode { didSet { defaults.set(appearance.rawValue, forKey: "appearance") } }

    @Published var focusEndMessage: String { didSet { defaults.set(focusEndMessage, forKey: "focusEndMessage") } }
    @Published var breakEndMessage: String { didSet { defaults.set(breakEndMessage, forKey: "breakEndMessage") } }

    /// One-time carry-over of preferences from the pre-rename FlowClone bundle.
    private func migrateLegacyDefaults() {
        guard !defaults.bool(forKey: "didMigrateFromFlowClone"),
              let legacy = UserDefaults(suiteName: "com.local.flowclone") else { return }
        for key in ["focusMinutes", "shortBreakMinutes", "longBreakMinutes", "intervals",
                    "autoStartBreaks", "autoStartFocus", "playSound", "showOverlay",
                    "boxDirection", "appearance", "focusEndMessage", "breakEndMessage", "sessionHistory"] {
            if defaults.object(forKey: key) == nil, let value = legacy.object(forKey: key) {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: "didMigrateFromFlowClone")
    }

    private init() {
        focusMinutes = 25
        shortBreakMinutes = 5
        longBreakMinutes = 15
        intervals = 4
        autoStartBreaks = true
        autoStartFocus = false
        playSound = true
        showOverlay = true
        boxDirection = .emptiesOut
        appearance = .system
        focusEndMessage = "Focus session complete — time for a break."
        breakEndMessage = "Break over — back to focus."

        migrateLegacyDefaults()

        // Re-read persisted values after the compiler-required initialisation above.
        focusMinutes = int("focusMinutes", 25)
        shortBreakMinutes = int("shortBreakMinutes", 5)
        longBreakMinutes = int("longBreakMinutes", 15)
        intervals = int("intervals", 4)
        autoStartBreaks = bool("autoStartBreaks", true)
        autoStartFocus = bool("autoStartFocus", false)
        playSound = bool("playSound", true)
        showOverlay = bool("showOverlay", true)
        boxDirection = BoxDirection(rawValue: string("boxDirection", "emptiesOut")) ?? .emptiesOut
        appearance = AppearanceMode(rawValue: string("appearance", "system")) ?? .system
        focusEndMessage = string("focusEndMessage", focusEndMessage)
        breakEndMessage = string("breakEndMessage", breakEndMessage)
    }

    func duration(for phase: Phase) -> TimeInterval {
        switch phase {
        case .focus: return TimeInterval(focusMinutes * 60)
        case .shortBreak: return TimeInterval(shortBreakMinutes * 60)
        case .longBreak: return TimeInterval(longBreakMinutes * 60)
        }
    }
}
