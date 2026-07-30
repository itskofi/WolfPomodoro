import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var store: SessionStore

    var body: some View {
        VStack(spacing: 10) {
            Card(title: "Durations") {
                DurationPicker(label: "Focus", minutes: $settings.focusMinutes,
                               presets: Settings.focusPresets)
                DurationPicker(label: "Short break", minutes: $settings.shortBreakMinutes,
                               presets: Settings.shortBreakPresets)
                DurationPicker(label: "Long break", minutes: $settings.longBreakMinutes,
                               presets: Settings.longBreakPresets)
                Row(label: "Long break after") {
                    Picker("", selection: $settings.intervals) {
                        ForEach(1...12, id: \.self) { count in
                            Text(count == 1 ? "1 session" : "\(count) sessions").tag(count)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }
            }

            Card(title: "Behaviour") {
                Row(label: "Auto-start breaks") {
                    Toggle("", isOn: $settings.autoStartBreaks).labelsHidden()
                }
                Row(label: "Auto-start focus") {
                    Toggle("", isOn: $settings.autoStartFocus).labelsHidden()
                }
                Row(label: "Play sound") {
                    Toggle("", isOn: $settings.playSound).labelsHidden()
                }
                Row(label: "Full-screen break") {
                    Toggle("", isOn: $settings.showOverlay).labelsHidden()
                }
            }

            Card(title: "Appearance") {
                Row(label: "Theme") {
                    Picker("", selection: $settings.appearance) {
                        ForEach(AppearanceMode.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }
            }

            Card(title: "Menu bar box") {
                Row(label: "Direction") {
                    Picker("", selection: $settings.boxDirection) {
                        ForEach(BoxDirection.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }
                Text(settings.boxDirection.explanation)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Card(title: "Notification text") {
                fieldLabel("When focus ends")
                TextField("", text: $settings.focusEndMessage, axis: .vertical)
                    .lineLimit(1...3)
                fieldLabel("When a break ends")
                TextField("", text: $settings.breakEndMessage, axis: .vertical)
                    .lineLimit(1...3)
            }
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 11.5))

            Card(title: "History data") {
                Row(label: "Stored sessions") {
                    Text("\(store.records.count)")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(Theme.textDim)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                Button("Clear history") { store.clear() }
                    .buttonStyle(WolfGhostButtonStyle())
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .tint(Theme.accent)
        .onChange(of: settings.focusMinutes) { _, _ in timer.refreshIdleDuration() }
        .onChange(of: settings.shortBreakMinutes) { _, _ in timer.refreshIdleDuration() }
        .onChange(of: settings.longBreakMinutes) { _, _ in timer.refreshIdleDuration() }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(Theme.textFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
