import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: SessionStore

    private var days: [(date: Date, focus: TimeInterval)] { store.dailyFocusTotals(days: 7) }
    private var peak: TimeInterval { max(days.map(\.focus).max() ?? 0, 1) }

    var body: some View {
        VStack(spacing: 10) {
            Card(title: "Today") {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(store.todayFocusSeconds.durationString)
                        .font(.system(size: 34, weight: .light, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("focused")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textDim)
                }
                statLine
            }

            Card(title: "Last 7 days") {
                chart
                Divider().overlay(Theme.surfaceRim).padding(.vertical, 2)
                grid
            }

            if store.records.isEmpty {
                Text("No sessions yet. Finish a focus session and it lands here.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var statLine: some View {
        var parts = ["\(store.todayFocusSessions) session\(store.todayFocusSessions == 1 ? "" : "s")"]
        if store.todayBreakSeconds >= 60 { parts.append("\(store.todayBreakSeconds.durationString) break") }
        if store.todayPartialSessions > 0 { parts.append("\(store.todayPartialSessions) partial") }
        parts.append("week \(store.weekFocusSeconds.durationString)")
        return Text(parts.joined(separator: "  ·  "))
            .font(.system(size: 10.5))
            .foregroundStyle(Theme.textDim)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chart: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(days, id: \.date) { day in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isToday(day.date) ? Theme.accent : Theme.accent.opacity(0.28))
                        .frame(maxWidth: .infinity)
                        .frame(height: max(3, 62 * day.focus / peak))
                    Text(weekdayInitial(day.date))
                        .font(.system(size: 9, weight: isToday(day.date) ? .bold : .regular))
                        .foregroundStyle(isToday(day.date) ? Theme.text : Theme.textFaint)
                }
            }
        }
        .frame(height: 80, alignment: .bottom)
    }

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), alignment: .leading),
                      GridItem(.flexible(), alignment: .leading)],
            spacing: 6
        ) {
            ForEach(days.reversed(), id: \.date) { day in
                HStack(spacing: 6) {
                    Text(dayLabel(day.date))
                        .foregroundStyle(Theme.textDim)
                        .frame(width: 50, alignment: .leading)
                    Text(day.focus.durationString)
                        .monospacedDigit()
                        .foregroundStyle(day.focus > 0 ? Theme.text : Theme.textFaint)
                }
                .font(.system(size: 11))
            }
        }
    }

    private func isToday(_ date: Date) -> Bool { Calendar.current.isDateInToday(date) }

    private func weekdayInitial(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }

    private func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yest." }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d"
        return formatter.string(from: date)
    }
}
