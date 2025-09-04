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
    @State private var customVideos: [ActivityItem] = []
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
    
    @StateObject private var persistence = VideoCollectionPersistence.shared
    
    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    // Combine sample activities with custom videos
    var allActivities: [ActivityItem] {
        ActivityItem.sampleActivities + customVideos
    }
    
    var body: some View {
        ZStack {
            // Calm background color
            Color.creamBackground
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // App Title and Settings
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Learning Together")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Tap an activity to see and learn")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 50)
                .padding(.horizontal, 20)
                
                // Add Video Button
                Button(action: {
                    showingVideoSelection = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        Text("Add Video from Library")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                // Activities Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(allActivities) { activity in
                            ActivityCardView(activity: activity) {
                                selectedActivity = activity
                                showingVideo = true
                            }
                            .contextMenu {
                                // Add context menu for custom videos
                                if customVideos.contains(where: { $0.id == activity.id }) {
                                    Button("Delete Collection", role: .destructive) {
                                        deleteCustomVideo(activity)
                                    }
                                    
                                    Button("Rename Collection") {
                                        activityToRename = activity
                                        renameText = activity.title
                                        showingRenameDialog = true
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            
            // Video Player Overlay
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
                    // We'll need to create a mixed media viewer later
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
        .preferredColorScheme(.light) // Always use light mode for consistency
        .fullScreenCover(isPresented: $showingVideoSelection) {
            FullScreenMediaSelectionView(
                onVideoSelected: { selectedAsset in
                    // Handle both photos and videos
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
                onMultipleVideosSelected: { selectedAssets, collectionName in
                    // Handle mixed media collections
                    addMixedMediaCollection(from: selectedAssets, name: collectionName)
                }
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
        .toast(isShowing: $showToast, message: toastMessage)
        .task {
            await loadSavedCollections()
        }
    }
    
    private func loadSavedCollections() async {
        let savedActivityItems = await persistence.convertToActivityItems()
        customVideos = savedActivityItems
    }
    
    private func addSingleVideo(from asset: PHAsset, name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Save to persistence
        persistence.saveCollection(
            title: cleanName,
            assetIdentifiers: [asset.localIdentifier],
            imageName: asset.mediaType == .video ? "video.circle" : "photo.circle",
            backgroundColor: asset.mediaType == .video ? "softBlue" : "sage"
        )
        
        // Add to current session
        let newActivity: ActivityItem
        if asset.mediaType == .video {
            newActivity = ActivityItem(
                title: cleanName,
                imageName: "video.circle",
                videoAsset: asset,
                audioDescription: "A custom video from your library",
                backgroundColor: "softBlue"
            )
        } else {
            newActivity = ActivityItem(
                title: cleanName,
                imageName: "photo.circle",
                photoAsset: asset,
                audioDescription: "A custom photo from your library",
                backgroundColor: "sage"
            )
        }
        
        customVideos.append(newActivity)
        
        // Show confirmation
        let mediaType = asset.mediaType == .video ? "video" : "photo"
        toastMessage = "'\(cleanName)' \(mediaType) saved!"
        showToast = true
        
        // Reset
        pendingSingleAsset = nil
        singleVideoName = ""
    }
    
    private func addMixedMediaCollection(from assets: [PHAsset], name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = cleanName.isEmpty ? "My Media Collection" : cleanName
        let identifiers = assets.map { $0.localIdentifier }
        
        let videoAssets = assets.filter { $0.mediaType == .video }
        let photoAssets = assets.filter { $0.mediaType == .image }
        
        // Save to persistence
        persistence.saveCollection(
            title: finalName,
            assetIdentifiers: identifiers,
            imageName: "rectangle.stack",
            backgroundColor: "warmBeige"
        )
        
        // Add to current session
        let newActivity = ActivityItem(
            title: finalName,
            imageName: "rectangle.stack",
            videoAssets: videoAssets.isEmpty ? nil : videoAssets,
            photoAssets: photoAssets.isEmpty ? nil : photoAssets,
            audioDescription: "A collection of \(assets.count) items from your library",
            backgroundColor: "warmBeige"
        )
        customVideos.append(newActivity)
        
        // Show confirmation
        toastMessage = "'\(finalName)' created with \(assets.count) items!"
        showToast = true
    }
    
    private func deleteCustomVideo(_ activity: ActivityItem) {
        // Remove from current session
        customVideos.removeAll { $0.id == activity.id }
        
        // Find and delete from persistence by matching title and asset count
        if let matchingCollection = persistence.savedCollections.first(where: { 
            $0.title == activity.title && 
            $0.assetIdentifiers.count == (activity.videoAssets?.count ?? (activity.videoAsset != nil ? 1 : 0))
        }) {
            persistence.deleteCollection(matchingCollection)
        }
        
        toastMessage = "Collection deleted"
        showToast = true
    }
    
    private func renameCollection(_ activity: ActivityItem, newName: String) {
        let cleanName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find matching collection in persistence
        if let matchingCollection = persistence.savedCollections.first(where: { 
            $0.title == activity.title && 
            $0.assetIdentifiers.count == (activity.videoAssets?.count ?? (activity.videoAsset != nil ? 1 : 0))
        }) {
            // Update in persistence
            persistence.renameCollection(matchingCollection, newTitle: cleanName)
            
            // Update in local customVideos array
            if let index = customVideos.firstIndex(where: { $0.id == activity.id }) {
                let updatedActivity: ActivityItem
                
                if let videoAssets = activity.videoAssets {
                    // Collection of videos
                    updatedActivity = ActivityItem(
                        title: cleanName,
                        imageName: activity.imageName,
                        videoAssets: videoAssets,
                        audioDescription: activity.audioDescription,
                        backgroundColor: activity.backgroundColor
                    )
                } else if let videoAsset = activity.videoAsset {
                    // Single video
                    updatedActivity = ActivityItem(
                        title: cleanName,
                        imageName: activity.imageName,
                        videoAsset: videoAsset,
                        audioDescription: activity.audioDescription,
                        backgroundColor: activity.backgroundColor
                    )
                } else {
                    // Fallback for sample activities with videoFileName
                    updatedActivity = ActivityItem(
                        title: cleanName,
                        imageName: activity.imageName,
                        videoFileName: activity.videoFileName ?? "",
                        audioDescription: activity.audioDescription,
                        backgroundColor: activity.backgroundColor
                    )
                }
                
                customVideos[index] = updatedActivity
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
}

#Preview {
    ContentView()
}