//
//  CollectionEditView.swift
//  Special children learning app
//
//  Created by AI Assistant
//

//
//  CollectionEditView.swift
//  Special children learning app
//
//  Created by AI Assistant
//

import SwiftUI
import Photos

struct MediaCollectionDetailEditView: View {
    let mediaCollectionItem: MediaCollection
    let onCollectionUpdated: (MediaCollection) -> Void
    
    @State private var mediaItems: [SavedMediaItem]
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var showingMediaItemEditor = false
    @State private var itemToEdit: SavedMediaItem?
    @State private var showingRenameAlert = false
    @State private var newCollectionName = ""
    @State private var currentTitle: String
    
    // NEW: Add media functionality
    @State private var showingAddMediaSelection = false
    @State private var showingAddMediaNaming = false
    @State private var pendingNewAssets: [PHAsset] = []
    
    init(mediaCollection: MediaCollection, onCollectionUpdated: @escaping (MediaCollection) -> Void) {
        self.mediaCollectionItem = mediaCollection
        self.onCollectionUpdated = onCollectionUpdated
        self._mediaItems = State(initialValue: mediaCollection.mediaItems ?? [])
        self._newCollectionName = State(initialValue: mediaCollection.title)
        self._currentTitle = State(initialValue: mediaCollection.title)
    }
    
    // NEW: Computed property for dynamic button subtitle
    private var addMediaButtonSubtitle: String {
        if mediaItems.isEmpty {
            return "Add photos or videos to this collection"
        }
        
        // Check what types of media are currently in the collection
        let identifiers = mediaItems.map { $0.assetIdentifier }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        
        var hasPhotos = false
        var hasVideos = false
        
        fetchResult.enumerateObjects { asset, _, _ in
            if asset.mediaType == .image {
                hasPhotos = true
            } else if asset.mediaType == .video {
                hasVideos = true
            }
        }
        
        if hasPhotos && hasVideos {
            return "Add more photos or videos"
        } else if hasPhotos {
            return "Add more photos"
        } else if hasVideos {
            return "Add more videos"
        } else {
            // Fallback for edge case
            return "Add photos or videos to this collection"
        }
    }

    // NEW: Computed property to determine allowed media filters based on current collection content
    private var allowedMediaFilters: Set<MediaFilter> {
        if mediaItems.isEmpty {
            return [.photos, .videos] // Allow both for empty collections
        }
        
        // Check what types of media are currently in the collection
        let identifiers = mediaItems.map { $0.assetIdentifier }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        
        var hasPhotos = false
        var hasVideos = false
        
        fetchResult.enumerateObjects { asset, _, _ in
            if asset.mediaType == .image {
                hasPhotos = true
            } else if asset.mediaType == .video {
                hasVideos = true
            }
        }
        
        if hasPhotos && !hasVideos {
            return [.photos] // Only allow photos
        } else if hasVideos && !hasPhotos {
            return [.videos] // Only allow videos
        } else {
            // Mixed content - allow both (shouldn't happen often but good fallback)
            return [.photos, .videos]
        }
    }
    
    // NEW: Computed property to determine initial filter
    private var preferredMediaFilter: MediaFilter {
        let allowed = allowedMediaFilters
        if allowed.contains(.photos) {
            return .photos
        } else if allowed.contains(.videos) {
            return .videos
        } else {
            return .photos // Fallback
        }
    }

    var body: some View {
        List {
            // NEW: Add Media Button Section
            Section {
                Button(action: {
                    showingAddMediaSelection = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add More Media")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(addMediaButtonSubtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Existing media items
            Section("Current Items (\(mediaItems.count))") {
                ForEach(mediaItems) { item in
                    Button(action: {
                        itemToEdit = item
                    }) {
                        HStack(spacing: 16) {
                            // Thumbnail
                            if let thumbnail = thumbnails[item.assetIdentifier] {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                    }
                            }
                            
                            // Name and audio indicator
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.customName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if item.audioRecordingFileName != nil {
                                    HStack(spacing: 4) {
                                        Image(systemName: "mic.fill")
                                            .font(.caption)
                                        Text("Audio")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .onMove(perform: moveItems)
                .onDelete(perform: deleteItems)
            }
        }
        .listStyle(PlainListStyle())
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: {
                    newCollectionName = currentTitle
                    showingRenameAlert = true
                }) {
                    HStack(spacing: 4) {
                        Text("Edit '\(currentTitle)'")
                            .font(.headline)
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .alert("Rename Collection", isPresented: $showingRenameAlert) {
            TextField("Collection name", text: $newCollectionName)
                .textInputAutocapitalization(.words)
            
            Button("Save") {
                renameCollection()
            }
            .disabled(newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            Button("Cancel", role: .cancel) {
                newCollectionName = currentTitle
            }
        } message: {
            Text("Enter a new name for your collection")
        }
        .onAppear {
            loadThumbnails()
        }
        .sheet(item: $itemToEdit) { item in
            MediaItemEditView(
                mediaItem: item,
                collectionId: mediaCollectionItem.id,
                onSave: { updatedItem in
                    // The updatedItem from onSave now contains the LATEST name and audio state.
                    // Simply update local state with this item.
                    if let index = mediaItems.firstIndex(where: { $0.id == updatedItem.id }) {
                        mediaItems.remove(at: index)
                        mediaItems.insert(updatedItem, at: index)
                    }
                    
                    // Persist change
                    VideoCollectionPersistence.shared.updateMediaItemInCollection(mediaCollectionItem.id, updatedMediaItem: updatedItem)
                    
                    // Notify parent view
                    notifyParentOfUpdate()
                    
                    itemToEdit = nil
                },
                onCancel: {
                    itemToEdit = nil
                }
            )
        }
        // NEW: Media selection for adding to existing collection
        .fullScreenCover(isPresented: $showingAddMediaSelection) {
            PhotoLibraryPickerView(
                onVideoSelected: { selectedAsset in
                    // Handle single asset selection - convert to array and proceed to naming
                    pendingNewAssets = [selectedAsset]
                    showingAddMediaNaming = true
                },
                onIndividualMediaSelected: { namedItems, _ in
                    // For adding to existing collection, ignore the collection name
                    // and just add the named items
                    addNamedItemsToExistingCollection(namedItems)
                },
                skipCollectionNaming: true,
                initialFilter: preferredMediaFilter,
                allowedFilters: allowedMediaFilters
            )
        }
        // MODIFIED: Use skipCollectionNaming parameter
        .sheet(isPresented: $showingAddMediaNaming) {
            if !pendingNewAssets.isEmpty {
                EnhancedMediaNamingView(
                    mediaItems: MediaItemForNaming.createFromAssets(pendingNewAssets),
                    onCollectionComplete: { namedItems, _ in
                        // For adding to existing collection, ignore the collection name
                        // and just add the named items
                        addNamedItemsToExistingCollection(namedItems)
                        showingAddMediaNaming = false
                        pendingNewAssets = []
                    },
                    onCancel: {
                        showingAddMediaNaming = false
                        pendingNewAssets = []
                    },
                    skipCollectionNaming: true // 🎯 THIS IS THE KEY FIX!
                )
                .interactiveDismissDisabled()
            }
        }
    }
    
    // NEW: Add named items to the existing collection
    private func addNamedItemsToExistingCollection(_ namedItems: [SavedMediaItem]) {
        print("🆕 Adding \(namedItems.count) new items to existing collection '\(currentTitle)'")
        
        // Add to local state
        mediaItems.append(contentsOf: namedItems)
        
        // Update persistence
        VideoCollectionPersistence.shared.updateCollection(mediaCollectionItem.id, with: mediaItems)
        
        // Notify parent view
        notifyParentOfUpdate()
        
        // Load thumbnails for new items
        loadThumbnails()
        
        print("✅ Successfully added \(namedItems.count) items to collection")
    }
    
    private func loadThumbnails() {
        let identifiers = mediaItems.map { $0.assetIdentifier }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        
        fetchResult.enumerateObjects { asset, _, _ in
            manager.requestImage(
                for: asset,
                targetSize: CGSize(width: 120, height: 120),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image = image {
                    DispatchQueue.main.async {
                        self.thumbnails[asset.localIdentifier] = image
                    }
                }
            }
        }
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        mediaItems.move(fromOffsets: source, toOffset: destination)
        VideoCollectionPersistence.shared.updateCollection(mediaCollectionItem.id, with: mediaItems)
        notifyParentOfUpdate()
    }
    
    private func deleteItems(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { mediaItems[$0] }
        mediaItems.remove(atOffsets: offsets)
        
        for item in itemsToDelete {
            VideoCollectionPersistence.shared.removeMediaItemFromCollection(mediaCollectionItem.id, mediaItemId: item.id)
        }
        notifyParentOfUpdate()
    }
    
    private func notifyParentOfUpdate() {
        let updatedmediaCollection = mediaCollectionItem.updatingMediaItems(with: mediaItems)
        onCollectionUpdated(updatedmediaCollection)
    }

    private func renameCollection() {
        let cleanName = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Update local title state first for immediate UI update
        currentTitle = cleanName
        
        // Update in persistence
        VideoCollectionPersistence.shared.renameCollectionById(mediaCollectionItem.id, newTitle: cleanName)
        
        // Create updated activity with new name but preserve all other properties
        let updatedmediaCollection = mediaCollectionItem.updatingTitle(to: cleanName)
        
        // Notify parent view
        onCollectionUpdated(updatedmediaCollection)
        
        print("✅ Collection renamed to '\(cleanName)'")
    }
}

// Extensions remain the same...
extension MediaCollection {
    func updatingMediaItems(with newItems: [SavedMediaItem]) -> MediaCollection {
        // Re-fetch assets based on new order and items
        let identifiers = newItems.map { $0.assetIdentifier }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        
        var fetchedAssets: [String: PHAsset] = [:]
        fetchResult.enumerateObjects { asset, _, _ in
            fetchedAssets[asset.localIdentifier] = asset
        }
        
        // Reorder assets to match newItems order
        let assets = identifiers.compactMap { fetchedAssets[$0] }
        
        let videoAssets = assets.filter { $0.mediaType == .video }
        let photoAssets = assets.filter { $0.mediaType == .image }
        
        return MediaCollection(
            id: self.id,
            title: self.title,
            imageName: self.imageName,
            videoAssets: videoAssets.isEmpty ? nil : videoAssets,
            photoAssets: photoAssets.isEmpty ? nil : photoAssets,
            mediaItems: newItems,
            audioDescription: self.audioDescription,
            backgroundColor: self.backgroundColor
        )
    }

    func updatingTitle(to newTitle: String) -> MediaCollection {
        // Create a new ActivityItem with updated title but preserve ALL properties
        if let videoAssets = self.videoAssets, let photoAssets = self.photoAssets {
            // Mixed media collection
            return MediaCollection(
                id: self.id,
                title: newTitle,
                imageName: self.imageName,
                videoAssets: videoAssets,
                photoAssets: photoAssets,
                mediaItems: self.mediaItems,
                audioDescription: self.audioDescription,
                backgroundColor: self.backgroundColor
            )
        } else if let videoAssets = self.videoAssets {
            // Video collection
            return MediaCollection(
                id: self.id,
                title: newTitle,
                imageName: self.imageName,
                videoAssets: videoAssets,
                photoAssets: nil,
                mediaItems: self.mediaItems,
                audioDescription: self.audioDescription,
                backgroundColor: self.backgroundColor
            )
        } else if let photoAssets = self.photoAssets {
            // Photo collection
            return MediaCollection(
                id: self.id,
                title: newTitle,
                imageName: self.imageName,
                videoAssets: nil,
                photoAssets: photoAssets,
                mediaItems: self.mediaItems,
                audioDescription: self.audioDescription,
                backgroundColor: self.backgroundColor
            )
        } else if let videoAsset = self.videoAsset {
            // Single video
            return MediaCollection(
                id: self.id,
                title: newTitle,
                imageName: self.imageName,
                videoAsset: videoAsset,
                audioDescription: self.audioDescription,
                backgroundColor: self.backgroundColor
            )
        } else if let photoAsset = self.photoAsset {
            // Single photo
            return MediaCollection(
                id: self.id,
                title: newTitle,
                imageName: self.imageName,
                photoAsset: photoAsset,
                audioDescription: self.audioDescription,
                backgroundColor: self.backgroundColor
            )
        } else {
            // Fallback - preserve as much as possible
            return MediaCollection(
                id: self.id,
                title: newTitle,
                imageName: self.imageName,
                videoAssets: nil,
                photoAssets: nil,
                mediaItems: self.mediaItems,
                audioDescription: self.audioDescription,
                backgroundColor: self.backgroundColor
            )
        }
    }
}

#Preview {
    NavigationView {
        MediaCollectionDetailEditView(
            mediaCollection: MediaCollection.sampleActivities.first(where: { $0.isVideoCollection })!,
            onCollectionUpdated: { _ in }
        )
    }
}

