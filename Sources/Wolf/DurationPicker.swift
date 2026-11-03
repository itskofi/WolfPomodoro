import SwiftUI

/// A Form-native picker of preset minute values with a "Custom…" entry that swaps the
/// menu for a number field in the same row.
struct DurationPicker: View {
    let label: String
    @Binding var minutes: Int
    let presets: [Int]

    @State private var customMode = false
    @State private var customText = ""
    @FocusState private var fieldFocused: Bool

    private let customTag = -1

    var body: some View {
        if customMode {
            LabeledContent(label) {
                HStack(spacing: 6) {
                    TextField("", text: $customText)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 48)
                        .focused($fieldFocused)
                        .onSubmit(commit)
                    Text("min").foregroundStyle(.secondary)
                    Button("Done", action: commit)
                }
            }
        } else {
            Picker(label, selection: selection) {
                ForEach(presets, id: \.self) { Text("\($0) min").tag($0) }
                if !presets.contains(minutes) {
                    Text("\(minutes) min").tag(minutes)
                }
                Divider()
                Text("Custom…").tag(customTag)
            }
        }
    }

    private var selection: Binding<Int> {
        Binding(
            get: { minutes },
            set: { newValue in
                if newValue == customTag {
                    customText = String(minutes)
                    customMode = true
                    DispatchQueue.main.async { fieldFocused = true }
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
        customMode = false
    }
}
