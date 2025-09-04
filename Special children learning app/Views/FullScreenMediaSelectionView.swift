//
//  FullScreenMediaSelectionView.swift
//  Special children learning app
//
//  Created by AI Assistant on 9/4/25.
//

import SwiftUI
import Photos

struct FullScreenMediaSelectionView: View {
    @StateObject private var photoLibraryManager = PhotoLibraryManager()
    @Environment(\.dismiss) private var dismiss
    let onVideoSelected: (PHAsset) -> Void
    let onMultipleVideosSelected: ([PHAsset], String) -> Void
    
    @State private var showingVideosOnly = true
    @State private var selectedAlbum: PhotoAlbum?
    @State private var searchText = ""
    @State private var mediaItems: [MediaItem] = []
    @State private var isLoadingMedia = false
    
    // Multi-selection state
    @State private var isMultiSelectMode = false
    @State private var selectedMedia: Set<String> = []
    @State private var showingNameDialog = false
    @State private var collectionName = ""
    @State private var pendingAssets: [PHAsset] = []
    
    private let sidebarWidth: CGFloat = 280
    
    var selectedVideoAssets: [PHAsset] {
        mediaItems.compactMap { item in
            selectedMedia.contains(item.id) && item.isVideo ? item.asset : nil
        }
    }
    
    var filteredAlbums: [PhotoAlbum] {
        if searchText.isEmpty {
            return photoLibraryManager.albums
        } else {
            return photoLibraryManager.albums.filter { 
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Sidebar
                VStack(spacing: 0) {
                    // Sidebar Header
                    VStack(spacing: 16) {
                        HStack {
                            Text("Albums")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                            Button("Cancel") {
                                dismiss()
                            }
                            .foregroundColor(.blue)
                        }
                        
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search albums", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        
                        // Media Type Picker
                        Picker("Media Type", selection: $showingVideosOnly) {
                            Text("Videos Only").tag(true)
                            Text("Photos & Videos").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding()
                    .padding(.top, 20) // Extra top padding for full screen
                    
                    Divider()
                    
                    // Albums List
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredAlbums) { album in
                                AlbumSidebarRow(
                                    album: album,
                                    isSelected: selectedAlbum?.id == album.id,
                                    showingVideosOnly: showingVideosOnly
                                ) {
                                    selectedAlbum = album
                                    Task {
                                        await loadAlbumMedia(album)
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer() // Push content to top
                }
                .frame(width: sidebarWidth)
                .background(Color(.systemGray6))
                
                Divider()
                
                // Main Content Area
                VStack(spacing: 0) {
                    // Main Header
                    VStack(spacing: 12) {
                        HStack {
                            Text(selectedAlbum?.title ?? "Select an Album")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            if !mediaItems.isEmpty {
                                Button(isMultiSelectMode ? "Cancel Selection" : "Select Multiple") {
                                    isMultiSelectMode.toggle()
                                    if !isMultiSelectMode {
                                        selectedMedia.removeAll()
                                    }
                                }
                                .foregroundColor(.blue)
                            }
                        }
                        
                        // Selection Status Bar
                        if isMultiSelectMode && !selectedMedia.isEmpty {
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
                    }
                    .padding()
                    .padding(.top, 20) // Extra top padding for full screen
                    
                    if selectedAlbum == nil {
                        // Empty State
                        VStack(spacing: 20) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("Select an album to view photos and videos")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if isLoadingMedia {
                        // Loading State
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading media...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if mediaItems.isEmpty {
                        // No Media State
                        VStack(spacing: 20) {
                            Image(systemName: showingVideosOnly ? "video.slash" : "photo")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text(showingVideosOnly ? "No videos in this album" : "No media in this album")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Media Grid
                        ScrollView {
                            LazyVGrid(columns: createColumns(for: geometry.size.width - sidebarWidth), spacing: 4) {
                                ForEach(mediaItems) { item in
                                    FullScreenMediaThumbnailView(
                                        mediaItem: item,
                                        photoLibraryManager: photoLibraryManager,
                                        isMultiSelectMode: isMultiSelectMode,
                                        isSelected: selectedMedia.contains(item.id)
                                    ) {
                                        if isMultiSelectMode {
                                            toggleSelection(for: item)
                                        } else {
                                            if item.isVideo {
                                                onVideoSelected(item.asset)
                                                dismiss()
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(8)
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .edgesIgnoringSafeArea(.all)
        .task {
            switch photoLibraryManager.authorizationStatus {
            case .authorized, .limited:
                if showingVideosOnly {
                    await photoLibraryManager.fetchVideoAlbums()
                } else {
                    await photoLibraryManager.fetchAllMediaAlbums()
                }
            case .notDetermined, .denied, .restricted:
                await photoLibraryManager.requestPhotoLibraryAccess()
            @unknown default:
                break
            }
        }
        .onChange(of: showingVideosOnly) { _, newValue in
            Task {
                selectedAlbum = nil
                mediaItems = []
                if newValue {
                    await photoLibraryManager.fetchVideoAlbums()
                } else {
                    await photoLibraryManager.fetchAllMediaAlbums()
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
    }
    
    private func createColumns(for width: CGFloat) -> [GridItem] {
        let itemSize: CGFloat = 120
        let spacing: CGFloat = 4
        let availableWidth = width - 16 // Account for padding
        let itemsPerRow = max(3, Int(availableWidth / (itemSize + spacing)))
        
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: itemsPerRow)
    }
    
    private func loadAlbumMedia(_ album: PhotoAlbum) async {
        isLoadingMedia = true
        
        if showingVideosOnly {
            let videos = await photoLibraryManager.fetchVideos(from: album)
            mediaItems = videos.map { MediaItem(asset: $0.asset, duration: $0.duration, creationDate: $0.creationDate) }
        } else {
            mediaItems = await photoLibraryManager.fetchAllMedia(from: album)
        }
        
        isLoadingMedia = false
    }
    
    private func toggleSelection(for item: MediaItem) {
        if selectedMedia.contains(item.id) {
            selectedMedia.remove(item.id)
        } else {
            selectedMedia.insert(item.id)
        }
    }
}

struct AlbumSidebarRow: View {
    let album: PhotoAlbum
    let isSelected: Bool
    let showingVideosOnly: Bool
    let onTap: () -> Void
    
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                Group {
                    if let image = thumbnailImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay {
                                Image(systemName: showingVideosOnly ? "video" : "photo")
                                    .foregroundColor(.secondary)
                            }
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Album Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(album.title)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        if showingVideosOnly {
                            Text("\(album.videoCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            if album.photoCount > 0 {
                                Label("\(album.photoCount)", systemImage: "photo")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if album.videoCount > 0 {
                                Label("\(album.videoCount)", systemImage: "video")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            if let thumbnailAsset = album.thumbnailAsset {
                thumbnailImage = await PhotoLibraryManager().loadThumbnail(
                    for: thumbnailAsset,
                    targetSize: CGSize(width: 100, height: 100)
                )
            }
        }
    }
}

struct FullScreenMediaThumbnailView: View {
    let mediaItem: MediaItem
    let photoLibraryManager: PhotoLibraryManager
    let isMultiSelectMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let image = thumbnailImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                )
            
            // Selection overlay
            if isMultiSelectMode {
                VStack {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.blue : Color.black.opacity(0.5))
                                .frame(width: 24, height: 24)
                            
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.top, 6)
                        .padding(.leading, 6)
                        Spacer()
                    }
                    Spacer()
                }
            }
            
            // Media type indicator
            if !isMultiSelectMode {
                if mediaItem.isVideo {
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                } else {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "photo")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(3)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                                .padding(.top, 4)
                                .padding(.trailing, 4)
                        }
                        Spacer()
                    }
                }
            }
            
            // Duration badge (for videos)
            if mediaItem.isVideo {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        if let duration = mediaItem.duration {
                            Text(formatDuration(duration))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(3)
                                .padding(.bottom, 4)
                                .padding(.trailing, 4)
                        }
                    }
                }
            }
            
            // Non-video overlay
            if !mediaItem.isVideo && !isMultiSelectMode {
                Color.black.opacity(0.3)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if mediaItem.isVideo || isMultiSelectMode {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                onTap()
            }
        }
        .task(id: mediaItem.id) {
            if thumbnailImage == nil {
                await loadThumbnail()
            }
        }
    }
    
    private func loadThumbnail() async {
        let image = await photoLibraryManager.loadThumbnail(
            for: mediaItem.asset,
            targetSize: CGSize(width: 150, height: 150)
        )
        
        await MainActor.run {
            self.thumbnailImage = image
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    FullScreenMediaSelectionView { asset in
        print("Selected video: \(asset.localIdentifier)")
    } onMultipleVideosSelected: { assets, name in
        print("Selected \(assets.count) videos for collection: \(name)")
    }
}