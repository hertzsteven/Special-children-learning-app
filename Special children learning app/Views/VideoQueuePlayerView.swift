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

    @State private var queuePlayer: AVQueuePlayer?
    @State private var currentVideoIndex = 0
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
                if let player = queuePlayer, !isLoadingVideos, hasStartedPlaying, !isWaitingForNextVideo {
                    FullScreenQueuePlayerView(player: player)
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
                            Text(activity.title)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            if isWaitingForNextVideo {
                                Text("Tap to play video \(currentVideoIndex + 1) of \(totalVideos)")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.8))
                            } else {
                                Text("Playing video \(currentVideoIndex + 1) of \(totalVideos)")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.8))
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
            queuePlayer?.pause()
            queuePlayer = nil
            SoundEffectPlayer.shared.stopAll()
        }
    }

    private func setupVideoQueue() {
        guard let videoAssets = activity.videoAssets else { return }
        
        isLoadingVideos = true
        
        Task {
            await loadVideoURLs(from: videoAssets)
            await generateThumbnailsFromAllVideos()
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
            self.createQueuePlayer()
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
    
    private func createQueuePlayer() {
        let playerItems = videoURLs.map { AVPlayerItem(url: $0) }
        queuePlayer = AVQueuePlayer(items: playerItems)
        
        // Set up observers for when videos end
        setupQueueObservers()
    }
    
    private func setupQueueObservers() {
        guard let player = queuePlayer else { return }
        
        // Observe when videos end to pause and show next thumbnail
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [self] notification in
            if let item = notification.object as? AVPlayerItem {
                handleVideoEnd(item: item, player: player)
            }
        }
    }
    
    private func handleVideoEnd(item: AVPlayerItem, player: AVQueuePlayer) {
        // Pause the player
        player.pause()
        isPlaying = false
        videoHasEnded = true
        
        // Prepare for next video
        if currentVideoIndex < totalVideos - 1 {
            // Move to next video
            currentVideoIndex += 1
            isWaitingForNextVideo = true
            // Reset animation for next thumbnail
            revealProgress = 0
            didPlayThumbnailSound = false
        } else {
            // Last video finished, loop back to first
            currentVideoIndex = 0
            isWaitingForNextVideo = true
            // Reset animation for first thumbnail
            revealProgress = 0
            didPlayThumbnailSound = false
            // Recreate queue to start from beginning
            createQueuePlayer()
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
        guard let player = queuePlayer else { return }
        
        if !hasStartedPlaying {
            // Starting first video
            startVideoQueue()
        } else if isWaitingForNextVideo {
            // Starting next video in queue
            startNextVideo()
        }
    }
    
    private func startVideoQueue() {
        guard let player = queuePlayer else { return }
        hasStartedPlaying = true
        isPlaying = true
        isWaitingForNextVideo = false
        videoHasEnded = false
        SoundEffectPlayer.shared.stopAll()
        player.play()
    }
    
    private func startNextVideo() {
        guard let player = queuePlayer else { return }
        
        // Advance to the current video index
        player.removeAllItems()
        
        // Add items starting from current index
        let remainingURLs = Array(videoURLs.dropFirst(currentVideoIndex))
        for url in remainingURLs {
            let item = AVPlayerItem(url: url)
            player.insert(item, after: nil)
        }
        
        isPlaying = true
        isWaitingForNextVideo = false
        videoHasEnded = false
        player.play()
    }

    private func handleVideoTap() {
        guard let player = queuePlayer else { return }
        
        // During video playback, tap pauses/resumes
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
}

// MARK: - Full Screen Queue Player View
struct FullScreenQueuePlayerView: UIViewRepresentable {
    let player: AVQueuePlayer

    func makeUIView(context: Context) -> QueuePlayerView {
        let view = QueuePlayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: QueuePlayerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    final class QueuePlayerView: UIView {
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