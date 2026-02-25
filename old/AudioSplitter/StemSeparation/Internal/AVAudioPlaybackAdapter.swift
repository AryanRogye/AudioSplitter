import AVFoundation
import Foundation

final class AVAudioPlaybackAdapter: NSObject, AudioPlaybackControlling, AVAudioPlayerDelegate {
    var onPlaybackStateChanged: ((URL?) -> Void)?

    private var audioPlayer: AVAudioPlayer?
    private(set) var currentlyPlayingURL: URL? {
        didSet {
            if oldValue != currentlyPlayingURL {
                onPlaybackStateChanged?(currentlyPlayingURL)
            }
        }
    }

    func isPlaying(_ url: URL?) -> Bool {
        guard let url else { return false }
        return currentlyPlayingURL == url
    }

    func togglePlayback(for url: URL?) throws {
        guard let url else { return }

        if currentlyPlayingURL == url {
            stopPlayback()
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            player.play()

            audioPlayer = player
            currentlyPlayingURL = url
        } catch {
            stopPlayback()
            throw error
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        currentlyPlayingURL = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopPlayback()
    }
}
