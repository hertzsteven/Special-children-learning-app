//
//  PhotoCollectionView.swift
//  Special children learning app
//
//  Created by AI Assistant on 9/4/25.
//

import SwiftUI
import Photos

struct PhotoCollectionView: View {
    let activity: ActivityItem
    let onDismiss: () -> Void
    
    @State private var currentIndex = 0
    @State private var photos: [UIImage] = []
    @State private var isLoading = true
    @StateObject private var soundPlayer = SoundPlayer.shared
    @StateObject private var audioManager = AudioPlaybackManager.shared // NEW: Audio manager

    @State private var isBouncing = false
    @State private var showRipple = false
    @State private var rippleScale: CGFloat = 0.5
    @State private var rippleOpacity: Double = 0.0
    
    private var photoAssets: [PHAsset] {
        return activity.photoAssets ?? []
    }
    
    // NEW: Get current photo's associated media item
    private var currentMediaItem: SavedMediaItem? {
        guard currentIndex < photoAssets.count,
              let mediaItems = activity.mediaItems else { return nil }
        
        let currentAsset = photoAssets[currentIndex]
        return mediaItems.first { $0.assetIdentifier == currentAsset.localIdentifier }
    }
    
    // NEW: Get the current photo's name
    private var currentPhotoName: String? {
        if let mediaItem = currentMediaItem {
            return mediaItem.customName
        }
        // Fallback to activity-level name lookup
        guard currentIndex < photoAssets.count else { return nil }
        let currentAsset = photoAssets[currentIndex]
        return activity.getMediaItemName(for: currentAsset)
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea(.all)
            
            if isLoading {
                VStack(spacing: 30) {
                    ProgressView()
                        .scaleEffect(2)
                        .tint(.white)
                    
                    Text("Loading photos...")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            } else if photos.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                    Text("No photos available")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            } else {
                // Full screen photo display
                Image(uiImage: photos[currentIndex])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.28), value: currentIndex)
                    .scaleEffect(isBouncing ? 1.05 : 1.0)
                    .animation(.spring(response: 0.22, dampingFraction: 0.6), value: isBouncing)
                    .onAppear {
                        // Play audio for first photo only when it appears
                        if currentIndex == 0 {
                            playAudioForCurrentPhoto()
                        }
                    }
                
                if showRipple {
                    GeometryReader { geo in
                        Circle()
                            .strokeBorder(Color.white.opacity(0.7), lineWidth: 3)
                            .frame(width: min(geo.size.width, geo.size.height) * 0.35,
                                   height: min(geo.size.width, geo.size.height) * 0.35)
                            .scaleEffect(rippleScale)
                            .opacity(rippleOpacity)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                            .allowsHitTesting(false)
                    }
                    .transition(.opacity)
                }
                
                // Photo name and audio indicator overlay (bottom center)
                VStack {
                    Spacer()
                    
                    VStack(spacing: 8) {
                        // Photo name
                        if let photoName = currentPhotoName {
                            Text(photoName)
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.black.opacity(0.7))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
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
                    .padding(.bottom, 80) // Space from bottom
                }
                
                // Close button (top right)
                VStack {
                    HStack {
                        Spacer()
                        
                        ZStack {
                            Image(systemName: "xmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .onLongPressGesture {
                            onDismiss()
                        }
                        .onTapGesture {
                            // Do nothing to prevent any tap action
                        }

                        .padding()
                    }
                    Spacer()
                }
                
                // Photo counter (top center)
                VStack {
                    HStack {
                        Spacer()
                        
                        Text("\(currentIndex + 1) of \(photos.count)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(12)
                        
                        Spacer()
                    }
                    .padding(.top, 60) // Below status bar
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            loadPhotos()
            soundPlayer.playWhoosh(volume: 0.3, rate: 1.2)
            // DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            //     playAudioForCurrentPhoto()
            // }
        }
        .onDisappear {
            // NEW: Cleanup audio when view disappears
            audioManager.cleanup()
        }
        .onChange(of: currentIndex) { _, newValue in
            // NEW: Play audio when photo changes (but not for the first photo which is handled above)
            if newValue > 0 {
                playAudioForCurrentPhoto()
            }
        }
        .onTapGesture {
            // Simple tap to go to next photo
            triggerTapAnimation()
            nextPhoto()
        }
    }
    
    // NEW: Play audio for current photo
    private func playAudioForCurrentPhoto() {
        guard let mediaItem = currentMediaItem else {
            print("📝 PhotoCollectionView: No media item found for current photo")
            return
        }
        
        audioManager.playAudioForMediaItem(mediaItem) {
            print("🔊 PhotoCollectionView: Finished playing audio for: \(mediaItem.customName)")
        }
    }
    
    private func loadPhotos() {
        guard !photoAssets.isEmpty else {
            isLoading = false
            return
        }
        
        Task {
            var loadedImages: [UIImage] = []
            
            for asset in photoAssets {
                if let image = await loadFullSizeImage(for: asset) {
                    loadedImages.append(image)
                }
            }
            
            await MainActor.run {
                self.photos = loadedImages
                self.isLoading = false
            }
        }
    }
    
    private func loadFullSizeImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    private func nextPhoto() {
        guard !photos.isEmpty else { return }
        
        // Play sound effect
        soundPlayer.playWhoosh(volume: 0.2, rate: 1.5)
        
        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Simple increment with wrap-around to beginning
        currentIndex = (currentIndex + 1) % photos.count
    }

    private func triggerTapAnimation() {
        // Bounce
        isBouncing = true
        withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) {
            isBouncing = false
        }
        
        // Ripple
        showRipple = true
        rippleScale = 0.5
        rippleOpacity = 0.6
        withAnimation(.easeOut(duration: 0.55)) {
            rippleScale = 1.6
            rippleOpacity = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showRipple = false
        }
    }
}
