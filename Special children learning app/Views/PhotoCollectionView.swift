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
    @State private var loadingProgress = 0.0
    @StateObject private var soundPlayer = SoundPlayer.shared
    
    private var photoAssets: [PHAsset] {
        return activity.photoAssets ?? []
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if isLoading {
                VStack(spacing: 30) {
                    ProgressView()
                        .scaleEffect(2)
                        .tint(.white)
                    
                    Text("Loading photos...")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    ProgressView(value: loadingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        .frame(width: 200)
                }
            } else if photos.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                    Text("No photos available")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Button("Close") {
                        onDismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                }
            } else {
                VStack(spacing: 0) {
                    // Top controls
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activity.title)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("\(currentIndex + 1) of \(photos.count)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Photo display
                    TabView(selection: $currentIndex) {
                        ForEach(0..<photos.count, id: \.self) { index in
                            Image(uiImage: photos[index])
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                // Add haptic feedback for swipe
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                    )
                    
                    Spacer()
                    
                    // Bottom controls
                    HStack(spacing: 40) {
                        Button(action: previousPhoto) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.title)
                                .foregroundColor(currentIndex > 0 ? .white : .gray)
                        }
                        .disabled(currentIndex <= 0)
                        
                        // Page indicators
                        HStack(spacing: 8) {
                            ForEach(0..<photos.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        
                        Button(action: nextPhoto) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.title)
                                .foregroundColor(currentIndex < photos.count - 1 ? .white : .gray)
                        }
                        .disabled(currentIndex >= photos.count - 1)
                    }
                    .padding(.bottom, 40)
                    
                    // Description
                    Text(activity.audioDescription)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            loadPhotos()
            soundPlayer.playWhoosh(volume: 0.3, rate: 1.2)
        }
        .onChange(of: currentIndex) { _, _ in
            // Play subtle sound when changing photos
            soundPlayer.playWhoosh(volume: 0.1, rate: 1.5)
        }
    }
    
    private func loadPhotos() {
        guard !photoAssets.isEmpty else {
            isLoading = false
            return
        }
        
        Task {
            var loadedImages: [UIImage] = []
            
            for (index, asset) in photoAssets.enumerated() {
                if let image = await loadFullSizeImage(for: asset) {
                    loadedImages.append(image)
                }
                
                // Update progress
                await MainActor.run {
                    loadingProgress = Double(index + 1) / Double(photoAssets.count)
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
        if currentIndex < photos.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex += 1
            }
        }
    }
    
    private func previousPhoto() {
        if currentIndex > 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex -= 1
            }
        }
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