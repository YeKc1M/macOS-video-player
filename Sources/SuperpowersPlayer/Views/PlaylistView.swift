import SwiftUI

struct PlaylistView: View {
    let playlist: [VideoFile]
    let currentVideo: VideoFile?
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
                        Text(video.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
    }
}
