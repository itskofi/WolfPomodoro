import SwiftUI

enum Tab: String, CaseIterable {
    case timer = "Timer", history = "History", settings = "Settings"

    /// Declared heights let the panel resize smoothly between tabs instead of the
    /// content being torn down and rebuilt at a new size.
    var panelHeight: CGFloat {
        switch self {
        case .timer:    return 296
        case .history:  return 356
        case .settings: return 452
        }
    }
}

struct PopoverView: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var settings: Settings
    @ObservedObject var store: SessionStore
    let onClose: () -> Void
    let onQuit: () -> Void

    @State private var tab: Tab = .timer
    @ObservedObject private var appearance = AppearanceBridge.shared

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            tabBar
            Divider().overlay(Theme.surfaceRim)

            // All three tabs stay mounted and cross-fade; only the panel height animates.
            // Swapping them with a switch rebuilt the view and read as a page refresh.
            ZStack(alignment: .top) {
                tabContent(.timer) {
                    TimerTab(timer: timer, settings: settings).padding(14)
                }
                tabContent(.history) {
                    ScrollView { HistoryView(store: store).padding(14) }
                        .scrollIndicators(.never)
                }
                tabContent(.settings) {
                    ScrollView {
                        SettingsView(settings: settings, timer: timer, store: store).padding(14)
                    }
                    .scrollIndicators(.never)
                }
            }
            .frame(width: Theme.popoverWidth, height: tab.panelHeight, alignment: .top)
            .clipped()
        }
        .frame(width: Theme.popoverWidth)
        .background(Theme.background)
        .environment(\.colorScheme, appearance.scheme(for: settings.appearance))
        .animation(.easeInOut(duration: 0.22), value: tab)
    }

    @ViewBuilder
    private func tabContent<Content: View>(_ item: Tab, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: Theme.popoverWidth, alignment: .top)
            .opacity(tab == item ? 1 : 0)
            .allowsHitTesting(tab == item)
    }

    private var titleBar: some View {
        HStack(spacing: 8) {
            Button(action: onClose) { Text("✕") }
                .buttonStyle(ChromeButtonStyle(hoverTint: Color(red: 0.91, green: 0.35, blue: 0.31)))
                .help("Close")

            Spacer()

            HStack(spacing: 6) {
                WolfMark(color: Theme.accent(forBreak: timer.phase.isBreak))
                    .frame(width: 13, height: 13)
                Text("WOLF")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(Theme.textDim)
            }

            Spacer()

            Button(action: onQuit) { Text("⏻") }
                .buttonStyle(ChromeButtonStyle(hoverTint: Theme.textDim))
                .help("Quit Wolf")
        }
        .padding(.horizontal, 11)
        .padding(.top, 10)
        .padding(.bottom, 9)
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(Tab.allCases, id: \.self) { item in
                TabButton(item: item, isSelected: tab == item) {
                    withAnimation(.easeOut(duration: 0.13)) { tab = item }
                }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8).fill(Theme.wash)
        )
        .padding(.horizontal, 11)
        .padding(.bottom, 10)
    }
}

private struct TabButton: View {
    let item: Tab
    let isSelected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(item.rawValue)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected || hovering ? Theme.text : Theme.textDim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Theme.surface : (hovering ? Theme.wash : Color.clear))
                )
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

/// Minimal wolf head: two ears tapering to a muzzle, drawn as a single mark.
struct WolfMark: View {
    var color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Path { p in
                p.move(to: CGPoint(x: w * 0.10, y: h * 0.00))
                p.addLine(to: CGPoint(x: w * 0.32, y: h * 0.26))
                p.addLine(to: CGPoint(x: w * 0.68, y: h * 0.26))
                p.addLine(to: CGPoint(x: w * 0.90, y: h * 0.00))
                p.addLine(to: CGPoint(x: w * 0.94, y: h * 0.55))
                p.addLine(to: CGPoint(x: w * 0.50, y: h * 1.00))
                p.addLine(to: CGPoint(x: w * 0.06, y: h * 0.55))
                p.closeSubpath()
            }
            .fill(color)
        }
    }
}

/// The signature element: a stopwatch bezel of 60 ticks. Ticks still to come are lit in
/// the phase colour; spent ticks fall back to the rim colour, so the dial empties the way
/// a real timer does.
struct TickDial: View {
    let progress: Double
    let accent: Color
    var diameter: CGFloat = 150

    var body: some View {
        ZStack {
            ForEach(0..<60, id: \.self) { index in
                let spent = Double(index) / 60 < progress
                let isMajor = index % 5 == 0
                Capsule()
                    .fill(spent ? Theme.surfaceRim : accent)
                    .frame(width: isMajor ? 2 : 1.4, height: isMajor ? 9 : 5.5)
                    .offset(y: -diameter / 2 + 6)
                    .rotationEffect(.degrees(Double(index) * 6))
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(.linear(duration: 0.3), value: progress)
    }
}

struct TimerTab: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var settings: Settings

    private var accent: Color { Theme.accent(forBreak: timer.phase.isBreak) }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                TickDial(progress: timer.progress, accent: accent)
                VStack(spacing: 5) {
                    Text(timer.remaining.clockString)
                        .font(Theme.clockFont(38))
                        .foregroundStyle(Theme.text)
                    Text(timer.phase.title.uppercased())
                        .font(Theme.eyebrow(9))
                        .tracking(2)
                        .foregroundStyle(accent)
                }
            }

            SessionDots(done: timer.completedFocusSessions, total: settings.intervals, accent: accent)

            VStack(spacing: 7) {
                Button(primaryLabel, action: timer.toggle)
                    .buttonStyle(WolfPrimaryButtonStyle(tint: accent))
                    .keyboardShortcut(.space, modifiers: [])

                HStack(spacing: 7) {
                    Button("Skip", action: timer.skip)
                    Button("Reset", action: timer.reset)
                }
                .buttonStyle(WolfGhostButtonStyle())
            }
            .padding(.top, 2)
        }
    }

    private var primaryLabel: String {
        switch timer.state {
        case .running: return "Pause"
        case .paused:  return "Resume"
        case .idle:    return timer.phase.isBreak ? "Start \(timer.phase.title)" : "Start Focus"
        }
    }
}

private struct SessionDots: View {
    let done: Int
    let total: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(1, total), id: \.self) { index in
                Circle()
                    .fill(index < done ? accent : Theme.surfaceRim)
                    .frame(width: 6, height: 6)
            }
        }
        .help("Focus sessions completed before the long break")
    }
}
