//
//  VideoQueuePlayerView.swift
//  Special children learning app
//
//  Created by Steven Hertz on 9/4/25.
//

import SwiftUI
import AVKit
import AVFoundation
import Photos

struct VideoQueuePlayerView: View {
    let activity: ActivityItem
    let onDismiss: () -> Void

    @State private var currentPlayer: AVPlayer?
    @State private var currentVideoIndex = 0
    @State private var currentRepeatCount = 0
    @State private var videoURLs: [URL] = []
    @State private var isPlaying = false
    @State private var isLoadingVideos = false
    @State private var videoHasEnded = false
    @State private var isWaitingForNextVideo = false

    // Thumbnail + animation
    @State private var thumbnailImages: [UIImage] = []
    @State private var revealProgress: CGFloat = 0
    @State private var hasStartedPlaying = false
    @State private var didPlayThumbnailSound = false

    @StateObject private var settings = AppSettings.shared
    @StateObject private var audioManager = AudioPlaybackManager.shared // NEW: Audio manager

    var totalVideos: Int {
        activity.videoAssets?.count ?? 0
    }
    
    var currentThumbnail: UIImage? {
        guard currentVideoIndex < thumbnailImages.count else { return nil }
        return thumbnailImages[currentVideoIndex]
    }
    
    var shouldShowThumbnail: Bool {
        return !hasStartedPlaying || (videoHasEnded && isWaitingForNextVideo)
    }
    
    // NEW: Get current video's associated media item
    private var currentMediaItem: SavedMediaItem? {
        guard let videoAssets = activity.videoAssets,
              currentVideoIndex < videoAssets.count,
              let mediaItems = activity.mediaItems else { return nil }
        
        let currentAsset = videoAssets[currentVideoIndex]
        return mediaItems.first { $0.assetIdentifier == currentAsset.localIdentifier }
    }
    
    // NEW: Get current video name
    private var currentVideoName: String? {
        if let mediaItem = currentMediaItem {
            return mediaItem.customName
        }
        // Fallback to activity-level name lookup
        guard let videoAssets = activity.videoAssets, currentVideoIndex < videoAssets.count else { return nil }
        return activity.getMediaItemName(for: videoAssets[currentVideoIndex])
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // Loading indicator
                if isLoadingVideos {
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("Loading video collection...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }

                // Full-screen video player
                if let player = currentPlayer, !isLoadingVideos, hasStartedPlaying, !isWaitingForNextVideo {
                    FullScreenSinglePlayerView(player: player)
                        .ignoresSafeArea()
                }

                // Animated thumbnail overlay (for first video and between videos)
                if shouldShowThumbnail && !isLoadingVideos {
                    if let image = currentThumbnail {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .mask(TileRevealMask(progress: revealProgress))
                            .ignoresSafeArea()
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.4)) {
                                    revealProgress = 1.0
                                }
                                if !didPlayThumbnailSound || isWaitingForNextVideo {
                                    SoundPlayer.shared.playWhoosh()
                                    didPlayThumbnailSound = true
                                }
                            }

                        // Center play button
                        Button(action: handlePlayButtonTap) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.95))
                                    .frame(width: 120, height: 120)
                                    .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
                                Image(systemName: "play.fill")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.black)
                                    .offset(x: 4)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .opacity(revealProgress > 0.8 ? 1 : 0)
                        .scaleEffect(revealProgress > 0.8 ? 1 : 0.6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: revealProgress)
                    }
                }

                // UI Overlay
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 30)
                        .padding(.top, 30)
                    }

                    Spacer()

                    // Show video info even when showing thumbnails
                    if hasStartedPlaying || isWaitingForNextVideo {
                        VStack(spacing: 8) {
                            // NEW: Show individual video name if available
                            if let videoName = currentVideoName {
                                Text(videoName)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            } else {
                                Text(activity.title)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            
                            if isWaitingForNextVideo {
                                if currentRepeatCount < settings.videoRepeatCount - 1 {
                                    Text("Tap to replay video \(currentVideoIndex + 1) (repeat \(currentRepeatCount + 2) of \(settings.videoRepeatCount))")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.8))
                                } else {
                                    Text("Tap to play video \(currentVideoIndex + 1) of \(totalVideos)")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            } else {
                                Text("Playing video \(currentVideoIndex + 1) of \(totalVideos) (repeat \(currentRepeatCount + 1) of \(settings.videoRepeatCount))")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            // NEW: Audio playback indicator
                            if audioManager.isPlaying {
                                HStack(spacing: 4) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundColor(.orange)
                                    Text("Playing audio description...")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .padding(.bottom, 50)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if shouldShowThumbnail {
                    handlePlayButtonTap()
                } else if hasStartedPlaying && !isWaitingForNextVideo {
                    handleVideoTap()
                }
            }
        }
        .onAppear(perform: setupVideoQueue)
        .onDisappear {
            currentPlayer?.pause()
            currentPlayer = nil
            audioManager.cleanup() // NEW: Cleanup audio
            SoundEffectPlayer.shared.stopAll()
        }
        .onChange(of: currentVideoIndex) { _, _ in
            // NEW: Play audio when video changes
            playAudioForCurrentVideo()
        }
    }

    // NEW: Play audio for current video
    private func playAudioForCurrentVideo() {
        guard let mediaItem = currentMediaItem else {
            print("📝 VideoQueuePlayerView: No media item found for current video")
            return
        }
        
        audioManager.playAudioForMediaItem(mediaItem) {
            print("🔊 VideoQueuePlayerView: Finished playing audio for: \(mediaItem.customName)")
        }
    }

    private func setupVideoQueue() {
        guard let videoAssets = activity.videoAssets else { return }
        
        isLoadingVideos = true
        
        Task {
            await loadVideoURLs(from: videoAssets)
            await generateThumbnailsFromAllVideos()
            await createPlayerForCurrentVideo()
            
            // NEW: Play audio for first video after setup
            await MainActor.run {
                playAudioForCurrentVideo()
            }
        }
    }
    
    private func loadVideoURLs(from assets: [PHAsset]) async {
        var urls: [URL] = []
        
        for asset in assets {
            if let url = await getVideoURL(for: asset) {
                urls.append(url)
            }
        }
        
        await MainActor.run {
            self.videoURLs = urls
            self.isLoadingVideos = false
        }
    }
    
    private func getVideoURL(for asset: PHAsset) async -> URL? {
        await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                if let urlAsset = avAsset as? AVURLAsset {
                    continuation.resume(returning: urlAsset.url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func createPlayerForCurrentVideo() async {
        guard currentVideoIndex < videoURLs.count else { return }
        
        await MainActor.run {
            let url = videoURLs[currentVideoIndex]
            currentPlayer = AVPlayer(url: url)
            setupPlayerObserver()
        }
    }
    
    private func setupPlayerObserver() {
        guard let player = currentPlayer else { return }
        
        // Remove any existing observers first
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        // Observe when current video ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [self] _ in
            handleCurrentVideoEnd()
        }
    }
    
    private func handleCurrentVideoEnd() {
        // Current video finished
        currentPlayer?.pause()
        isPlaying = false
        videoHasEnded = true
        
        // Check if we need to repeat current video or advance
        if currentRepeatCount < settings.videoRepeatCount - 1 {
            // Repeat the same video
            currentRepeatCount += 1
            isWaitingForNextVideo = true
            revealProgress = 0
            didPlayThumbnailSound = false
            // Keep same video index and player
            // NEW: Play audio again for repeat
            playAudioForCurrentVideo()
        } else {
            // Move to next video and reset repeat count
            currentRepeatCount = 0
            
            if currentVideoIndex < totalVideos - 1 {
                // Move to next video
                currentVideoIndex += 1
            } else {
                // Loop back to first video
                currentVideoIndex = 0
            }
            
            // Show thumbnail for next video
            isWaitingForNextVideo = true
            revealProgress = 0
            didPlayThumbnailSound = false
            
            // Create player for next video
            Task {
                await createPlayerForCurrentVideo()
                // Audio will be played automatically by onChange(of: currentVideoIndex)
            }
        }
    }
    
    private func generateThumbnailsFromAllVideos() async {
        guard let videoAssets = activity.videoAssets else { return }
        
        var thumbnails: [UIImage] = []
        
        for asset in videoAssets {
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            let image = await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: CGSize(width: 1920, height: 1080),
                    contentMode: .aspectFill,
                    options: options
                ) { image, _ in
                    continuation.resume(returning: image)
                }
            }
            
            if let image = image {
                thumbnails.append(image)
            }
        }
        
        await MainActor.run {
            self.thumbnailImages = thumbnails
            self.revealProgress = 0
        }
    }

    private func handlePlayButtonTap() {
        if !hasStartedPlaying {
            // Starting first video
            startCurrentVideo()
        } else if isWaitingForNextVideo {
            // Starting current video (could be repeat or next video)
            startCurrentVideo()
        }
    }
    
    private func startCurrentVideo() {
        guard let player = currentPlayer else { return }
        
        hasStartedPlaying = true
        isPlaying = true
        isWaitingForNextVideo = false
        videoHasEnded = false
        SoundEffectPlayer.shared.stopAll()
        
        player.seek(to: .zero)
        player.play()
    }

    private func handleVideoTap() {
        guard let player = currentPlayer else { return }
        
        // During video playback, tap pauses/resumes
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
}

// MARK: - Full Screen Single Player View
struct FullScreenSinglePlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> SinglePlayerView {
        let view = SinglePlayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: SinglePlayerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    final class SinglePlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}

#Preview {
    // This would need actual PHAssets for preview
    VideoQueuePlayerView(activity: ActivityItem.sampleActivities[0]) {
        print("Dismiss video queue")
    }
}