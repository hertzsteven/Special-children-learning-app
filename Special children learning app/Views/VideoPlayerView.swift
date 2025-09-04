//
//  VideoPlayerView.swift
//  Special children learning app
//
//  Created by Steven Hertz on 9/3/25.
//

import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: View {
    let activity: ActivityItem
    let onDismiss: () -> Void

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var videoEnded = false

    // Thumbnail + animation
    @State private var thumbnailImage: UIImage?
    @State private var revealProgress: CGFloat = 0
    @State private var hasStartedPlaying = false
    @State private var didPlayThumbnailSound = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // Full-screen video, no controls
                if let player {
                    if hasStartedPlaying {
                        FullScreenPlayerView(player: player)
                            .ignoresSafeArea()
                            .onAppear {
                                // Ensure playback starts right away
                                player.play()
                                isPlaying = true
                            }
                    }
                }

                // Animated thumbnail overlay (only when not yet playing)
                if !hasStartedPlaying {
                    if let image = thumbnailImage {
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
                                if !didPlayThumbnailSound {
                                    SoundPlayer.shared.playWhoosh()
                                    didPlayThumbnailSound = true
                                }
                            }

                        // Center play button
                        Button(action: startVideo) {
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

                // Close and title
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

                    if hasStartedPlaying {
                        Text(activity.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(10)
                            .padding(.bottom, 50)
                    }
                }
            }
            .contentShape(Rectangle()) // so taps anywhere register
            .onTapGesture {
                // Handle taps to start video or during playback
                if hasStartedPlaying {
                    handleTap()
                } else {
                    startVideo()
                }
            }
        }
        .onAppear(perform: setupPlayer)
        .onDisappear {
            player?.pause()
            player = nil
            SoundEffectPlayer.shared.stopAll()
        }
    }

    private func setupPlayer() {
        // Try mp4 then mov
        var url: URL?
        if let u = Bundle.main.url(forResource: activity.videoFileName, withExtension: "mp4") {
            url = u
        } else if let u = Bundle.main.url(forResource: activity.videoFileName, withExtension: "mov") {
            url = u
        }

        guard let url else { return }

        let player = AVPlayer(url: url)
        self.player = player

        // Observe end of playback
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            isPlaying = false
            videoEnded = true
        }

        // Generate first-frame thumbnail for animated reveal
        generateThumbnail(from: url)
    }

    private func generateThumbnail(from url: URL) {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 1920, height: 1080)
        let time = CMTime(seconds: 0.1, preferredTimescale: 600) // a bit in, to avoid black

        gen.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cg, _, _, _ in
            if let cg {
                DispatchQueue.main.async {
                    self.thumbnailImage = UIImage(cgImage: cg)
                    // Start reveal at 0 so animation triggers onAppear of the image
                    self.revealProgress = 0
                }
            }
        }
    }

    private func startVideo() {
        guard let player = player else { return }
        hasStartedPlaying = true
        videoEnded = false
        isPlaying = true
        SoundEffectPlayer.shared.stopAll()
        player.seek(to: .zero)
        player.play()
    }

    private func handleTap() {
        guard let player else { return }
        if videoEnded {
            player.seek(to: .zero)
            player.play()
            isPlaying = true
            videoEnded = false
            return
        }

        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
}

// MARK: - AVPlayerLayer-backed view that always fills screen (no controls, no black bars)
struct FullScreenPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill // fill screen, crop as needed
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}

// MARK: - Mask used to reveal the thumbnail in tiles from center
struct TileRevealMask: Shape {
    var progress: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tile: CGFloat = 44
        let cols = Int(ceil(rect.width / tile))
        let rows = Int(ceil(rect.height / tile))
        let cx = rect.midX
        let cy = rect.midY
        let maxDist = hypot(cx, cy)

        for r in 0..<rows {
            for c in 0..<cols {
                let x = CGFloat(c) * tile
                let y = CGFloat(r) * tile
                let centerX = x + tile / 2
                let centerY = y + tile / 2
                let dist = hypot(centerX - cx, centerY - cy)
                let delay = (dist / maxDist) * 0.45
                let local = max(0, min(1, (progress - delay) / 0.55))
                if local > 0 {
                    let appearSize = tile * local
                    let dx = (tile - appearSize) / 2
                    let dy = (tile - appearSize) / 2
                    let w = min(appearSize, rect.width - (x + dx))
                    let h = min(appearSize, rect.height - (y + dy))
                    path.addRect(CGRect(x: x + dx, y: y + dy, width: w, height: h))
                }
            }
        }
        return path
    }

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
}

#Preview {
    VideoPlayerView(activity: ActivityItem.sampleActivities[0]) {
        print("Dismiss video")
    }
}
