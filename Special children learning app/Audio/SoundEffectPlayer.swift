import Foundation
import AVFoundation

final class SoundEffectPlayer {
    static let shared = SoundEffectPlayer()
    private var audioPlayer: AVAudioPlayer?
    private let speech = AVSpeechSynthesizer()

    private init() {}

    func playWaWa() {
        if playBundledIfAvailable() {
            return
        }

        let utterance = AVSpeechUtterance(string: "wa wa")
        utterance.rate = 0.45
        utterance.pitchMultiplier = 1.15
        utterance.volume = 0.5
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speech.speak(utterance)
    }

    func stopAll() {
        audioPlayer?.stop()
        audioPlayer = nil
        if speech.isSpeaking {
            speech.stopSpeaking(at: .immediate)
        }
    }

    private func playBundledIfAvailable() -> Bool {
        let candidates: [(String, String)] = [
            ("wawa", "wav"),
            ("wawa", "mp3"),
            ("wawa", "aiff"),
            ("thumbnail_appear", "wav"),
            ("thumbnail_appear", "mp3"),
            ("thumbnail_appear", "aiff")
        ]

        for (name, ext) in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    audioPlayer = player
                    player.prepareToPlay()
                    player.play()
                    return true
                } catch {
                    continue
                }
            }
        }
        return false
    }
}

final class SoundPlayer: ObservableObject {
    static let shared = SoundPlayer()

    private var player: AVAudioPlayer?
    
    func playWhoosh(volume: Float = 1.0, rate: Float = 1.0) {
        guard let url = Bundle.main.url(forResource: "whoosh", withExtension: "wav") ??
                        Bundle.main.url(forResource: "whoosh", withExtension: "mp3") else {
            print("whoosh file not found in bundle")
            return
        }
        do {
            // Optional: ensure playback even in Silent Mode (adjust as needed)
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.enableRate = true
            player?.volume = volume
            player?.rate = rate // 0.5 = slower, 1.0 = normal, 1.5 = faster
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("Audio error:", error)
        }
    }
}
