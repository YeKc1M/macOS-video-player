import SwiftUI

struct ShortcutSettingsView: View {
    @State var bindings: [PlayerAction: StoredKeyBinding]
    let onSave: ([PlayerAction: StoredKeyBinding]) -> Void
    let onReset: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("Keyboard Shortcuts")
                .font(.headline)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(PlayerAction.allCases) { action in
                        HStack {
                            Text(action.displayName)
                                .frame(width: 140, alignment: .trailing)

                            KeyRecorderView(
                                currentBinding: bindings[action] ?? action.defaultBinding
                            ) { newBinding in
                                bindings[action] = newBinding
                                onSave(bindings)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 16)
            }

            Divider()

            HStack {
                Button("Reset to Defaults") {
                    bindings = Dictionary(
                        uniqueKeysWithValues: PlayerAction.allCases.map {
                            ($0, $0.defaultBinding)
                        }
                    )
                    onReset()
                }

                Spacer()

                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 400, height: 420)
    }
}
