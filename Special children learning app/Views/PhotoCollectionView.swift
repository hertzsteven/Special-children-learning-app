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
    
    private var photoAssets: [PHAsset] {
        return activity.photoAssets ?? []
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
                
                // Close button (top right)
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            loadPhotos()
            soundPlayer.playWhoosh(volume: 0.3, rate: 1.2)
        }
        .onTapGesture {
            // Simple tap to go to next photo
            nextPhoto()
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
}

#Preview {
    PhotoCollectionView(
        activity: ActivityItem(
            title: "Sample Photo Collection",
            imageName: "photo.stack",
            photoAssets: [],
            audioDescription: "A collection of beautiful photos",
            backgroundColor: "sage"
        )
    ) {
        print("Dismissed")
    }
}