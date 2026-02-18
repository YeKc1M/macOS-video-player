import SwiftUI

struct PlaylistView: View {
    let playlist: [VideoFile]
    let currentVideo: VideoFile?
    let videoDurations: [URL: Double]
    let currentTime: Double
    let currentVideoURL: URL?
    let onSelect: (VideoFile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Playlist")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            if playlist.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "film.stack")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No videos")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Open a file or folder to begin")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(playlist, selection: Binding<VideoFile.ID?>(
                        get: { currentVideo?.id },
                        set: { id in
                            if let id, let video = playlist.first(where: { $0.id == id }) {
                                onSelect(video)
                            }
                        }
                    )) { video in
                        HStack {
                            Image(systemName: currentVideo?.id == video.id ? "play.fill" : "film")
                                .foregroundStyle(currentVideo?.id == video.id ? .blue : .secondary)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(video.name)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                if let duration = videoDurations[video.url] {
                                    let progress = video.url == currentVideoURL
                                        ? currentTime
                                        : ProgressStore.load(for: video.url)
                                    Text("\(formatTime(progress)) / \(formatTime(duration))")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listStyle(.sidebar)
                    .onAppear {
                        if let currentVideo {
                            proxy.scrollTo(currentVideo.id, anchor: .center)
                        }
                    }
                    .onChange(of: currentVideo) { _, newVideo in
                        if let newVideo {
                            withAnimation {
                                proxy.scrollTo(newVideo.id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
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
