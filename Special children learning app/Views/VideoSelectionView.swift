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
    
    @State private var showingVideosOnly = true
    
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
                    VStack(spacing: 0) {
                        // Media type selector
                        Picker("Media Type", selection: $showingVideosOnly) {
                            Text("Videos Only").tag(true)
                            Text("Photos & Videos").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding()
                        
                        MediaAlbumListView(
                            photoLibraryManager: photoLibraryManager,
                            onVideoSelected: onVideoSelected,
                            onMultipleVideosSelected: onMultipleVideosSelected,
                            showingVideosOnly: showingVideosOnly
                        )
                    }
                @unknown default:
                    VideoPermissionView(photoLibraryManager: photoLibraryManager)
                }
            }
            .navigationTitle("Select Media")
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
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("Media Access Needed")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("We need access to your photos and videos so you can select which ones to use in the learning activities.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            Button("Allow Media Access") {
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

struct MediaAlbumListView: View {
    let photoLibraryManager: PhotoLibraryManager
    let onVideoSelected: (PHAsset) -> Void
    let onMultipleVideosSelected: ([PHAsset], String) -> Void
    let showingVideosOnly: Bool
    
    @State private var selectedAlbum: PhotoAlbum?
    @State private var showingMedia = false
    
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
                    Text("Loading albums...")
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
                            if showingVideosOnly {
                                await photoLibraryManager.fetchVideoAlbums()
                            } else {
                                await photoLibraryManager.fetchAllMediaAlbums()
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else if photoLibraryManager.albums.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: showingVideosOnly ? "video.slash" : "photo.on.rectangle.angled")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text(showingVideosOnly ? "No video albums found" : "No media albums found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(photoLibraryManager.albums) { album in
                            MediaAlbumCard(
                                album: album, 
                                photoLibraryManager: photoLibraryManager,
                                showingVideosOnly: showingVideosOnly
                            ) {
                                selectedAlbum = album
                                showingMedia = true
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .task(id: showingVideosOnly) {
            if showingVideosOnly {
                await photoLibraryManager.fetchVideoAlbums()
            } else {
                await photoLibraryManager.fetchAllMediaAlbums()
            }
        }
        .refreshable {
            if showingVideosOnly {
                await photoLibraryManager.fetchVideoAlbums()
            } else {
                await photoLibraryManager.fetchAllMediaAlbums()
            }
        }
        .sheet(isPresented: $showingMedia) {
            if let album = selectedAlbum {
                MediaGridView(
                    album: album,
                    photoLibraryManager: photoLibraryManager,
                    onVideoSelected: onVideoSelected,
                    onMultipleVideosSelected: onMultipleVideosSelected,
                    showingVideosOnly: showingVideosOnly
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

struct MediaAlbumCard: View {
    let album: PhotoAlbum
    let photoLibraryManager: PhotoLibraryManager
    let showingVideosOnly: Bool
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
                                Image(systemName: showingVideosOnly ? "video" : "photo.on.rectangle.angled")
                                    .font(.system(size: 32))
                                    .foregroundColor(.primary.opacity(0.6))
                            }
                        }
                    
                    // Media count badge
                    VStack {
                        HStack {
                            Spacer()
                            VStack(spacing: 2) {
                                if !showingVideosOnly && album.photoCount > 0 {
                                    Text("\(album.photoCount)")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.8))
                                        .cornerRadius(6)
                                }
                                
                                if album.videoCount > 0 {
                                    Text("\(album.videoCount)")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.8))
                                        .cornerRadius(6)
                                }
                            }
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
                    
                    if showingVideosOnly {
                        Text("\(album.videoCount) video\(album.videoCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(album.totalMediaCount) item\(album.totalMediaCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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

struct MediaGridView: View {
    let album: PhotoAlbum
    let photoLibraryManager: PhotoLibraryManager
    let onVideoSelected: (PHAsset) -> Void
    let onMultipleVideosSelected: ([PHAsset], String) -> Void
    let showingVideosOnly: Bool
    
    @State private var mediaItems: [MediaItem] = []
    @State private var isLoading = false
    @State private var isMultiSelectMode = false
    @State private var selectedMedia: Set<String> = []
    @State private var showingNameDialog = false
    @State private var collectionName = ""
    @State private var pendingAssets: [PHAsset] = []
    @Environment(\.dismiss) private var dismiss
    
    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 8)
    ]
    
    var selectedMediaAssets: [PHAsset] {
        mediaItems.compactMap { item in
            selectedMedia.contains(item.id) ? item.asset : nil
        }
    }
    
    var selectedVideoAssets: [PHAsset] {
        mediaItems.compactMap { item in
            selectedMedia.contains(item.id) && item.isVideo ? item.asset : nil
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading media...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if mediaItems.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No media in this album")
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        // Multi-select controls
                        if isMultiSelectMode {
                            HStack {
                                Text("\(selectedMedia.count) selected")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                Spacer()
                                
                                if selectedVideoAssets.count > 1 {
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
                                } else if selectedMedia.count == 1 && selectedVideoAssets.count == 1 {
                                    Button("Select Video") {
                                        onVideoSelected(selectedVideoAssets.first!)
                                        dismiss()
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.green)
                                    .cornerRadius(8)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                        }
                        
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(mediaItems) { item in
                                    MediaThumbnailView(
                                        mediaItem: item,
                                        photoLibraryManager: photoLibraryManager,
                                        isMultiSelectMode: isMultiSelectMode,
                                        isSelected: selectedMedia.contains(item.id)
                                    ) {
                                        if isMultiSelectMode {
                                            toggleSelection(for: item)
                                        } else {
                                            // Only allow selection of videos in single select mode
                                            if item.isVideo {
                                                onVideoSelected(item.asset)
                                                dismiss()
                                            }
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
                            selectedMedia.removeAll()
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
            await loadMedia()
        }
    }
    
    private func loadMedia() async {
        isLoading = true
        if showingVideosOnly {
            let videos = await photoLibraryManager.fetchVideos(from: album)
            mediaItems = videos.map { MediaItem(asset: $0.asset, duration: $0.duration, creationDate: $0.creationDate) }
        } else {
            mediaItems = await photoLibraryManager.fetchAllMedia(from: album)
        }
        isLoading = false
    }
    
    private func toggleSelection(for item: MediaItem) {
        if selectedMedia.contains(item.id) {
            selectedMedia.remove(item.id)
        } else {
            selectedMedia.insert(item.id)
        }
    }
}

struct MediaThumbnailView: View {
    let mediaItem: MediaItem
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
                .aspectRatio(1, contentMode: .fit)
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
            
            // Selection overlay
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
            
            // Media type indicator
            if !isMultiSelectMode {
                if mediaItem.isVideo {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                } else {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "photo")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                                .padding(.top, 8)
                                .padding(.trailing, 8)
                        }
                        Spacer()
                    }
                }
            }
            
            // Duration badge (for videos only)
            if mediaItem.isVideo {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(formatDuration(mediaItem.duration ?? 0))
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
            
            // Non-video overlay (shows it's not selectable in single select mode)
            if !mediaItem.isVideo && !isMultiSelectMode {
                Color.black.opacity(0.4)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .contentShape(Rectangle()) // Make entire area tappable
        .onTapGesture {
            // Add haptic feedback for videos or multi-select
            if mediaItem.isVideo || isMultiSelectMode {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                onTap()
            }
        }
        .task(id: mediaItem.id) {
            // Only load thumbnail if not already loaded
            if thumbnailImage == nil {
                await loadThumbnail()
            }
        }
    }
    
    private func loadThumbnail() async {
        let image = await photoLibraryManager.loadThumbnail(
            for: mediaItem.asset,
            targetSize: CGSize(width: 120, height: 120)
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