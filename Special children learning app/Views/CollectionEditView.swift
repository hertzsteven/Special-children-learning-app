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

struct CollectionEditView: View {
    let activityItem: ActivityItem
    let onCollectionUpdated: (ActivityItem) -> Void
    
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
    
    init(activity: ActivityItem, onCollectionUpdated: @escaping (ActivityItem) -> Void) {
        self.activityItem = activity
        self.onCollectionUpdated = onCollectionUpdated
        self._mediaItems = State(initialValue: activity.mediaItems ?? [])
        self._newCollectionName = State(initialValue: activity.title)
        self._currentTitle = State(initialValue: activity.title)
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
                            Text("Add photos or videos to this collection")
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
                        showingMediaItemEditor = true
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
        .sheet(isPresented: $showingMediaItemEditor) {
            if let itemToEdit = itemToEdit {
                MediaItemEditView(
                    mediaItem: itemToEdit,
                    collectionId: activityItem.id,
                    onSave: { updatedItem in
                        // The updatedItem from onSave now contains the LATEST name and audio state.
                        // Simply update local state with this item.
                        if let index = mediaItems.firstIndex(where: { $0.id == updatedItem.id }) {
                            mediaItems.remove(at: index)
                            mediaItems.insert(updatedItem, at: index)
//                            mediaItems[index] = updatedItem
                        }
                        
                        // Persist change
                        VideoCollectionPersistence.shared.updateMediaItemInCollection(activityItem.id, updatedMediaItem: updatedItem)
                        
                        // Notify parent view
                        notifyParentOfUpdate()
                        
                        showingMediaItemEditor = false
                    },
                    onCancel: {
                        showingMediaItemEditor = false
                    }
                )
            }
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
                }
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
            }
        }
    }
    
    // NEW: Add named items to the existing collection
    private func addNamedItemsToExistingCollection(_ namedItems: [SavedMediaItem]) {
        print("🆕 Adding \(namedItems.count) new items to existing collection '\(currentTitle)'")
        
        // Add to local state
        mediaItems.append(contentsOf: namedItems)
        
        // Update persistence
        VideoCollectionPersistence.shared.updateCollection(activityItem.id, with: mediaItems)
        
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
        VideoCollectionPersistence.shared.updateCollection(activityItem.id, with: mediaItems)
        notifyParentOfUpdate()
    }
    
    private func deleteItems(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { mediaItems[$0] }
        mediaItems.remove(atOffsets: offsets)
        
        for item in itemsToDelete {
            VideoCollectionPersistence.shared.removeMediaItemFromCollection(activityItem.id, mediaItemId: item.id)
        }
        notifyParentOfUpdate()
    }
    
    private func notifyParentOfUpdate() {
        let updatedActivity = activityItem.updatingMediaItems(with: mediaItems)
        onCollectionUpdated(updatedActivity)
    }

    private func renameCollection() {
        let cleanName = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Update local title state first for immediate UI update
        currentTitle = cleanName
        
        // Update in persistence
        VideoCollectionPersistence.shared.renameCollectionById(activityItem.id, newTitle: cleanName)
        
        // Create updated activity with new name but preserve all other properties
        let updatedActivity = activityItem.updatingTitle(to: cleanName)
        
        // Notify parent view
        onCollectionUpdated(updatedActivity)
        
        print("✅ Collection renamed to '\(cleanName)'")
    }
}

// Extensions remain the same...
extension ActivityItem {
    func updatingMediaItems(with newItems: [SavedMediaItem]) -> ActivityItem {
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
        
        return ActivityItem(
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

    func updatingTitle(to newTitle: String) -> ActivityItem {
        // Create a new ActivityItem with updated title but preserve ALL properties
        if let videoAssets = self.videoAssets, let photoAssets = self.photoAssets {
            // Mixed media collection
            return ActivityItem(
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
            return ActivityItem(
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
            return ActivityItem(
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
            return ActivityItem(
                id: self.id,
                title: newTitle,
                imageName: self.imageName,
                videoAsset: videoAsset,
                audioDescription: self.audioDescription,
                backgroundColor: self.backgroundColor
            )
        } else if let photoAsset = self.photoAsset {
            // Single photo
            return ActivityItem(
                id: self.id,
                title: newTitle,
                imageName: self.imageName,
                photoAsset: photoAsset,
                audioDescription: self.audioDescription,
                backgroundColor: self.backgroundColor
            )
        } else {
            // Fallback - preserve as much as possible
            return ActivityItem(
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
        CollectionEditView(
            activity: ActivityItem.sampleActivities.first(where: { $0.isVideoCollection })!,
            onCollectionUpdated: { _ in }
        )
    }
}

//struct CollectionEditView: View {
//    let activityItem: ActivityItem
//    let onCollectionUpdated: (ActivityItem) -> Void
//    
//    @State private var mediaItems: [SavedMediaItem]
//    @State private var thumbnails: [String: UIImage] = [:]
//    @State private var showingMediaItemEditor = false
//    @State private var itemToEdit: SavedMediaItem?
//    @State private var showingRenameAlert = false
//    @State private var newCollectionName = ""
//    @State private var currentTitle: String
//    
//    // NEW: States for adding media
//    @State private var showingAddMedia = false
//    @State private var showingToast = false
//    @State private var toastMessage = ""
//    
//    init(activity: ActivityItem, onCollectionUpdated: @escaping (ActivityItem) -> Void) {
//        print("-----",activity.title)
//        print("-----",activity.id)
//        dump(activity)
//        print("-----")
//        
//        self.activityItem = activity
//        self.onCollectionUpdated = onCollectionUpdated
//        self._mediaItems = State(initialValue: activity.mediaItems ?? [])
//        self._newCollectionName = State(initialValue: activity.title)
//        self._currentTitle = State(initialValue: activity.title)
//    }
//    
//    var body: some View {
//        List {
//            // NEW: Add Media Section
//            Section {
//                Button(action: {
//                    showingAddMedia = true
//                }) {
//                    HStack {
//                        Image(systemName: "plus.circle.fill")
//                            .font(.title2)
//                            .foregroundColor(.blue)
//                        
//                        VStack(alignment: .leading, spacing: 4) {
//                            Text("Add Media")
//                                .font(.headline)
//                                .foregroundColor(.blue)
//                            Text("Add photos or videos from your library")
//                                .font(.caption)
//                                .foregroundColor(.secondary)
//                        }
//                        
//                        Spacer()
//                        
//                        Image(systemName: "chevron.right")
//                            .foregroundColor(.secondary)
//                    }
//                    .padding(.vertical, 8)
//                }
//            }
//            
//            // Existing Media Items Section
//            if !mediaItems.isEmpty {
//                Section("Media Items (\(mediaItems.count))") {
//                    ForEach(mediaItems) { item in
//                        Button(action: {
//                            itemToEdit = item
//                            showingMediaItemEditor = true
//                        }) {
//                            HStack(spacing: 16) {
//                                // Thumbnail
//                                if let thumbnail = thumbnails[item.assetIdentifier] {
//                                    Image(uiImage: thumbnail)
//                                        .resizable()
//                                        .aspectRatio(contentMode: .fill)
//                                        .frame(width: 60, height: 60)
//                                        .clipShape(RoundedRectangle(cornerRadius: 8))
//                                } else {
//                                    RoundedRectangle(cornerRadius: 8)
//                                        .fill(Color.gray.opacity(0.3))
//                                        .frame(width: 60, height: 60)
//                                        .overlay {
//                                            Image(systemName: "photo")
//                                                .foregroundColor(.gray)
//                                        }
//                                }
//                                
//                                // Name and audio indicator
//                                VStack(alignment: .leading, spacing: 4) {
//                                    Text(item.customName)
//                                        .font(.headline)
//                                        .foregroundColor(.primary)
//                                    
//                                    if item.audioRecordingFileName != nil {
//                                        HStack(spacing: 4) {
//                                            Image(systemName: "mic.fill")
//                                                .font(.caption)
//                                            Text("Audio")
//                                                .font(.caption)
//                                        }
//                                        .foregroundColor(.secondary)
//                                    }
//                                }
//                                
//                                Spacer()
//                                
//                                Image(systemName: "chevron.right")
//                                    .foregroundColor(.secondary)
//                            }
//                            .padding(.vertical, 8)
//                        }
//                    }
//                    .onMove(perform: moveItems)
//                    .onDelete(perform: deleteItems)
//                }
//            }
//        }
//        .listStyle(PlainListStyle())
//        .toolbar {
//            ToolbarItem(placement: .principal) {
//                Button(action: {
//                    newCollectionName = currentTitle
//                    showingRenameAlert = true
//                }) {
//                    HStack(spacing: 4) {
//                        Text("Edit '\(currentTitle)'")
//                            .font(.headline)
//                        Image(systemName: "pencil")
//                            .font(.caption)
//                    }
//                }
//            }
//            ToolbarItem(placement: .navigationBarTrailing) {
//                EditButton()
//            }
//        }
//        // NEW: Full screen media selection
//        .fullScreenCover(isPresented: $showingAddMedia) {
//            FullScreenMediaSelectionView(
//                onVideoSelected: { selectedAsset in
//                    // Handle single media selection
//                    handleSingleMediaSelection(asset: selectedAsset)
//                },
//                onIndividualMediaSelected: { namedItems, _ in
//                    // Handle multiple media selection (ignore collection name since we're adding to existing)
//                    handleMultipleMediaSelection(namedItems: namedItems)
//                }
//            )
//        }
//        .alert("Rename Collection", isPresented: $showingRenameAlert) {
//            TextField("Collection name", text: $newCollectionName)
//                .textInputAutocapitalization(.words)
//            
//            Button("Save") {
//                renameCollection()
//            }
//            .disabled(newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
//            
//            Button("Cancel", role: .cancel) {
//                newCollectionName = currentTitle
//            }
//        } message: {
//            Text("Enter a new name for your collection")
//        }
//        .onAppear {
//            loadThumbnails()
//        }
//        .sheet(isPresented: $showingMediaItemEditor) {
//            if let itemToEdit = itemToEdit {
//                MediaItemEditView(
//                    mediaItem: itemToEdit,
//                    onSave: { updatedItem in
//                        // Update local state
//                        if let index = mediaItems.firstIndex(where: { $0.id == updatedItem.id }) {
//                            mediaItems.remove(at: index)
//                            mediaItems.insert(updatedItem, at: index)
////                            mediaItems[index].customName = updatedItem.customName
//                            dump(mediaItems[index])
//                            print(index)
//                        }
//                        
//                        // Persist change
//                        VideoCollectionPersistence.shared.updateMediaItemInCollection(activityItem.id, updatedMediaItem: updatedItem)
//                        
//                        // Notify parent view
//                        notifyParentOfUpdate()
//                        
//                        showingMediaItemEditor = false
//                    },
//                    onCancel: {
//                        showingMediaItemEditor = false
//                    }
//                )
//            }
//        }
//        // NEW: Toast notifications (uses your existing toast system)
//        .toast(isShowing: $showingToast, message: toastMessage)
//    }
//    
//    // NEW: Handle single media selection
//    private func handleSingleMediaSelection(asset: PHAsset) {
//        // Create a quick name based on media type and date
//        let defaultName = generateDefaultName(for: asset)
//        
//        // Create SavedMediaItem
//        let newMediaItem = SavedMediaItem(
//            assetIdentifier: asset.localIdentifier,
//            customName: defaultName,
//            audioRecordingFileName: nil
//        )
//        
//        // Add to collection
//        addMediaItemToCollection(newMediaItem)
//        
//        showToast("Added '\(defaultName)' to collection")
//    }
//    
//    // NEW: Handle multiple media selection
//    private func handleMultipleMediaSelection(namedItems: [SavedMediaItem]) {
//        // Use batch method for efficiency
//        VideoCollectionPersistence.shared.addMultipleMediaItemsToCollection(activityItem.id, mediaItems: namedItems)
//        
//        // Update local state
//        mediaItems.append(contentsOf: namedItems)
//        
//        // Refresh thumbnails for new items
//        loadThumbnailsForNewItems(namedItems.map { $0.assetIdentifier })
//        
//        // Notify parent view
//        notifyParentOfUpdate()
//        
//        let count = namedItems.count
//        showToast("Added \(count) item\(count == 1 ? "" : "s") to collection")
//    }
//    
//    // NEW: Add single media item to collection
//    private func addMediaItemToCollection(_ mediaItem: SavedMediaItem) {
//        // Add to persistence
//        VideoCollectionPersistence.shared.addMediaItemToCollection(activityItem.id, mediaItem: mediaItem)
//        
//        // Add to local state
//        mediaItems.append(mediaItem)
//        
//        // Load thumbnail for new item
//        loadThumbnailsForNewItems([mediaItem.assetIdentifier])
//        
//        // Notify parent view
//        notifyParentOfUpdate()
//    }
//    
//    // NEW: Generate default name for new media
//    private func generateDefaultName(for asset: PHAsset) -> String {
//        let formatter = DateFormatter()
//        let creationDate = asset.creationDate ?? Date()
//        
//        if asset.mediaType == .video {
//            formatter.dateFormat = "EEEE"
//            let dayOfWeek = formatter.string(from: creationDate)
//            return "\(dayOfWeek) Video"
//        } else {
//            formatter.dateFormat = "MMMM d"
//            let monthDay = formatter.string(from: creationDate)
//            return "\(monthDay) Photo"
//        }
//    }
//    
//    // NEW: Load thumbnails for specific asset identifiers
//    private func loadThumbnailsForNewItems(_ identifiers: [String]) {
//        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
//        
//        let manager = PHImageManager.default()
//        let options = PHImageRequestOptions()
//        options.isSynchronous = false
//        options.deliveryMode = .opportunistic
//        
//        fetchResult.enumerateObjects { asset, _, _ in
//            manager.requestImage(
//                for: asset,
//                targetSize: CGSize(width: 120, height: 120),
//                contentMode: .aspectFill,
//                options: options
//            ) { image, _ in
//                if let image = image {
//                    DispatchQueue.main.async {
//                        self.thumbnails[asset.localIdentifier] = image
//                    }
//                }
//            }
//        }
//    }
//    
//    // NEW: Show toast message
//    private func showToast(_ message: String) {
//        toastMessage = message
//        showingToast = true
//    }
//    
//    private func loadThumbnails() {
//        let identifiers = mediaItems.map { $0.assetIdentifier }
//        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
//        
//        let manager = PHImageManager.default()
//        let options = PHImageRequestOptions()
//        options.isSynchronous = false
//        options.deliveryMode = .opportunistic
//        
//        fetchResult.enumerateObjects { asset, _, _ in
//            manager.requestImage(
//                for: asset,
//                targetSize: CGSize(width: 120, height: 120),
//                contentMode: .aspectFill,
//                options: options
//            ) { image, _ in
//                if let image = image {
//                    DispatchQueue.main.async {
//                        self.thumbnails[asset.localIdentifier] = image
//                    }
//                }
//            }
//        }
//    }
//    
//    private func moveItems(from source: IndexSet, to destination: Int) {
//        mediaItems.move(fromOffsets: source, toOffset: destination)
//        VideoCollectionPersistence.shared.updateCollection(activityItem.id, with: mediaItems)
//        notifyParentOfUpdate()
//    }
//    
//    private func deleteItems(at offsets: IndexSet) {
//        let itemsToDelete = offsets.map { mediaItems[$0] }
//        mediaItems.remove(atOffsets: offsets)
//        
//        for item in itemsToDelete {
//            VideoCollectionPersistence.shared.removeMediaItemFromCollection(activityItem.id, mediaItemId: item.id)
//        }
//        notifyParentOfUpdate()
//    }
//    
//    private func notifyParentOfUpdate() {
//        let updatedActivity = activityItem.updatingMediaItems(with: mediaItems)
//        onCollectionUpdated(updatedActivity)
//    }
//
//    private func renameCollection() {
//        let cleanName = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
//        
//        // Update local title state first for immediate UI update
//        currentTitle = cleanName
//        
//        // Update in persistence
//        VideoCollectionPersistence.shared.renameCollectionById(activityItem.id, newTitle: cleanName)
//        
//        // Create updated activity with new name but preserve all other properties
//        let updatedActivity = activityItem.updatingTitle(to: cleanName)
//        
//        // Notify parent view
//        onCollectionUpdated(updatedActivity)
//        
//        print("✅ Collection renamed to '\(cleanName)'")
//    }
//}
//
//// MARK: - Extensions
//
//extension ActivityItem {
//    func updatingMediaItems(with newItems: [SavedMediaItem]) -> ActivityItem {
//        // Re-fetch assets based on new order and items
//        let identifiers = newItems.map { $0.assetIdentifier }
//        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
//        
//        var fetchedAssets: [String: PHAsset] = [:]
//        fetchResult.enumerateObjects { asset, _, _ in
//            fetchedAssets[asset.localIdentifier] = asset
//        }
//        
//        // Reorder assets to match newItems order
//        let assets = identifiers.compactMap { fetchedAssets[$0] }
//        
//        let videoAssets = assets.filter { $0.mediaType == .video }
//        let photoAssets = assets.filter { $0.mediaType == .image }
//        
//        // Create new ActivityItem with updated properties
//        return ActivityItem(
//            id: self.id,
//            title: self.title,
//            imageName: self.imageName,
//            videoAssets: videoAssets.isEmpty ? nil : videoAssets,
//            photoAssets: photoAssets.isEmpty ? nil : photoAssets,
//            mediaItems: newItems,
//            audioDescription: "A collection of \(newItems.count) items: \(newItems.map { $0.customName }.joined(separator: ", "))",
//            backgroundColor: self.backgroundColor
//        )
//    }
//
//    func updatingTitle(to newTitle: String) -> ActivityItem {
//        return ActivityItem(
//            id: self.id,
//            title: newTitle,
//            imageName: self.imageName,
//            videoAssets: self.videoAssets,
//            photoAssets: self.photoAssets,
//            mediaItems: self.mediaItems,
//            audioDescription: self.audioDescription,
//            backgroundColor: self.backgroundColor
//        )
//    }
//}
//
//#Preview {
//    NavigationView {
//        CollectionEditView(
//            activity: ActivityItem.sampleActivities.first(where: { $0.isVideoCollection })!,
//            onCollectionUpdated: { _ in }
//        )
//    }
//}

//
//struct CollectionEditView: View {
//    let activityItem: ActivityItem
//    let onCollectionUpdated: (ActivityItem) -> Void
//    
//    @State private var mediaItems: [SavedMediaItem]
//    @State private var thumbnails: [String: UIImage] = [:]
//    @State private var showingMediaItemEditor = false
//    @State private var itemToEdit: SavedMediaItem?
//    @State private var showingRenameAlert = false
//    @State private var newCollectionName = ""
//    @State private var currentTitle: String
//    
//    init(activity: ActivityItem, onCollectionUpdated: @escaping (ActivityItem) -> Void) {
//        print("-----",activity.title)
//        print("-----",activity.id)
//        dump(activity)
//
//        print("-----")
//        self.activityItem = activity
//        self.onCollectionUpdated = onCollectionUpdated
//        self._mediaItems = State(initialValue: activity.mediaItems ?? [])
//        self._newCollectionName = State(initialValue: activity.title)
//        self._currentTitle = State(initialValue: activity.title)
//    }
//    
//    var body: some View {
//        List {
//            ForEach(mediaItems) { item in
//                Button(action: {
//                    itemToEdit = item
//                    showingMediaItemEditor = true
//                }) {
//                    HStack(spacing: 16) {
//                        // Thumbnail
//                        if let thumbnail = thumbnails[item.assetIdentifier] {
//                            Image(uiImage: thumbnail)
//                                .resizable()
//                                .aspectRatio(contentMode: .fill)
//                                .frame(width: 60, height: 60)
//                                .clipShape(RoundedRectangle(cornerRadius: 8))
//                        } else {
//                            RoundedRectangle(cornerRadius: 8)
//                                .fill(Color.gray.opacity(0.3))
//                                .frame(width: 60, height: 60)
//                                .overlay {
//                                    Image(systemName: "photo")
//                                        .foregroundColor(.gray)
//                                }
//                        }
//                        
//                        // Name and audio indicator
//                        VStack(alignment: .leading, spacing: 4) {
//                            Text(item.customName)
//                                .font(.headline)
//                                .foregroundColor(.primary)
//                            
//                            if item.audioRecordingFileName != nil {
//                                HStack(spacing: 4) {
//                                    Image(systemName: "mic.fill")
//                                        .font(.caption)
//                                    Text("Audio")
//                                        .font(.caption)
//                                }
//                                .foregroundColor(.secondary)
//                            }
//                        }
//                        
//                        Spacer()
//                        
//                        Image(systemName: "chevron.right")
//                            .foregroundColor(.secondary)
//                    }
//                    .padding(.vertical, 8)
//                }
//            }
//            .onMove(perform: moveItems)
//            .onDelete(perform: deleteItems)
//        }
//        .listStyle(PlainListStyle())
//        .toolbar {
//            ToolbarItem(placement: .principal) {
//                Button(action: {
//                    newCollectionName = currentTitle
//                    showingRenameAlert = true
//                }) {
//                    HStack(spacing: 4) {
//                        Text("Edit '\(currentTitle)'")
//                            .font(.headline)
//                        Image(systemName: "pencil")
//                            .font(.caption)
//                    }
//                }
//            }
//            ToolbarItem(placement: .navigationBarTrailing) {
//                EditButton()
//            }
//        }
//        .alert("Rename Collection", isPresented: $showingRenameAlert) {
//            TextField("Collection name", text: $newCollectionName)
//                .textInputAutocapitalization(.words)
//            
//            Button("Save") {
//                renameCollection()
//            }
//            .disabled(newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
//            
//            Button("Cancel", role: .cancel) {
//                newCollectionName = currentTitle
//            }
//        } message: {
//            Text("Enter a new name for your collection")
//        }
//        .onAppear {
//            loadThumbnails()
//        }
//        .sheet(isPresented: $showingMediaItemEditor) {
//            if let itemToEdit = itemToEdit {
//                MediaItemEditView(
//                    mediaItem: itemToEdit,
//                    onSave: { updatedItem in
//                        // Update local state
//                        if let index = mediaItems.firstIndex(where: { $0.id == updatedItem.id }) {
//                            mediaItems.remove(at: index)
//                            mediaItems.insert(updatedItem, at: index)
////                            mediaItems[index].customName = updatedItem.customName
//                            dump(mediaItems[index])
//                            print(index)
//                        }
//                        
//                        // Persist change
//                        VideoCollectionPersistence.shared.updateMediaItemInCollection(activityItem.id, updatedMediaItem: updatedItem)
//                        
//                        // Notify parent view
//                        notifyParentOfUpdate()
//                        
//                        showingMediaItemEditor = false
//                    },
//                    onCancel: {
//                        showingMediaItemEditor = false
//                    }
//                )
//            }
//        }
//    }
//    
//    private func loadThumbnails() {
//        let identifiers = mediaItems.map { $0.assetIdentifier }
//        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
//        
//        let manager = PHImageManager.default()
//        let options = PHImageRequestOptions()
//        options.isSynchronous = false
//        options.deliveryMode = .opportunistic
//        
//        fetchResult.enumerateObjects { asset, _, _ in
//            manager.requestImage(
//                for: asset,
//                targetSize: CGSize(width: 120, height: 120),
//                contentMode: .aspectFill,
//                options: options
//            ) { image, _ in
//                if let image = image {
//                    DispatchQueue.main.async {
//                        self.thumbnails[asset.localIdentifier] = image
//                    }
//                }
//            }
//        }
//    }
//    
//    private func moveItems(from source: IndexSet, to destination: Int) {
//        mediaItems.move(fromOffsets: source, toOffset: destination)
//        VideoCollectionPersistence.shared.updateCollection(activityItem.id, with: mediaItems)
//        notifyParentOfUpdate()
//    }
//    
//    private func deleteItems(at offsets: IndexSet) {
//        let itemsToDelete = offsets.map { mediaItems[$0] }
//        mediaItems.remove(atOffsets: offsets)
//        
//        for item in itemsToDelete {
//            VideoCollectionPersistence.shared.removeMediaItemFromCollection(activityItem.id, mediaItemId: item.id)
//        }
//        notifyParentOfUpdate()
//    }
//    
//    private func notifyParentOfUpdate() {
//        let updatedActivity = activityItem.updatingMediaItems(with: mediaItems)
//        onCollectionUpdated(updatedActivity)
//    }
//
//    private func renameCollection() {
//        let cleanName = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
//        
//        // Update local title state first for immediate UI update
//        currentTitle = cleanName
//        
//        // Update in persistence
//        VideoCollectionPersistence.shared.renameCollectionById(activityItem.id, newTitle: cleanName)
//        
//        // Create updated activity with new name but preserve all other properties
//        let updatedActivity = activityItem.updatingTitle(to: cleanName)
//        
//        // Notify parent view
//        onCollectionUpdated(updatedActivity)
//        
//        print("✅ Collection renamed to '\(cleanName)'")
//    }
//}
//
//extension ActivityItem {
//    func updatingMediaItems(with newItems: [SavedMediaItem]) -> ActivityItem {
//        var updatedActivity = self
//        updatedActivity.mediaItems = newItems
//        
//        // Re-fetch assets based on new order and items
//        let identifiers = newItems.map { $0.assetIdentifier }
//        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
//        
//        var assets: [PHAsset] = []
//        let orderedIdentifiers = newItems.map { $0.assetIdentifier }
//        
//        var fetchedAssets: [String: PHAsset] = [:]
//        fetchResult.enumerateObjects { asset, _, _ in
//            fetchedAssets[asset.localIdentifier] = asset
//        }
//        
//        // Reorder assets to match newItems order
//        assets = orderedIdentifiers.compactMap { fetchedAssets[$0] }
//        
//        updatedActivity.videoAssets = assets.filter { $0.mediaType == .video }
//        updatedActivity.photoAssets = assets.filter { $0.mediaType == .image }
//        
//        return updatedActivity
//    }
//
//    func updatingTitle(to newTitle: String) -> ActivityItem {
//        // Create a new ActivityItem with updated title but preserve ALL properties
//        if let videoAssets = self.videoAssets, let photoAssets = self.photoAssets {
//            // Mixed media collection
//            return ActivityItem(
//                id: self.id,
//                title: newTitle,
//                imageName: self.imageName,
//                videoAssets: videoAssets,
//                photoAssets: photoAssets,
//                mediaItems: self.mediaItems,
//                audioDescription: self.audioDescription,
//                backgroundColor: self.backgroundColor
//            )
//        } else if let videoAssets = self.videoAssets {
//            // Video collection
//            return ActivityItem(
//                id: self.id,
//                title: newTitle,
//                imageName: self.imageName,
//                videoAssets: videoAssets,
//                photoAssets: nil,
//                mediaItems: self.mediaItems,
//                audioDescription: self.audioDescription,
//                backgroundColor: self.backgroundColor
//            )
//        } else if let photoAssets = self.photoAssets {
//            // Photo collection
//            return ActivityItem(
//                id: self.id,
//                title: newTitle,
//                imageName: self.imageName,
//                videoAssets: nil,
//                photoAssets: photoAssets,
//                mediaItems: self.mediaItems,
//                audioDescription: self.audioDescription,
//                backgroundColor: self.backgroundColor
//            )
//        } else if let videoAsset = self.videoAsset {
//            // Single video
//            return ActivityItem(
//                id: self.id,
//                title: newTitle,
//                imageName: self.imageName,
//                videoAsset: videoAsset,
//                audioDescription: self.audioDescription,
//                backgroundColor: self.backgroundColor
//            )
//        } else if let photoAsset = self.photoAsset {
//            // Single photo
//            return ActivityItem(
//                id: self.id,
//                title: newTitle,
//                imageName: self.imageName,
//                photoAsset: photoAsset,
//                audioDescription: self.audioDescription,
//                backgroundColor: self.backgroundColor
//            )
//        } else {
//            // Fallback - preserve as much as possible
//            return ActivityItem(
//                id: self.id,
//                title: newTitle,
//                imageName: self.imageName,
//                videoAssets: nil,
//                photoAssets: nil,
//                mediaItems: self.mediaItems,
//                audioDescription: self.audioDescription,
//                backgroundColor: self.backgroundColor
//            )
//        }
//    }
//}
//
//#Preview {
//    NavigationView {
//        CollectionEditView(
//            activity: ActivityItem.sampleActivities.first(where: { $0.isVideoCollection })!,
//            onCollectionUpdated: { _ in }
//        )
//    }
//}
