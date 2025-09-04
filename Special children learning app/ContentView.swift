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
    @State private var customVideos: [ActivityItem] = []
    
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
                // App Title
                VStack(spacing: 8) {
                    Text("Learning Together")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Tap an activity to see and learn")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 50)
                
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
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            
            // Video Player Overlay
            if showingVideo, let activity = selectedActivity {
                VideoPlayerView(activity: activity) {
                    showingVideo = false
                    selectedActivity = nil
                }
            }
        }
        .preferredColorScheme(.light) // Always use light mode for consistency
        .sheet(isPresented: $showingVideoSelection) {
            VideoSelectionView { selectedAsset in
                addCustomVideo(from: selectedAsset)
            }
        }
    }
    
    private func addCustomVideo(from asset: PHAsset) {
        let newActivity = ActivityItem(
            title: "Custom Video \(customVideos.count + 1)",
            imageName: "video.circle",
            videoAsset: asset,
            audioDescription: "A custom video from your library",
            backgroundColor: "softBlue"
        )
        customVideos.append(newActivity)
    }
}

#Preview {
    ContentView()
}