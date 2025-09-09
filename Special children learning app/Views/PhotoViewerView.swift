//
//  PhotoViewerView.swift
//  Special children learning app
//
//  Created by AI Assistant on 9/4/25.
//

import SwiftUI
import Photos

struct PhotoViewerView: View {
    let activity: MediaCollection
    let onDismiss: () -> Void
    
    @State private var displayImage: UIImage?
    @State private var isLoading = true
    @StateObject private var soundPlayer = SoundPlayer.shared
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack {
                // Close button
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
//                    Button(action: {}) {
//                        Image(systemName: "xmark.circle")
//                            .font(.title)
//                            .foregroundColor(.white)
//                            .background(Color.black.opacity(0.5))
//                            .clipShape(Circle())
//                    }
//                    .onLongPressGesture {
//                        onDismiss()
//                    }
                    .padding()
                }
                
                Spacer()
                
                // Photo display
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                } else if let image = displayImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        Text("Unable to load photo")
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                // Title and description
                VStack(spacing: 12) {
                    Text(activity.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(activity.audioDescription)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            loadPhoto()
            // Play sound effect when photo appears
            soundPlayer.playWhoosh(volume: 0.3, rate: 1.2)
        }
        .onTapGesture {
            onDismiss()
        }
    }
    
    private func loadPhoto() {
        guard let photoAsset = activity.photoAsset else {
            isLoading = false
            return
        }
        
        Task {
            let image = await loadFullSizeImage(for: photoAsset)
            await MainActor.run {
                self.displayImage = image
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
}

#Preview {
    PhotoViewerView(
        activity: MediaCollection(
            title: "Sample Photo",
            imageName: "photo",
            videoFileName: "",
            audioDescription: "A beautiful sample photo",
            backgroundColor: "softBlue"
        )
    ) {
        print("Dismissed")
    }
}
