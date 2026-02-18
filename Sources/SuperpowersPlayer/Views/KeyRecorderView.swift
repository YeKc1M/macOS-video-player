import AppKit
import SwiftUI

struct KeyRecorderView: View {
    let currentBinding: StoredKeyBinding
    let onRecord: (StoredKeyBinding) -> Void

    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        Button(action: { startRecording() }) {
            Text(isRecording ? "Press a key…" : currentBinding.displayName)
                .frame(minWidth: 100)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .foregroundStyle(isRecording ? .blue : .primary)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape cancels
                stopRecording()
                return nil
            }
            let displayName = StoredKeyBinding.displayName(
                forKeyCode: event.keyCode,
                characters: event.charactersIgnoringModifiers
            )
            let binding = StoredKeyBinding(
                keyCode: Int(event.keyCode),
                displayName: displayName
            )
            onRecord(binding)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
