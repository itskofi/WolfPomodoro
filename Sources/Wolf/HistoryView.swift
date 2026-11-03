import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: SessionStore

    private var days: [(date: Date, focus: TimeInterval)] { store.dailyFocusTotals(days: 7) }
    private var peak: TimeInterval { max(days.map(\.focus).max() ?? 0, 30 * 60) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BigDigits(text: store.todayFocusSeconds < 60 ? "0m" : store.todayFocusSeconds.durationString,
                      size: 56, color: Theme.onGround)
            Text(summary)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.onGround.opacity(0.55))
                .padding(.top, 2)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days, id: \.date) { day in
                    let today = Calendar.current.isDateInToday(day.date)
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(today ? Theme.accent : Theme.accent.opacity(0.28))
                            .frame(height: max(8, 120 * day.focus / peak))
                        Text(weekday(day.date))
                            .font(.system(size: 11, weight: today ? .heavy : .semibold))
                            .foregroundStyle(Theme.onGround.opacity(today ? 1 : 0.45))
                    }
                    .frame(maxWidth: .infinity)
                    .help("\(day.focus.durationString)")
                }
            }
            .frame(height: 144, alignment: .bottom)
            .padding(.top, 26)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summary: String {
        let sessions = store.todayFocusSessions
        var parts = ["today", "\(sessions) session\(sessions == 1 ? "" : "s")"]
        if store.weekFocusSeconds >= 60 { parts.append("\(store.weekFocusSeconds.durationString) this week") }
        return parts.joined(separator: " · ")
    }

    private func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }
}
