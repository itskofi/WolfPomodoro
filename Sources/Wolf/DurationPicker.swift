import SwiftUI

/// A dropdown of preset minute values with a "Custom…" entry that swaps the dropdown for
/// a number field in the same spot. Sits in the shared control column so every settings
/// row shares one trailing edge.
struct DurationPicker: View {
    let label: String
    @Binding var minutes: Int
    let presets: [Int]

    @State private var customMode = false
    @State private var customText = ""
    @FocusState private var fieldFocused: Bool

    private let customTag = -1

    var body: some View {
        Row(label: label) {
            if customMode {
                HStack(spacing: 5) {
                    TextField("", text: $customText)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .focused($fieldFocused)
                        .onSubmit(commit)
                        .frame(maxWidth: .infinity)
                    Text("min")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textDim)
                    Button("Set", action: commit)
                        .buttonStyle(.borderless)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            } else {
                Picker("", selection: selection) {
                    ForEach(presets, id: \.self) { preset in
                        Text("\(preset) min").tag(preset)
                    }
                    if !presets.contains(minutes) {
                        Text("\(minutes) min (custom)").tag(minutes)
                    }
                    Text("Custom…").tag(customTag)
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { customText = String(minutes) }
    }

    private var selection: Binding<Int> {
        Binding(
            get: { minutes },
            set: { newValue in
                if newValue == customTag {
                    customText = String(minutes)
                    customMode = true
                    fieldFocused = true
                } else {
                    minutes = newValue
                }
            }
        )
    }

    private func commit() {
        if let value = Int(customText.trimmingCharacters(in: .whitespaces)) {
            minutes = min(max(value, 1), 180)
        }
        customText = String(minutes)
        customMode = false
    }
}
