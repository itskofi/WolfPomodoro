import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var store: SessionStore
    let onQuit: () -> Void

    @State private var confirmClear = false

    var body: some View {
        Form {
            Section {
                DurationPicker(label: "Focus", minutes: $settings.focusMinutes,
                               presets: Settings.focusPresets)
                DurationPicker(label: "Short break", minutes: $settings.shortBreakMinutes,
                               presets: Settings.shortBreakPresets)
                DurationPicker(label: "Long break", minutes: $settings.longBreakMinutes,
                               presets: Settings.longBreakPresets)
                Picker("Long break after", selection: $settings.intervals) {
                    ForEach(1...12, id: \.self) { Text($0 == 1 ? "1 session" : "\($0) sessions").tag($0) }
                }
            }

            Section {
                Toggle("Auto-start breaks", isOn: $settings.autoStartBreaks)
                Toggle("Auto-start focus", isOn: $settings.autoStartFocus)
                Toggle("Play sound", isOn: $settings.playSound)
                Toggle("Full-screen break", isOn: $settings.showOverlay)
            }

            Section {
                Picker("Menu bar", selection: $settings.boxDirection) {
                    ForEach(BoxDirection.allCases) { Text($0.label).tag($0) }
                }
            } footer: {
                Text(settings.boxDirection.explanation)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                TextField("Focus ends", text: $settings.focusEndMessage)
                TextField("Break ends", text: $settings.breakEndMessage)
            }

            Section {
                LabeledContent("Stored sessions", value: "\(store.records.count)")
                Button(confirmClear ? "Click Again to Clear" : "Clear History…") {
                    if confirmClear { store.clear(); confirmClear = false } else { confirmClear = true }
                }
                .foregroundStyle(.red)
                .disabled(store.records.isEmpty)
            }

            Section {
                Button("Quit Wolf", action: onQuit)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .controlSize(.small)
        .onChange(of: confirmClear) { _, armed in
            guard armed else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { confirmClear = false }
        }
        .onChange(of: settings.focusMinutes) { _, _ in timer.refreshIdleDuration() }
        .onChange(of: settings.shortBreakMinutes) { _, _ in timer.refreshIdleDuration() }
        .onChange(of: settings.longBreakMinutes) { _, _ in timer.refreshIdleDuration() }
    }
}
