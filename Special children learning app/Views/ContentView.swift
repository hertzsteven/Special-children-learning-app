//
//  ContentView.swift
//  Special children learning app
//
//  Created by Steven Hertz on 9/3/25.
//

import SwiftUI
import Photos

struct ContentView: View {
    @State private var selectedActivity: ActivityItem?
    @State private var showingVideo = false
    @State private var showingVideoSelection = false
    @State private var showingSettings = false
    @State private var activityItemCollection: [ActivityItem] = []
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showingSingleVideoNameDialog = false
    @State private var singleVideoName = ""
    @State private var pendingSingleAsset: PHAsset?
    @State private var pendingCollectionName = ""
    @State private var pendingCollectionAssets: [PHAsset] = []
    @State private var showingRenameDialog = false
    @State private var renameText = ""
    @State private var activityToRename: ActivityItem?
    @State private var showingCollectionSelection = false
    @State private var selectedActivityForSelection: ActivityItem?
    @State private var filteredActivityForViewing: ActivityItem?
    @State private var showingDeleteConfirm = false
    @State private var activityToDelete: ActivityItem?
    @State private var navPath = NavigationPath()
    
    @StateObject private var persistence = VideoCollectionPersistence.shared
    
    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    // Combine sample activities with custom videos
    var allActivities: [ActivityItem] {
        ActivityItem.sampleActivities + activityItemCollection
    }
    
    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                // Calm background color
                Color.creamBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // App Title and Settings
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
//                                Text("Learning Together")
//                                    .font(.largeTitle)
//                                    .fontWeight(.bold)
//                                    .foregroundColor(.primary)
                                
//                                Text("Tap an activity to see and learn")
//                                    .font(.title3)
//                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    showingVideoSelection = true
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.blue)
                                        .background(
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 48, height: 48)
                                        )
                                        .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 1)
                                }
                                .padding(.vertical, 32)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.top, 50)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    
                    // Activities Grid
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(allActivities) { activity in
                                activityCard(for: activity)
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
                        
                        Text("Tap an activity to see and learn")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            .navigationDestination(for: ActivityItem.self) { activity in
                let _ = print(activity.title, activity.id)
                let _ = print("-----")
                CollectionEditView(
                    activity: activity,
                    onCollectionUpdated: { updatedActivity in
                        // Update the activity in activityItemCollection array
                        if let index = activityItemCollection.firstIndex(where: { $0.id == activity.id }) {
                            activityItemCollection.remove(at: index)
                            activityItemCollection.insert(updatedActivity, at: index)
//                            activityItemCollection[index] = updatedActivity
                            print("✅ Updated ActivityItem '\(updatedActivity.title)' in ContentView")
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
        .fullScreenCover(isPresented: $showingVideoSelection) {
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
                },
                skipCollectionNaming: false 
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
                if let activity = activityToRename {
                    renameCollection(activity, newName: renameText)
                }
            }
            .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            Button("Cancel", role: .cancel) {
                activityToRename = nil
                renameText = ""
            }
        } message: {
            Text("Enter a new name for your collection")
        }
        .alert("Delete Collection?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let activity = activityToDelete {
                    deleteCustomVideo(activity)
                }
                activityToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                activityToDelete = nil
            }
        } message: {
            Text("This will remove '\(activityToDelete?.title ?? "this collection")' from your app. Your photos and videos remain in the Photos library.")
        }
        .toast(isShowing: $showToast, message: toastMessage)
        .task {
            await loadSavedCollections()
        }
    }

    @ViewBuilder
    private func activityCard(for activity: ActivityItem) -> some View {
        let editHandler: (() -> Void)? = isCustom(activity) ? { navPath.append(activity) } : nil
        
        ActivityCardView(
            activity: activity,
            onTap: {
//                if activity.isVideoCollection || activity.isPhotoCollection || activity.isMixedMediaCollection {
                    selectedActivityForSelection = activity
                    showingCollectionSelection = true
//                } else {
//                    selectedActivity = activity
//                    showingVideo = true
//                }
            },
            onEdit: editHandler
        )
        .contextMenu {
            if isCustom(activity) {
                Button("Edit Collection") {
                    navPath.append(activity)
                }
                
                Button("Delete Collection", role: .destructive) {
                    activityToDelete = activity
                    showingDeleteConfirm = true
                }
                
                Button("Rename Collection") {
                    activityToRename = activity
                    renameText = activity.title
                    showingRenameDialog = true
                }
            }
        }
    }

    @ViewBuilder
    private var videoOverlay: some View {
        if showingVideo, let activity = selectedActivity {
            if activity.isVideoCollection {
                VideoQueuePlayerView(activity: activity) {
                    showingVideo = false
                    selectedActivity = nil
                }
            } else if activity.isPhotoCollection {
                PhotoCollectionView(activity: activity) {
                    showingVideo = false
                    selectedActivity = nil
                }
            } else if activity.isMixedMediaCollection {
                VideoQueuePlayerView(activity: activity) {
                    showingVideo = false
                    selectedActivity = nil
                }
            } else if activity.isPhoto {
                PhotoViewerView(activity: activity) {
                    showingVideo = false
                    selectedActivity = nil
                }
            } else {
                VideoPlayerView(activity: activity) {
                    showingVideo = false
                    selectedActivity = nil
                }
            }
        }
    }

    @ViewBuilder
    private var collectionSelectionOverlay: some View {
        if showingCollectionSelection, let activity = selectedActivityForSelection {
            CollectionItemSelectionView(
                activity: activity,
                onDismiss: {
                    showingCollectionSelection = false
                    selectedActivityForSelection = nil
                },
                onSelectionComplete: { filteredActivity in
                    showingCollectionSelection = false
                    selectedActivityForSelection = nil
                    selectedActivity = filteredActivity
                    showingVideo = true
                }
            )
        }
    }

    private func isCustom(_ activity: ActivityItem) -> Bool {
        activityItemCollection.contains(where: { $0.id == activity.id })
    }

    private func loadSavedCollections() async {
        let savedActivityItems = await persistence.convertToActivityItems()
        activityItemCollection = savedActivityItems
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
            let newActivity = ActivityItem(
                id: newCollection.id,
                title: cleanName,
                imageName: asset.mediaType == .video ? "video.circle" : "photo.circle",
                videoAssets: asset.mediaType == .video ? [asset] : nil,
                photoAssets: asset.mediaType == .image ? [asset] : nil,
                mediaItems: [mediaItem],
                audioDescription: "A custom \(asset.mediaType == .video ? "video" : "photo") from your library",
                backgroundColor: asset.mediaType == .video ? "softBlue" : "sage"
            )
            
            activityItemCollection.append(newActivity)
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
                    // Create ActivityItem with the SAME ID as the saved collection
                    let newActivity = ActivityItem(
                        id: newCollection.id,  // ← Use saved collection's ID
                        title: finalName,
                        imageName: "rectangle.stack",
                        videoAssets: videoAssets.isEmpty ? nil : videoAssets,
                        photoAssets: photoAssets.isEmpty ? nil : photoAssets,
                        mediaItems: namedItems,
                        audioDescription: "A collection of \(allAssets.count) items: \(namedItems.map { $0.customName }.joined(separator: ", "))",
                        backgroundColor: "warmBeige"
                    )
                    
                    activityItemCollection.append(newActivity)
                }
                
                // Show confirmation
                toastMessage = "'\(finalName)' created with \(allAssets.count) items!"
                showToast = true
                
                print("Collection created successfully with \(allAssets.count) items")
            }
        }
    }

    private func deleteCustomVideo(_ activity: ActivityItem) {
        activityItemCollection.removeAll { $0.id == activity.id }
        
        if let matchingCollection = findMatchingSavedCollection(for: activity) {
            persistence.deleteCollection(matchingCollection)
        }
        
        toastMessage = "Collection deleted"
        showToast = true
    }
    
    private func renameCollection(_ activity: ActivityItem, newName: String) {
        let cleanName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let matchingCollection = findMatchingSavedCollection(for: activity) {
            // Update in persistence
            persistence.renameCollection(matchingCollection, newTitle: cleanName)
            
            // UPDATE: Preserve ID and all other properties when updating local ActivityItem
            if let index = activityItemCollection.firstIndex(where: { $0.id == activity.id }) {
                let updatedActivity: ActivityItem
                
                if let videoAssets = activity.videoAssets, let photoAssets = activity.photoAssets {
                    updatedActivity = ActivityItem(
                        id: activity.id,  // ← PRESERVE the original ID
                        title: cleanName,
                        imageName: activity.imageName,
                        videoAssets: videoAssets,
                        photoAssets: photoAssets,
                        mediaItems: activity.mediaItems,
                        audioDescription: activity.audioDescription,
                        backgroundColor: activity.backgroundColor
                    )
                } else if let videoAssets = activity.videoAssets {
                    updatedActivity = ActivityItem(
                        id: activity.id,  // ← PRESERVE the original ID  
                        title: cleanName,
                        imageName: activity.imageName,
                        videoAssets: videoAssets,
                        photoAssets: nil,
                        mediaItems: activity.mediaItems,
                        audioDescription: activity.audioDescription,
                        backgroundColor: activity.backgroundColor
                    )
                } else if let photoAssets = activity.photoAssets {
                    updatedActivity = ActivityItem(
                        id: activity.id,  // ← PRESERVE the original ID
                        title: cleanName,
                        imageName: activity.imageName,
                        videoAssets: nil,
                        photoAssets: photoAssets,
                        mediaItems: activity.mediaItems,
                        audioDescription: activity.audioDescription,
                        backgroundColor: activity.backgroundColor
                    )
                } else if let videoAsset = activity.videoAsset {
                    updatedActivity = ActivityItem(
                        id: activity.id,  // ← PRESERVE the original ID
                        title: cleanName,
                        imageName: activity.imageName,
                        videoAsset: videoAsset,
                        audioDescription: activity.audioDescription,
                        backgroundColor: activity.backgroundColor
                    )
                } else if let photoAsset = activity.photoAsset {
                    updatedActivity = ActivityItem(
                        id: activity.id,  // ← PRESERVE the original ID
                        title: cleanName,
                        imageName: activity.imageName,
                        photoAsset: photoAsset,
                        audioDescription: activity.audioDescription,
                        backgroundColor: activity.backgroundColor
                    )
                } else {
                    // For local video files, we need to add a UUID-preserving initializer for this case
                    // For now, use the general initializer with nil values
                    updatedActivity = ActivityItem(
                        id: activity.id,  // ← PRESERVE the original ID
                        title: cleanName,
                        imageName: activity.imageName,
                        videoAssets: nil,
                        photoAssets: nil,
                        mediaItems: nil,
                        audioDescription: activity.audioDescription,
                        backgroundColor: activity.backgroundColor
                    )
                }
                
                activityItemCollection[index] = updatedActivity
                print("✅ Updated ActivityItem '\(cleanName)' with preserved ID in ContentView")
            }
            
            toastMessage = "Collection renamed to '\(cleanName)'"
        } else {
            toastMessage = "Could not rename collection"
        }
        
        showToast = true
        
        // Reset state
        activityToRename = nil
        renameText = ""
    }

    private func assetIdentifiers(for activity: ActivityItem) -> [String] {
        var ids: [String] = []
        if let videoAssets = activity.videoAssets {
            ids.append(contentsOf: videoAssets.map { $0.localIdentifier })
        }
        if let photoAssets = activity.photoAssets {
            ids.append(contentsOf: photoAssets.map { $0.localIdentifier })
        }
        if let videoAsset = activity.videoAsset {
            ids.append(videoAsset.localIdentifier)
        }
        if let photoAsset = activity.photoAsset {
            ids.append(photoAsset.localIdentifier)
        }
        return ids
    }
    
    private func findMatchingSavedCollection(for activity: ActivityItem) -> SavedVideoCollection? {
        let activityIDs = Set(assetIdentifiers(for: activity))
        guard !activityIDs.isEmpty else { return nil }
        
        // Prefer exact asset set match
        if let exactMatch = persistence.savedCollections.first(where: { Set($0.allAssetIdentifiers) == activityIDs }) {
            return exactMatch
        }
        
        // Fallback: match by title and overlapping assets count
        if let fallback = persistence.savedCollections.first(where: {
            $0.title == activity.title && !$0.allAssetIdentifiers.isEmpty &&
            Set($0.allAssetIdentifiers).intersection(activityIDs).count == activityIDs.count
        }) {
            return fallback
        }
        
        return nil
    }
}

#Preview {
    ContentView()
}
