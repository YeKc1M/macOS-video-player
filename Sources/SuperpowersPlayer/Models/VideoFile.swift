import Foundation
import UniformTypeIdentifiers

struct VideoFile: Identifiable, Hashable {
    let id: URL
    let name: String
    let url: URL

    init(url: URL) {
        self.id = url
        self.name = url.lastPathComponent
        self.url = url
    }

    /// Supported video UTTypes for NSOpenPanel filtering
    static let supportedTypes: [UTType] = [.movie, .video, .mpeg4Movie, .quickTimeMovie]

    /// Supported file extensions for folder scanning
    static let supportedExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv"]

    /// Check if a URL points to a supported video file
    static func isVideoFile(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    /// Scan a directory for video files, sorted by name
    static func scanDirectory(_ url: URL) -> [VideoFile] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return [] }

        var files: [VideoFile] = []
        for case let fileURL as URL in enumerator {
            if isVideoFile(fileURL) {
                files.append(VideoFile(url: fileURL))
            }
        }
        return files.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
