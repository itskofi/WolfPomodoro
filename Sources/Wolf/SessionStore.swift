import Foundation
import Combine

struct SessionRecord: Codable, Identifiable {
    var id = UUID()
    var phase: Phase
    var start: Date
    var end: Date
    var plannedSeconds: TimeInterval
    var actualSeconds: TimeInterval
    /// False when the phase was ended early with Skip.
    var wasCompleted: Bool
}

/// Persisted session history. Stored as a JSON blob in UserDefaults, same as Settings,
/// so the app still writes nothing outside its own preferences.
final class SessionStore: ObservableObject {
    static let shared = SessionStore()

    private let key = "sessionHistory"
    private let retentionDays = 90
    private let maxRecords = 1000

    @Published private(set) var records: [SessionRecord] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([SessionRecord].self, from: data) {
            records = decoded
        }
        prune()
    }

    func add(_ record: SessionRecord) {
        records.append(record)
        prune()
        persist()
    }

    func clear() {
        records = []
        persist()
    }

    private func prune() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? .distantPast
        records = records.filter { $0.end >= cutoff }
        if records.count > maxRecords {
            records = Array(records.suffix(maxRecords))
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Derived stats

    private func seconds(in records: [SessionRecord], phase: Phase? = nil) -> TimeInterval {
        records.filter { phase == nil || $0.phase == phase }.reduce(0) { $0 + $1.actualSeconds }
    }

    private func records(on day: Date) -> [SessionRecord] {
        records.filter { Calendar.current.isDate($0.end, inSameDayAs: day) }
    }

    var todayFocusSeconds: TimeInterval { seconds(in: records(on: Date()), phase: .focus) }

    var todayBreakSeconds: TimeInterval {
        let today = records(on: Date())
        return seconds(in: today) - seconds(in: today, phase: .focus)
    }

    var todayFocusSessions: Int { records(on: Date()).filter { $0.phase == .focus }.count }

    var todayPartialSessions: Int {
        records(on: Date()).filter { $0.phase == .focus && !$0.wasCompleted }.count
    }

    var weekFocusSeconds: TimeInterval { dailyFocusTotals(days: 7).reduce(0) { $0 + $1.focus } }

    /// Focus seconds per day for the last `days` days, oldest first, ending today.
    func dailyFocusTotals(days: Int) -> [(date: Date, focus: TimeInterval)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (day, seconds(in: records(on: day), phase: .focus))
        }
    }
}

extension TimeInterval {
    /// "1h 40m", or "40m" under an hour, or "—" at zero.
    var durationString: String {
        let minutes = Int(self) / 60
        if minutes == 0 { return "—" }
        let hours = minutes / 60
        return hours > 0 ? "\(hours)h \(minutes % 60)m" : "\(minutes)m"
    }
}
