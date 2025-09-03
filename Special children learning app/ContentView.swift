//
//  ContentView.swift
//  Special children learning app
//
//  Created by Steven Hertz on 9/3/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedActivity: ActivityItem?
    @State private var showingVideo = false
    
    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
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
                
                // Activities Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(ActivityItem.sampleActivities) { activity in
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
    }
}

#Preview {
    ContentView()
}