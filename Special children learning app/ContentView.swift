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
                                        // Could implement rename functionality
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
                } else {
                    VideoPlayerView(activity: activity) {
                        showingVideo = false
                        selectedActivity = nil
                    }
                }
            }
        }
        .preferredColorScheme(.light) // Always use light mode for consistency
        .sheet(isPresented: $showingVideoSelection) {
            VideoSelectionView(
                onVideoSelected: { selectedAsset in
                    // Show naming dialog for single video
                    pendingSingleAsset = selectedAsset
                    singleVideoName = "My Video"
                    showingSingleVideoNameDialog = true
                },
                onMultipleVideosSelected: { selectedAssets, collectionName in
                    // Use the collection name from the naming dialog
                    addVideoCollection(from: selectedAssets, name: collectionName)
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
            imageName: "video.circle",
            backgroundColor: "softBlue"
        )
        
        // Add to current session
        let newActivity = ActivityItem(
            title: cleanName,
            imageName: "video.circle",
            videoAsset: asset,
            audioDescription: "A custom video from your library",
            backgroundColor: "softBlue"
        )
        customVideos.append(newActivity)
        
        // Show confirmation
        toastMessage = "'\(cleanName)' saved!"
        showToast = true
        
        // Reset
        pendingSingleAsset = nil
        singleVideoName = ""
    }
    
    private func addVideoCollection(from assets: [PHAsset], name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = cleanName.isEmpty ? "My Video Collection" : cleanName
        let identifiers = assets.map { $0.localIdentifier }
        
        // Save to persistence
        persistence.saveCollection(
            title: finalName,
            assetIdentifiers: identifiers,
            imageName: "play.rectangle.on.rectangle",
            backgroundColor: "warmBeige"
        )
        
        // Add to current session
        let newActivity = ActivityItem(
            title: finalName,
            imageName: "play.rectangle.on.rectangle",
            videoAssets: assets,
            audioDescription: "A collection of \(assets.count) videos from your library",
            backgroundColor: "warmBeige"
        )
        customVideos.append(newActivity)
        
        // Show confirmation
        toastMessage = "'\(finalName)' created with \(assets.count) videos!"
        showToast = true
    }
    
    private func deleteCustomVideo(_ activity: ActivityItem) {
        // Remove from current session
        customVideos.removeAll { $0.id == activity.id }
        
        // Note: For proper deletion from persistence, we'd need to map 
        // ActivityItem back to SavedVideoCollection ID
        
        toastMessage = "Collection deleted"
        showToast = true
    }
}

#Preview {
    ContentView()
}