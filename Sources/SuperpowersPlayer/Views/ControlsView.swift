import SwiftUI

struct ControlsView: View {
    let isPlaying: Bool
    let currentTime: Double
    let duration: Double
    let playbackSpeed: Float
    let onTogglePlayPause: () -> Void
    let onSeek: (Double) -> Void
    let onIncreaseSpeed: () -> Void
    let onDecreaseSpeed: () -> Void

    @State private var isSeeking = false
    @State private var seekTime: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            // Seek bar
            Slider(
                value: Binding(
                    get: { isSeeking ? seekTime : currentTime },
                    set: { newValue in
                        seekTime = newValue
                        isSeeking = true
                    }
                ),
                in: 0...max(duration, 0.01),
                onEditingChanged: { editing in
                    if !editing {
                        onSeek(seekTime)
                        isSeeking = false
                    }
                }
            )

            HStack {
                // Play/Pause button
                Button(action: onTogglePlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])

                // Time display
                Text("\(formatTime(isSeeking ? seekTime : currentTime)) / \(formatTime(duration))")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                // Speed controls
                HStack(spacing: 4) {
                    Button(action: onDecreaseSpeed) {
                        Image(systemName: "minus")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .disabled(playbackSpeed <= 0.1)

                    Text(String(format: "%.1fx", playbackSpeed))
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 45)

                    Button(action: onIncreaseSpeed) {
                        Image(systemName: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .disabled(playbackSpeed >= 4.0)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
