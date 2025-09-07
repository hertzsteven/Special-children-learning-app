//
//  AudioPlaybackManager.swift
//  Special children learning app
//
//  Created by AI Assistant on 12/19/24.
//

import Foundation
import AVFoundation

@MainActor
class AudioPlaybackManager: ObservableObject {
    static let shared = AudioPlaybackManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var isInitialized = false
    
    @Published var isPlaying = false
    @Published var currentAudioURL: URL?
    
    private init() {}
    
    // Configure audio session for playback
    func setupAudioSession() {
        guard !isInitialized else { return }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
            isInitialized = true
            print("✅ AudioPlaybackManager: Audio session configured")
        } catch {
            print("❌ AudioPlaybackManager: Failed to configure audio session: \(error)")
        }
    }
    
    // Play audio from URL with optional completion
    func playAudio(from url: URL, completion: (() -> Void)? = nil) {
        setupAudioSession()
        
        // Stop any currently playing audio
        stopAudio()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = AudioPlayerDelegate(completion: completion)
            audioPlayer?.prepareToPlay()
            
            if audioPlayer?.play() == true {
                isPlaying = true
                currentAudioURL = url
                print("🔊 AudioPlaybackManager: Playing audio from \(url.lastPathComponent)")
            } else {
                print("❌ AudioPlaybackManager: Failed to start audio playback")
            }
        } catch {
            print("❌ AudioPlaybackManager: Error creating audio player: \(error)")
        }
    }
    
    // Play audio for a specific media item
    func playAudioForMediaItem(_ mediaItem: SavedMediaItem, completion: (() -> Void)? = nil) {
        guard let audioURL = mediaItem.audioRecordingURL else {
            print("📝 AudioPlaybackManager: No audio recording for media item: \(mediaItem.customName)")
            completion?()
            return
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("❌ AudioPlaybackManager: Audio file not found: \(audioURL.path)")
            completion?()
            return
        }
        
        playAudio(from: audioURL, completion: completion)
    }
    
    // Stop current audio playback
    func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentAudioURL = nil
    }
    
    // Pause/resume audio
    func pauseAudio() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    func resumeAudio() {
        audioPlayer?.play()
        isPlaying = true
    }
    
    // Clean up
    func cleanup() {
        stopAudio()
        if isInitialized {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                isInitialized = false
            } catch {
                print("❌ AudioPlaybackManager: Failed to deactivate audio session: \(error)")
            }
        }
    }
}

// MARK: - Audio Player Delegate
private class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let completion: (() -> Void)?
    
    init(completion: (() -> Void)?) {
        self.completion = completion
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            AudioPlaybackManager.shared.isPlaying = false
            AudioPlaybackManager.shared.currentAudioURL = nil
            completion?()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ AudioPlaybackManager: Decode error: \(error?.localizedDescription ?? "Unknown")")
        Task { @MainActor in
            AudioPlaybackManager.shared.isPlaying = false
            AudioPlaybackManager.shared.currentAudioURL = nil
            completion?()
        }
    }
}