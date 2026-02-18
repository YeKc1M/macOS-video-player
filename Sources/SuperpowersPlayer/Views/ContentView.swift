import SwiftUI

struct ContentView: View {
    @State private var viewModel = PlayerViewModel()
    @State private var showingSettings = false
    @State private var keyMonitor: Any?

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
                        volume: viewModel.volume,
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
                videoDurations: viewModel.videoDurations,
                currentTime: viewModel.currentTime,
                currentVideoURL: viewModel.currentVideo?.url,
                onSelect: { viewModel.selectVideo($0) }
            )
        }
        .frame(minWidth: 800, minHeight: 500)
        .focusedValue(\.playerActions, PlayerActions(
            openFile: { viewModel.openFile() },
            openFolder: { viewModel.openFolder() },
            viewModel: viewModel
        ))
        .sheet(isPresented: $showingSettings) {
            ShortcutSettingsView(
                bindings: viewModel.keyBindings,
                onSave: { viewModel.updateKeyBindings($0) },
                onReset: { viewModel.resetKeyBindings() }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .showShortcutSettings)) { _ in
            showingSettings = true
        }
        .onAppear { installKeyMonitor() }
        .onDisappear { removeKeyMonitor() }
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if let responder = NSApp.keyWindow?.firstResponder,
               responder is NSText {
                return event
            }
            if NSApp.keyWindow?.attachedSheet != nil {
                return event
            }
            if viewModel.handleKeyCode(event.keyCode) {
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}
