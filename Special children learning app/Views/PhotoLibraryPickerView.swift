//
//  FullScreenMediaSelectionView.swift
//  Special children learning app
//
//  Created by AI Assistant on 9/4/25.
//

import SwiftUI
import Photos


enum MediaFilter: Hashable {
    case videos
    case photos
    case all
}

struct PhotoLibraryPickerView: View {
    @StateObject private var photoLibraryManager = PhotoLibraryManager()
    @Environment(\.dismiss) private var dismiss
    let onVideoSelected: (PHAsset) -> Void
    let onIndividualMediaSelected: ([SavedMediaItem], String) -> Void // Updated signature
    
    @State private var mediaFilter: MediaFilter = .videos
    @State private var selectedAlbum: PhotoAlbum?
    @State private var searchText = ""
    @State private var mediaItems: [MediaItem] = []
    @State private var isLoadingMedia = false
    
    // Multi-selection state - always enabled now
    @State private var selectedMedia: Set<String> = []
    @State private var showingIndividualNaming = false // Show individual naming view
    @State private var pendingAssets: [PHAsset] = []
    
    private let sidebarWidth: CGFloat = 280
    
    let skipCollectionNaming: Bool
    
    var selectedVideoAssets: [PHAsset] {
        mediaItems.compactMap { item in
            selectedMedia.contains(item.id) && item.isVideo ? item.asset : nil
        }
    }
    
    var selectedPhotoAssets: [PHAsset] {
        mediaItems.compactMap { item in
            selectedMedia.contains(item.id) && !item.isVideo ? item.asset : nil
        }
    }
    
    var selectedAllAssets: [PHAsset] {
        mediaItems.compactMap { item in
            selectedMedia.contains(item.id) ? item.asset : nil
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
    
    // Updated initializer
    init(
        onVideoSelected: @escaping (PHAsset) -> Void,
        onIndividualMediaSelected: @escaping ([SavedMediaItem], String) -> Void,
        skipCollectionNaming: Bool = true
    ) {
        self.onVideoSelected = onVideoSelected
        self.onIndividualMediaSelected = onIndividualMediaSelected
        self.skipCollectionNaming = skipCollectionNaming
    }
    
    var body: some View {
        ZStack {
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
                            
                            Picker("Media Type", selection: $mediaFilter) {
                                Text("Videos").tag(MediaFilter.videos)
                                Text("Photos").tag(MediaFilter.photos)
                                Text("All").tag(MediaFilter.all)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        .padding()
                        .padding(.top, 20)
                        
                        Divider()
                        
                        // Albums List
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredAlbums) { album in
                                    AlbumSidebarRow(
                                        album: album,
                                        isSelected: selectedAlbum?.id == album.id,
                                        mediaFilter: mediaFilter
                                    ) {
                                        selectedAlbum = album
                                        Task {
                                            await loadAlbumMedia(album)
                                        }
                                    }
                                }
                            }
                        }
                        
                        Spacer()
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
                            }
                        }
                        .padding()
                        .padding(.top, 20)
                        
                        if selectedAlbum == nil {
                            // Empty State
                            VStack(spacing: 20) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                                Text(emptyPromptForFilter())
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
                                Image(systemName: noMediaIconForFilter())
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                                Text(noMediaTextForFilter())
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
                                            isSelected: selectedMedia.contains(item.id)
                                        ) {
                                            toggleSelection(for: item)
                                        }
                                    }
                                }
                                .padding(8)
                                .padding(.bottom, 100) // Space for floating buttons
                            }
                        }
                    }
                }
            }
            
            // Floating Selection UI
            VStack {
                Spacer()
                
                if !selectedMedia.isEmpty {
                    HStack {
                        // Selection Counter
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                            Text("\(selectedMedia.count) selected")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        .cornerRadius(25)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                        
                        Spacer()
                        
                        // Done Button
                        Button("Done") {
                            handleDoneButtonTap()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(25)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 34) // Safe area bottom
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: selectedMedia.isEmpty)
                }
            }
        }
        .background(Color(.systemBackground))
        .edgesIgnoringSafeArea(.all)
        .task {
            switch photoLibraryManager.authorizationStatus {
            case .authorized, .limited:
                await fetchAlbumsForCurrentFilter()
            case .notDetermined, .denied, .restricted:
                await photoLibraryManager.requestPhotoLibraryAccess()
                // After requesting, fetch based on current filter
                await fetchAlbumsForCurrentFilter()
            @unknown default:
                break
            }
        }
        .onChange(of: mediaFilter) { _, _ in
            Task {
                selectedAlbum = nil
                mediaItems = []
                selectedMedia.removeAll()
                await fetchAlbumsForCurrentFilter()
            }
        }
        // Individual naming sheet
        .sheet(isPresented: $showingIndividualNaming) {
            if !pendingAssets.isEmpty {
                EnhancedMediaNamingView(
                    mediaItems: MediaItemForNaming.createFromAssets(pendingAssets),
                    onCollectionComplete: { namedItems, collectionName in
                        onIndividualMediaSelected(namedItems, collectionName)
                        dismiss()
                    },
                    onCancel: {
                        showingIndividualNaming = false
                        pendingAssets = []
                    },
                    skipCollectionNaming: skipCollectionNaming
                )
            } else {
                // Fallback view if no assets
                VStack(spacing: 20) {
                    Text("No media selected")
                        .font(.title2)
                    
                    Button("Close") {
                        showingIndividualNaming = false
                        pendingAssets = []
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            }
        }
    }
    
    private func createColumns(for width: CGFloat) -> [GridItem] {
        let itemSize: CGFloat = 120
        let spacing: CGFloat = 4
        let availableWidth = width - 16
        let itemsPerRow = max(3, Int(availableWidth / (itemSize + spacing)))
        
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: itemsPerRow)
    }
    
    private func fetchAlbumsForCurrentFilter() async {
        switch mediaFilter {
        case .videos:
            await photoLibraryManager.fetchVideoAlbums()
        case .photos:
            await photoLibraryManager.fetchPhotoAlbums()
        case .all:
            await photoLibraryManager.fetchAllMediaAlbums()
        }
    }
    
    private func loadAlbumMedia(_ album: PhotoAlbum) async {
        isLoadingMedia = true
        selectedMedia.removeAll() // Clear selections when switching albums
        
        switch mediaFilter {
        case .videos:
            let videos = await photoLibraryManager.fetchVideos(from: album)
            mediaItems = videos.map { MediaItem(asset: $0.asset, duration: $0.duration, creationDate: $0.creationDate) }
        case .photos:
            mediaItems = await photoLibraryManager.fetchPhotos(from: album)
        case .all:
            mediaItems = await photoLibraryManager.fetchAllMedia(from: album)
        }
        
        isLoadingMedia = false
    }
    
    private func toggleSelection(for item: MediaItem) {
        // Allow selection of both photos and videos now
        if selectedMedia.contains(item.id) {
            selectedMedia.remove(item.id)
        } else {
            selectedMedia.insert(item.id)
        }
        
        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func handleDoneButtonTap() {
        let allAssets = selectedAllAssets
        print("handleDoneButtonTap called with \(allAssets.count) selected assets")
        print("selectedMedia set contains: \(selectedMedia)")
        print("mediaItems count: \(mediaItems.count)")
        
        if allAssets.count >= 1 {
            // Treat single and multiple selections the same: go to individual naming
            print("Opening individual naming with \(allAssets.count) assets")
            pendingAssets = allAssets
            // Add a small delay to ensure pendingAssets is set before showing sheet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showingIndividualNaming = true
            }
        } else {
            print("No assets selected!")
        }
    }
    
    private func emptyPromptForFilter() -> String {
        switch mediaFilter {
        case .videos: return "Select an album to view videos"
        case .photos: return "Select an album to view photos"
        case .all: return "Select an album to view photos and videos"
        }
    }
    
    private func noMediaIconForFilter() -> String {
        switch mediaFilter {
        case .videos: return "video.slash"
        case .photos: return "photo"
        case .all: return "photo"
        }
    }
    
    private func noMediaTextForFilter() -> String {
        switch mediaFilter {
        case .videos: return "No videos in this album"
        case .photos: return "No photos in this album"
        case .all: return "No media in this album"
        }
    }
}

struct AlbumSidebarRow: View {
    let album: PhotoAlbum
    let isSelected: Bool
    let mediaFilter: MediaFilter
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
                                Image(systemName: placeholderIcon)
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
                        switch mediaFilter {
                        case .videos:
                            Text("\(album.videoCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .photos:
                            Text("\(album.photoCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .all:
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
    
    private var placeholderIcon: String {
        switch mediaFilter {
        case .videos: return "video"
        case .photos: return "photo"
        case .all: return "photo.on.rectangle.angled"
        }
    }
}

struct FullScreenMediaThumbnailView: View {
    let mediaItem: MediaItem
    let photoLibraryManager: PhotoLibraryManager
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
            
            // Media type indicator
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
            
            // Duration badge (for videos only)
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
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
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
    PhotoLibraryPickerView(
        onVideoSelected: { asset in
            print("Selected single media: \(asset.localIdentifier)")
        },
        onIndividualMediaSelected: { namedItems, collectionName in
            print("Selected \(namedItems.count) individually named items")
        }
    )
}
