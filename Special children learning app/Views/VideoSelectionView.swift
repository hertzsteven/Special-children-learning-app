//
//  VideoSelectionView.swift
//  Special children learning app
//
//  Created by Steven Hertz on 9/4/25.
//

import SwiftUI
import Photos

struct VideoSelectionView: View {
    @StateObject private var photoLibraryManager = PhotoLibraryManager()
    @Environment(\.dismiss) private var dismiss
    let onVideoSelected: (PHAsset) -> Void
    let onMultipleVideosSelected: ([PHAsset], String) -> Void
    
    init(onVideoSelected: @escaping (PHAsset) -> Void, onMultipleVideosSelected: @escaping ([PHAsset], String) -> Void = { _, _ in }) {
        self.onVideoSelected = onVideoSelected
        self.onMultipleVideosSelected = onMultipleVideosSelected
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch photoLibraryManager.authorizationStatus {
                case .notDetermined, .denied, .restricted:
                    VideoPermissionView(photoLibraryManager: photoLibraryManager)
                case .authorized, .limited:
                    VideoAlbumListView(
                        photoLibraryManager: photoLibraryManager,
                        onVideoSelected: onVideoSelected,
                        onMultipleVideosSelected: onMultipleVideosSelected
                    )
                @unknown default:
                    VideoPermissionView(photoLibraryManager: photoLibraryManager)
                }
            }
            .navigationTitle("Select Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct VideoPermissionView: View {
    let photoLibraryManager: PhotoLibraryManager
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "video.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("Video Access Needed")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("We need access to your videos so you can select which ones to play in the learning activities.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            Button("Allow Video Access") {
                Task {
                    await photoLibraryManager.requestPhotoLibraryAccess()
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
        }
        .padding(40)
    }
}

struct VideoAlbumListView: View {
    let photoLibraryManager: PhotoLibraryManager
    let onVideoSelected: (PHAsset) -> Void
    let onMultipleVideosSelected: ([PHAsset], String) -> Void
    
    @State private var selectedAlbum: PhotoAlbum?
    @State private var showingVideos = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        Group {
            if photoLibraryManager.isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading video albums...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = photoLibraryManager.errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        Task {
                            await photoLibraryManager.fetchVideoAlbums()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else if photoLibraryManager.albums.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No video albums found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(photoLibraryManager.albums) { album in
                            VideoAlbumCard(
                                album: album, 
                                photoLibraryManager: photoLibraryManager
                            ) {
                                selectedAlbum = album
                                showingVideos = true
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            if photoLibraryManager.albums.isEmpty {
                await photoLibraryManager.fetchVideoAlbums()
            }
        }
        .refreshable {
            await photoLibraryManager.fetchVideoAlbums()
        }
        .sheet(isPresented: $showingVideos) {
            if let album = selectedAlbum {
                VideoGridView(
                    album: album,
                    photoLibraryManager: photoLibraryManager,
                    onVideoSelected: onVideoSelected,
                    onMultipleVideosSelected: onMultipleVideosSelected
                )
            }
        }
    }
}

struct VideoAlbumCard: View {
    let album: PhotoAlbum
    let photoLibraryManager: PhotoLibraryManager
    let onTap: () -> Void
    
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.softBlue)
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay {
                            if let image = thumbnailImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                Image(systemName: "video")
                                    .font(.system(size: 32))
                                    .foregroundColor(.primary.opacity(0.6))
                            }
                        }
                    
                    // Video count badge
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(album.videoCount)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(8)
                                .padding(.top, 8)
                                .padding(.trailing, 8)
                        }
                        Spacer()
                    }
                }
                
                // Album info
                VStack(alignment: .leading, spacing: 4) {
                    Text(album.title)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text("\(album.videoCount) video\(album.videoCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .task {
            if let thumbnailAsset = album.thumbnailAsset {
                thumbnailImage = await photoLibraryManager.loadThumbnail(
                    for: thumbnailAsset,
                    targetSize: CGSize(width: 200, height: 200)
                )
            }
        }
    }
}

struct VideoGridView: View {
    let album: PhotoAlbum
    let photoLibraryManager: PhotoLibraryManager
    let onVideoSelected: (PHAsset) -> Void
    let onMultipleVideosSelected: ([PHAsset], String) -> Void
    
    @State private var videos: [VideoItem] = []
    @State private var isLoading = false
    @State private var isMultiSelectMode = false
    @State private var selectedVideos: Set<String> = []
    @State private var showingNameDialog = false
    @State private var collectionName = ""
    @State private var pendingAssets: [PHAsset] = []
    @Environment(\.dismiss) private var dismiss
    
    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 8)
    ]
    
    var selectedVideoAssets: [PHAsset] {
        videos.compactMap { video in
            selectedVideos.contains(video.id) ? video.asset : nil
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading videos...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if videos.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "video")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No videos in this album")
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        // Multi-select controls
                        if isMultiSelectMode {
                            HStack {
                                Text("\(selectedVideos.count) selected")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                Spacer()
                                
                                if selectedVideos.count > 1 {
                                    Button("Create Collection") {
                                        pendingAssets = selectedVideoAssets
                                        collectionName = "My Video Collection"
                                        showingNameDialog = true
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                        }
                        
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(videos) { video in
                                    VideoThumbnailView(
                                        video: video,
                                        photoLibraryManager: photoLibraryManager,
                                        isMultiSelectMode: isMultiSelectMode,
                                        isSelected: selectedVideos.contains(video.id)
                                    ) {
                                        if isMultiSelectMode {
                                            toggleSelection(for: video)
                                        } else {
                                            onVideoSelected(video.asset)
                                            dismiss()
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle(album.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button(isMultiSelectMode ? "Cancel Selection" : "Select Multiple") {
                        isMultiSelectMode.toggle()
                        if !isMultiSelectMode {
                            selectedVideos.removeAll()
                        }
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Name Your Collection", isPresented: $showingNameDialog) {
            TextField("Collection name", text: $collectionName)
                .textInputAutocapitalization(.words)
            
            Button("Create") {
                onMultipleVideosSelected(pendingAssets, collectionName)
                dismiss()
            }
            .disabled(collectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            Button("Cancel", role: .cancel) {
                pendingAssets = []
                collectionName = ""
            }
        } message: {
            Text("Give your video collection a memorable name")
        }
        .task {
            await loadVideos()
        }
    }
    
    private func loadVideos() async {
        isLoading = true
        videos = await photoLibraryManager.fetchVideos(from: album)
        isLoading = false
    }
    
    private func toggleSelection(for video: VideoItem) {
        if selectedVideos.contains(video.id) {
            selectedVideos.remove(video.id)
        } else {
            selectedVideos.insert(video.id)
        }
    }
}

struct VideoThumbnailView: View {
    let video: VideoItem
    let photoLibraryManager: PhotoLibraryManager
    let isMultiSelectMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(16/9, contentMode: .fit)
                .overlay {
                    if let image = thumbnailImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 4)
                )
            
            // Selection overlay - SINGLE TAP TARGET
            if isMultiSelectMode {
                VStack {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.blue : Color.black.opacity(0.5))
                                .frame(width: 30, height: 30)
                            
                            Image(systemName: isSelected ? "checkmark" : "")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 8)
                        .padding(.leading, 8)
                        Spacer()
                    }
                    Spacer()
                }
            }
            
            // Play icon (only in single select mode)
            if !isMultiSelectMode {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            
            // Duration badge
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(formatDuration(video.duration))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .padding(.bottom, 4)
                        .padding(.trailing, 4)
                }
            }
        }
        .contentShape(Rectangle()) // Make entire area tappable
        .onTapGesture {
            // Add haptic feedback for immediate response
            if isMultiSelectMode {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            onTap()
        }
        .task(id: video.id) {
            // Only load thumbnail if not already loaded
            if thumbnailImage == nil {
                await loadThumbnail()
            }
        }
    }
    
    private func loadThumbnail() async {
        let image = await photoLibraryManager.loadThumbnail(
            for: video.asset,
            targetSize: CGSize(width: 120, height: 120) // Smaller size for performance
        )
        
        await MainActor.run {
            self.thumbnailImage = image
            self.isLoading = false
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    VideoSelectionView { asset in
        print("Selected video: \(asset.localIdentifier)")
    }
}