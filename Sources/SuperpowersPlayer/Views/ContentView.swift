import SwiftUI

struct ContentView: View {
    @State private var viewModel = PlayerViewModel()

    var body: some View {
        HSplitView {
            // Left: Video player + controls
            VStack(spacing: 0) {
                if viewModel.currentVideo != nil {
                    VideoPlayerView(player: viewModel.player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    ControlsView(
                        isPlaying: viewModel.isPlaying,
                        currentTime: viewModel.currentTime,
                        duration: viewModel.duration,
                        playbackSpeed: viewModel.playbackSpeed,
                        onTogglePlayPause: { viewModel.togglePlayPause() },
                        onSeek: { viewModel.seek(to: $0) },
                        onIncreaseSpeed: { viewModel.increaseSpeed() },
                        onDecreaseSpeed: { viewModel.decreaseSpeed() }
                    )
                } else {
                    // Welcome state
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.secondary)
                        Text("SuperpowersPlayer")
                            .font(.title)
                        Text("Open a video file or folder to get started")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Button("Open File...") {
                                viewModel.openFile()
                            }
                            Button("Open Folder...") {
                                viewModel.openFolder()
                            }
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 500)

            // Right: Playlist sidebar
            PlaylistView(
                playlist: viewModel.playlist,
                currentVideo: viewModel.currentVideo,
                onSelect: { viewModel.selectVideo($0) }
            )
        }
        .frame(minWidth: 800, minHeight: 500)
        .onReceive(NotificationCenter.default.publisher(for: .openFile)) { _ in
            viewModel.openFile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFolder)) { _ in
            viewModel.openFolder()
        }
    }
}
