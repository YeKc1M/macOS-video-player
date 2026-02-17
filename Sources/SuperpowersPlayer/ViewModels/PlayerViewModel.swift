import AVFoundation
import AVKit
import Combine
import SwiftUI

@Observable
@MainActor
final class PlayerViewModel {
    // MARK: - Observable State
    var playlist: [VideoFile] = []
    var currentVideo: VideoFile?
    var isPlaying: Bool = false
    var currentTime: Double = 0
    var duration: Double = 0
    var playbackSpeed: Float = 1.0
    var volume: Float = 1.0
    var videoDurations: [URL: Double] = [:]

    // MARK: - Non-observable AVFoundation objects
    @ObservationIgnored private(set) var player = AVPlayer()
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var saveTimer: Timer?

    init() {
        // Save progress periodically every 0.5 seconds
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveCurrentProgress()
            }
        }

        // Save progress on app termination
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveCurrentProgress()
            }
        }
    }

    // MARK: - File Opening

    func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = VideoFile.supportedTypes

        if panel.runModal() == .OK, let url = panel.url {
            let video = VideoFile(url: url)
            playlist = [video]
            selectVideo(video)
            Task { [weak self] in
                await self?.loadPlaylistDurations()
            }
        }
    }

    func openFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select a folder containing video files"

        if panel.runModal() == .OK, let url = panel.url {
            let files = VideoFile.scanDirectory(url)
            playlist = files
            if let first = files.first {
                selectVideo(first)
            }
            Task { [weak self] in
                await self?.loadPlaylistDurations()
            }
        }
    }

    // MARK: - Video Selection

    func selectVideo(_ video: VideoFile) {
        // Save progress for current video before switching
        saveCurrentProgress()

        // Set new current video
        currentVideo = video

        // Load into player
        let item = AVPlayerItem(url: video.url)
        player.replaceCurrentItem(with: item)

        // Reset state
        currentTime = 0
        duration = 0
        isPlaying = false

        // Remove old observers
        cleanupObservers()

        // Observe item status to get duration and restore position
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self, item.status == .readyToPlay else { return }
                let dur = item.duration.seconds
                if dur.isFinite {
                    self.duration = dur
                }
                // Restore saved position
                let savedTime = ProgressStore.load(for: video.url)
                if savedTime > 0 && savedTime < dur {
                    let target = CMTime(seconds: savedTime, preferredTimescale: 600)
                    self.player.seek(to: target)
                    self.currentTime = savedTime
                }
                // Auto-play
                self.play()
            }
        }

        // Periodic time observer (0.5s interval)
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let seconds = time.seconds
                if seconds.isFinite {
                    self.currentTime = seconds
                }
            }
        }

        // End-of-playback observer
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Clear progress since video finished
                if let video = self.currentVideo {
                    ProgressStore.clear(for: video.url)
                }
                // Auto-advance to next video
                self.playNext()
            }
        }
    }

    // MARK: - Playback Controls

    func play() {
        player.play()
        player.rate = playbackSpeed
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to time: Double) {
        let clamped = max(0, min(time, duration))
        let target = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: target)
        currentTime = clamped
    }

    func increaseSpeed() {
        let newSpeed = min(playbackSpeed + 0.1, 4.0)
        setSpeed(newSpeed)
    }

    func decreaseSpeed() {
        let newSpeed = max(playbackSpeed - 0.1, 0.1)
        setSpeed(newSpeed)
    }

    private func setSpeed(_ speed: Float) {
        playbackSpeed = (speed * 10).rounded() / 10  // Round to 1 decimal
        if isPlaying {
            player.rate = playbackSpeed
        }
    }

    // MARK: - Volume Control

    func increaseVolume() {
        let newVolume = min(volume + 0.05, 1.0)
        volume = (newVolume * 20).rounded() / 20
        player.volume = volume
    }

    func decreaseVolume() {
        let newVolume = max(volume - 0.05, 0.0)
        volume = (newVolume * 20).rounded() / 20
        player.volume = volume
    }

    // MARK: - Playlist Navigation

    func playNext() {
        guard !playlist.isEmpty, let currentVideo else { return }
        guard let index = playlist.firstIndex(of: currentVideo) else { return }
        let nextIndex = (index + 1) % playlist.count
        selectVideo(playlist[nextIndex])
    }

    func playPrevious() {
        guard !playlist.isEmpty, let currentVideo else { return }
        guard let index = playlist.firstIndex(of: currentVideo) else { return }
        let previousIndex = (index - 1 + playlist.count) % playlist.count
        selectVideo(playlist[previousIndex])
    }

    // MARK: - Duration Loading

    func loadPlaylistDurations() async {
        let videos = playlist
        let results = await withTaskGroup(of: (URL, Double?).self) { group in
            for video in videos {
                group.addTask { [weak self] in
                    guard self != nil else { return (video.url, nil) }
                    do {
                        let asset = AVURLAsset(url: video.url)
                        let duration = try await asset.load(.duration)
                        let seconds = duration.seconds
                        if seconds.isFinite {
                            return (video.url, seconds)
                        }
                        return (video.url, nil)
                    } catch {
                        return (video.url, nil)
                    }
                }
            }
            var collected: [URL: Double] = [:]
            for await (url, dur) in group {
                if let dur {
                    collected[url] = dur
                }
            }
            return collected
        }
        videoDurations = results
    }

    // MARK: - Progress Persistence

    private func saveCurrentProgress() {
        guard let video = currentVideo else { return }
        guard currentTime > 0 && currentTime.isFinite else { return }
        ProgressStore.save(time: currentTime, for: video.url)
    }

    // MARK: - Cleanup

    private func cleanupObservers() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        statusObservation?.invalidate()
        statusObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }

    deinit {
        saveTimer?.invalidate()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }
}
