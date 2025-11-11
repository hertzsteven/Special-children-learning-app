//
//  ContentView.swift
//  Special children learning app
//
//  Created by Steven Hertz on 9/3/25.
//

import SwiftUI
import Photos

struct ContentView: View {
    @State private var selectedMediaCollection: MediaCollection?
    @State private var showingVideo = false
    @State private var showingVideoSelection = false
    @State private var showingSettings = false
    @State private var mediaCollectionItemCollection: [MediaCollection] = []
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showingSingleVideoNameDialog = false
    @State private var singleVideoName = ""
    @State private var pendingSingleAsset: PHAsset?
    @State private var pendingCollectionName = ""
    @State private var pendingCollectionAssets: [PHAsset] = []
    @State private var showingRenameDialog = false
    @State private var renameText = ""
    @State private var mediaCollectionToRename: MediaCollection?
    @State private var showingCollectionSelection = false
    @State private var selectedMediaCollectionForSelection: MediaCollection?
    @State private var filteredMediaCollectionForViewing: MediaCollection?
    @State private var showingDeleteConfirm = false
    @State private var mediaCollectionToDelete: MediaCollection?
    @State private var navPath = NavigationPath()
    
    // NEW: Media type selection states
    @State private var showingMediaTypeChoice = false
    @State private var selectedMediaType: MediaType?
    
    @StateObject private var persistence = VideoCollectionPersistence.shared
    
    // NEW: Enum for media types
    enum MediaType: Identifiable {
        case photos, videos
        
        var id: String {
            switch self {
            case .photos: return "photos"
            case .videos: return "videos"
            }
        }
    }

    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    // Combine sample activities with custom videos
    var mediaCollections: [MediaCollection] {
        MediaCollection.sampleActivities + mediaCollectionItemCollection
    }
    
    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                // Calm background color
                Color.creamBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Button(action: {
                        showingMediaTypeChoice = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                            Text("Add an Album")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.4, green: 0.6, blue: 0.8)) // Soft blue
                        .cornerRadius(12)
                    }
                    
                    // App Title and Settings
                    VStack(spacing: 8) {

                        HStack {
//                            VStack(alignment: .leading, spacing: 8) {
//                                Text("Learning Together")
//                                    .font(.largeTitle)
//                                    .fontWeight(.bold)
//                                    .foregroundColor(.primary)
                                
//                                Text("Tap an mediaCollection to see and learn")
//                                    .font(.title3)
//                                    .foregroundColor(.secondary)
                                
//                                Button(action: {
//                                    showingVideoSelection = true
//                                }) {
//                                    Image(systemName: "plus.circle.fill")
//                                        .font(.largeTitle)
//                                        .foregroundColor(.blue)
//                                        .background(
//                                            Circle()
//                                                .fill(Color.white)
//                                                .frame(width: 48, height: 48)
//                                        )
//                                        .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 1)
//                                }
//                                .padding(.vertical, 32)
//                            }
                            
//                            Spacer()
                        }
                    }
//                    .padding(.top, 50)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    
                    HStack {
                        Text("My Media Albums")
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    // Activities Grid
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(mediaCollections) { mediaCollection in
                                mediaCollectionCard(for: mediaCollection)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                }
                
                // Video Player Overlay
                videoOverlay
                
                // NEW: Collection Selection Overlay
                collectionSelectionOverlay
            }
//            .navigationTitle("Learning Together")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 4) {
                        Text("Learning - Together")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Tap a mediaCollection to see and learn")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            .navigationDestination(for: MediaCollection.self) { mediaCollection in
                let _ = print(mediaCollection.title, mediaCollection.id)
                let _ = print("-----")
                MediaCollectionDetailEditView(
                    mediaCollection: mediaCollection,
                    onCollectionUpdated: { updatedmediaCollection in
                        // Update the mediaCollection in mediaCollectionItemCollection array
                        if let index = mediaCollectionItemCollection.firstIndex(where: { $0.id == mediaCollection.id }) {
                            mediaCollectionItemCollection.remove(at: index)
                            mediaCollectionItemCollection.insert(updatedmediaCollection, at: index)
//                            mediaCollectionItemCollection[index] = updatedActivity
                            print("✅ Updated ActivityItem '\(updatedmediaCollection.title)' in ContentView")
                        } else {
                            print("⚠️ Could not find ActivityItem to update in ContentView")
                        }
                    }
                )
            }
            .toolbar {
                ToolbarItem {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }

        .preferredColorScheme(.light) // Always use light mode for consistency
        // NEW: Media type selection sheet
        .sheet(isPresented: $showingMediaTypeChoice) {
            VStack(spacing: 30) {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Create New Album")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("What type of album would you like to create?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                VStack(spacing: 16) {
                    Button(action: {
                        selectedMediaType = .photos
                        showingMediaTypeChoice = false
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 30))
                                .foregroundColor(.green)
                                .frame(width: 50)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Photo Album")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Create a collection of photos")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        selectedMediaType = .videos
                        showingMediaTypeChoice = false
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.blue)
                                .frame(width: 50)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Video Album")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Create a collection of videos")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                Button("Cancel") {
                    showingMediaTypeChoice = false
                    selectedMediaType = nil
                }
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
        }

        .fullScreenCover(item: $selectedMediaType) { mediaType in
            PhotoLibraryPickerView(
                onVideoSelected: { selectedAsset in
                    // Handle single photos and videos
                    if selectedAsset.mediaType == .video {
                        // Show naming dialog for single video
                        pendingSingleAsset = selectedAsset
                        singleVideoName = "My Video"
                        showingSingleVideoNameDialog = true
                    } else if selectedAsset.mediaType == .image {
                        // Show naming dialog for single photo
                        pendingSingleAsset = selectedAsset
                        singleVideoName = "My Photo"
                        showingSingleVideoNameDialog = true
                    }
                },
                onIndividualMediaSelected: { namedItems, collectionName in
                    // Handle the new collection creation
                    addNamedMediaCollection(namedItems: namedItems, collectionName: collectionName)
                    // Reset selected media type
                    selectedMediaType = nil
                },
                skipCollectionNaming: false,
                initialFilter: mediaType == .photos ? .photos : .videos,
                allowedFilters: mediaType == .photos ? [.photos] : [.videos]
            )
        }

        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .alert("Name Your Video", isPresented: $showingSingleVideoNameDialog) {
            TextField("Video name", text: $singleVideoName)
                .textInputAutocapitalization(.words)
            
            Button("Save") {
                if let asset = pendingSingleAsset {
                    addSingleVideo(from: asset, name: singleVideoName)
                }
            }
            .disabled(singleVideoName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            Button("Cancel", role: .cancel) {
                pendingSingleAsset = nil
                singleVideoName = ""
            }
        } message: {
            Text("Give your video a memorable name")
        }
        .alert("Rename Collection", isPresented: $showingRenameDialog) {
            TextField("Collection name", text: $renameText)
                .textInputAutocapitalization(.words)
            
            Button("Save") {
                if let mediaCollection = mediaCollectionToRename {
                    renameCollection(mediaCollection, newName: renameText)
                }
            }
            .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            Button("Cancel", role: .cancel) {
                mediaCollectionToRename = nil
                renameText = ""
            }
        } message: {
            Text("Enter a new name for your collection")
        }
        .alert("Delete Collection?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let mediaCollection = mediaCollectionToDelete {
                    deleteCustomVideo(mediaCollection)
                }
                mediaCollectionToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                mediaCollectionToDelete = nil
            }
        } message: {
            Text("This will remove '\(mediaCollectionToDelete?.title ?? "this collection")' from your app. Your photos and videos remain in the Photos library.")
        }
        .toast(isShowing: $showToast, message: toastMessage)
        .task {
            await loadSavedCollections()
        }
    }

    @ViewBuilder
    private func mediaCollectionCard(for mediaCollection: MediaCollection) -> some View {
        let editHandler: (() -> Void)? = isCustom(mediaCollection) ? { navPath.append(mediaCollection) } : nil
        
        mediaCollectionCardView(
            mediaCollection: mediaCollection,
            onTap: {
//                if mediaCollection.isVideoCollection || mediaCollection.isPhotoCollection || mediaCollection.isMixedMediaCollection {
                    selectedMediaCollectionForSelection = mediaCollection
                    showingCollectionSelection = true
//                } else {
//                    selectedActivity = mediaCollection
//                    showingVideo = true
//                }
            },
            onEdit: editHandler
        )
        .contextMenu {
            if isCustom(mediaCollection) {
                Button("Edit Collection") {
                    navPath.append(mediaCollection)
                }
                
                Button("Delete Collection", role: .destructive) {
                    mediaCollectionToDelete = mediaCollection
                    showingDeleteConfirm = true
                }
                
                Button("Rename Collection") {
                    mediaCollectionToRename = mediaCollection
                    renameText = mediaCollection.title
                    showingRenameDialog = true
                }
            }
        }
    }

    @ViewBuilder
    private var videoOverlay: some View {
        if showingVideo, let mediaCollection = selectedMediaCollection {
            if mediaCollection.isVideoCollection {
                MediaCollectionPlayerView(mediaCollection: mediaCollection) {
                    showingVideo = false
                    selectedMediaCollection = nil
                }
            } else if mediaCollection.isPhotoCollection {
                PhotoCollectionView(mediaCollection: mediaCollection) {
                    showingVideo = false
                    selectedMediaCollection = nil
                }
            } else if mediaCollection.isMixedMediaCollection {
                MediaCollectionPlayerView(mediaCollection: mediaCollection) {
                    showingVideo = false
                    selectedMediaCollection = nil
                }
            } else if mediaCollection.isPhoto {
                PhotoViewerView(mediaCollection: mediaCollection) {
                    showingVideo = false
                    selectedMediaCollection = nil
                }
            } else {
                VideoPlayerView(mediaCollection: mediaCollection) {
                    showingVideo = false
                    selectedMediaCollection = nil
                }
            }
        }
    }

    @ViewBuilder
    private var collectionSelectionOverlay: some View {
        if showingCollectionSelection, let mediaCollection = selectedMediaCollectionForSelection {
            MediaCollectionItemsSelectionView(
                activity: mediaCollection,
                onDismiss: {
                    showingCollectionSelection = false
                    selectedMediaCollectionForSelection = nil
                },
                onSelectionComplete: { filteredMediaCollection in
                    showingCollectionSelection = false
                    selectedMediaCollectionForSelection = nil
                    selectedMediaCollection = filteredMediaCollection
                    showingVideo = true
                }
            )
        }
    }

    private func isCustom(_ mediaCollection: MediaCollection) -> Bool {
        mediaCollectionItemCollection.contains(where: { $0.id == mediaCollection.id })
    }

    private func loadSavedCollections() async {
        let savedMediaCollectionItems = await persistence.convertToMediaCollectionItems()
        mediaCollectionItemCollection = savedMediaCollectionItems
    }
    
    private func addSingleVideo(from asset: PHAsset, name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let mediaItem = SavedMediaItem(
            assetIdentifier: asset.localIdentifier,
            customName: cleanName,
            audioRecordingFileName: nil
        )
        
        persistence.saveCollectionWithMediaItems(
            title: cleanName,
            mediaItems: [mediaItem],
            imageName: asset.mediaType == .video ? "video.circle" : "photo.circle",
            backgroundColor: asset.mediaType == .video ? "softBlue" : "sage"
        )
        
        // Find the newly created collection to get its ID
        if let newCollection = persistence.savedCollections.last {
            let newMediaCollection = MediaCollection(
                id: newCollection.id,
                title: cleanName,
                imageName: asset.mediaType == .video ? "video.circle" : "photo.circle",
                videoAssets: asset.mediaType == .video ? [asset] : nil,
                photoAssets: asset.mediaType == .image ? [asset] : nil,
                mediaItems: [mediaItem],
                audioDescription: "A custom \(asset.mediaType == .video ? "video" : "photo") from your library",
                backgroundColor: asset.mediaType == .video ? "softBlue" : "sage"
            )
            
            mediaCollectionItemCollection.append(newMediaCollection)
        }
        
        // Show confirmation
        let mediaType = asset.mediaType == .video ? "video" : "photo"
        toastMessage = "'\(cleanName)' \(mediaType) saved!"
        showToast = true
        
        // Reset
        pendingSingleAsset = nil
        singleVideoName = ""
    }
    
    private func addNamedMediaCollection(namedItems: [SavedMediaItem], collectionName: String) {
        print("Creating collection '\(collectionName)' with \(namedItems.count) named items")
        
        let cleanName = collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = cleanName.isEmpty ? "My Media Collection" : cleanName
        
        // Get all assets by fetching them from the namedItems
        Task {
            var allAssets: [PHAsset] = []
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: namedItems.map { $0.assetIdentifier }, options: nil)
            fetchResult.enumerateObjects { asset, _, _ in
                allAssets.append(asset)
            }
            
            let videoAssets = allAssets.filter { $0.mediaType == .video }
            let photoAssets = allAssets.filter { $0.mediaType == .image }
            
            // Save to persistence with individual names and audio recordings FIRST
            persistence.saveCollectionWithMediaItems(
                title: finalName,
                mediaItems: namedItems,
                imageName: "rectangle.stack",
                backgroundColor: "warmBeige"
            )
            
            await MainActor.run {
                // Find the newly created collection to get its ID
                if let newCollection = persistence.savedCollections.last {
                    // Create MediaCollectionItem with the SAME ID as the saved collection
                    let newMediaCollection = MediaCollection(
                        id: newCollection.id,  // ← Use saved collection's ID
                        title: finalName,
                        imageName: "rectangle.stack",
                        videoAssets: videoAssets.isEmpty ? nil : videoAssets,
                        photoAssets: photoAssets.isEmpty ? nil : photoAssets,
                        mediaItems: namedItems,
                        audioDescription: "A collection of \(allAssets.count) items: \(namedItems.map { $0.customName }.joined(separator: ", "))",
                        backgroundColor: "warmBeige"
                    )
                    
                    mediaCollectionItemCollection.append(newMediaCollection)
                }
                
                // Show confirmation
                toastMessage = "'\(finalName)' created with \(allAssets.count) items!"
                showToast = true
                
                // NEW: Reset selected media type
                selectedMediaType = nil
                
                print("Collection created successfully with \(allAssets.count) items")
            }
        }
    }

    private func deleteCustomVideo(_ mediaCollection: MediaCollection) {
        mediaCollectionItemCollection.removeAll { $0.id == mediaCollection.id }
        
        if let matchingCollection = findMatchingSavedCollection(for: mediaCollection) {
            persistence.deleteCollection(matchingCollection)
        }
        
        toastMessage = "Collection deleted"
        showToast = true
    }
    
    private func renameCollection(_ mediaCollection: MediaCollection, newName: String) {
        let cleanName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let matchingCollection = findMatchingSavedCollection(for: mediaCollection) {
            // Update in persistence
            persistence.renameCollection(matchingCollection, newTitle: cleanName)
            
            // UPDATE: Preserve ID and all other properties when updating local MediaCollectionItem
            if let index = mediaCollectionItemCollection.firstIndex(where: { $0.id == mediaCollection.id }) {
                let updatedMediaCollection: MediaCollection
                
                if let videoAssets = mediaCollection.videoAssets, let photoAssets = mediaCollection.photoAssets {
                    updatedMediaCollection = MediaCollection(
                        id: mediaCollection.id,  // ← PRESERVE the original ID
                        title: cleanName,
                        imageName: mediaCollection.imageName,
                        videoAssets: videoAssets,
                        photoAssets: photoAssets,
                        mediaItems: mediaCollection.mediaItems,
                        audioDescription: mediaCollection.audioDescription,
                        backgroundColor: mediaCollection.backgroundColor
                    )
                } else if let videoAssets = mediaCollection.videoAssets {
                    updatedMediaCollection = MediaCollection(
                        id: mediaCollection.id,  // ← PRESERVE the original ID  
                        title: cleanName,
                        imageName: mediaCollection.imageName,
                        videoAssets: videoAssets,
                        photoAssets: nil,
                        mediaItems: mediaCollection.mediaItems,
                        audioDescription: mediaCollection.audioDescription,
                        backgroundColor: mediaCollection.backgroundColor
                    )
                } else if let photoAssets = mediaCollection.photoAssets {
                    updatedMediaCollection = MediaCollection(
                        id: mediaCollection.id,  // ← PRESERVE the original ID
                        title: cleanName,
                        imageName: mediaCollection.imageName,
                        videoAssets: nil,
                        photoAssets: photoAssets,
                        mediaItems: mediaCollection.mediaItems,
                        audioDescription: mediaCollection.audioDescription,
                        backgroundColor: mediaCollection.backgroundColor
                    )
                } else if let videoAsset = mediaCollection.videoAsset {
                    updatedMediaCollection = MediaCollection(
                        id: mediaCollection.id,  // ← PRESERVE the original ID
                        title: cleanName,
                        imageName: mediaCollection.imageName,
                        videoAsset: videoAsset,
                        audioDescription: mediaCollection.audioDescription,
                        backgroundColor: mediaCollection.backgroundColor
                    )
                } else if let photoAsset = mediaCollection.photoAsset {
                    updatedMediaCollection = MediaCollection(
                        id: mediaCollection.id,  // ← PRESERVE the original ID
                        title: cleanName,
                        imageName: mediaCollection.imageName,
                        photoAsset: photoAsset,
                        audioDescription: mediaCollection.audioDescription,
                        backgroundColor: mediaCollection.backgroundColor
                    )
                } else {
                    // For local video files, we need to add a UUID-preserving initializer for this case
                    // For now, use the general initializer with nil values
                    updatedMediaCollection = MediaCollection(
                        id: mediaCollection.id,  // ← PRESERVE the original ID
                        title: cleanName,
                        imageName: mediaCollection.imageName,
                        videoAssets: nil,
                        photoAssets: nil,
                        mediaItems: nil,
                        audioDescription: mediaCollection.audioDescription,
                        backgroundColor: mediaCollection.backgroundColor
                    )
                }
                
                mediaCollectionItemCollection[index] = updatedMediaCollection
                print("✅ Updated MediaCollectionItem '\(cleanName)' with preserved ID in ContentView")
            }
            
            toastMessage = "Collection renamed to '\(cleanName)'"
        } else {
            toastMessage = "Could not rename collection"
        }
        
        showToast = true
        
        // Reset state
        mediaCollectionToRename = nil
        renameText = ""
    }

    private func assetIdentifiers(for mediaCollection: MediaCollection) -> [String] {
        var ids: [String] = []
        if let videoAssets = mediaCollection.videoAssets {
            ids.append(contentsOf: videoAssets.map { $0.localIdentifier })
        }
        if let photoAssets = mediaCollection.photoAssets {
            ids.append(contentsOf: photoAssets.map { $0.localIdentifier })
        }
        if let videoAsset = mediaCollection.videoAsset {
            ids.append(videoAsset.localIdentifier)
        }
        if let photoAsset = mediaCollection.photoAsset {
            ids.append(photoAsset.localIdentifier)
        }
        return ids
    }
    
    private func findMatchingSavedCollection(for mediaCollection: MediaCollection) -> SavedVideoCollection? {
        let mediaCollectionIDs = Set(assetIdentifiers(for: mediaCollection))
        guard !mediaCollectionIDs.isEmpty else { return nil }
        
        // Prefer exact asset set match
        if let exactMatch = persistence.savedCollections.first(where: { Set($0.allAssetIdentifiers) == mediaCollectionIDs }) {
            return exactMatch
        }
        
        // Fallback: match by title and overlapping assets count
        if let fallback = persistence.savedCollections.first(where: {
            $0.title == mediaCollection.title && !$0.allAssetIdentifiers.isEmpty &&
            Set($0.allAssetIdentifiers).intersection(mediaCollectionIDs).count == mediaCollectionIDs.count
        }) {
            return fallback
        }
        
        return nil
    }
}

#Preview("ContentView", traits: .landscapeLeft) {
    ContentView()
}
