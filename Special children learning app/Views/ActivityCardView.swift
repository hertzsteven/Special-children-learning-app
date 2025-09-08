//
//  ActivityCardView.swift
//  Special children learning app
//
//  Created by Steven Hertz on 9/3/25.
//

import SwiftUI

struct ActivityCardView: View {
    let activity: ActivityItem
    let onTap: () -> Void
    let onEdit: (() -> Void)? // NEW: Optional edit callback
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: {
                // Haptic feedback for accessibility
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                onTap()
            }) {
                VStack(spacing: 12) {
                    // Activity Illustration
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(activity.backgroundColor))
                        .frame(height: 120)
                        .overlay {
                            Image(systemName: activity.imageName)
                                .font(.system(size: 48))
                                .foregroundColor(.primary.opacity(0.8))
                        }
                    
                    // Activity Title and Info
                    VStack(spacing: 4) {
                        Text(activity.title)
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        // Show video count for collections
                        if activity.isVideoCollection, let count = activity.videoAssets?.count {
                            Text("\(count) videos")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Show photo count for photo collections  
                        if activity.isPhotoCollection, let count = activity.photoAssets?.count {
                            Text("\(count) photos")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Show mixed media count
                        if activity.isMixedMediaCollection {
                            let videoCount = activity.videoAssets?.count ?? 0
                            let photoCount = activity.photoAssets?.count ?? 0
                            Text("\(videoCount + photoCount) items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(CardButtonStyle())
            
            // NEW: Edit button for collections
            if let onEdit = onEdit, 
               (activity.isVideoCollection || activity.isPhotoCollection || activity.isMixedMediaCollection) {
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    onEdit()
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                }
                .offset(x: -8, y: 8)
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
    
    private var accessibilityLabel: String {
        if activity.isVideoCollection {
            return "\(activity.title). Collection with \(activity.videoAssets?.count ?? 0) videos."
        } else {
            return "\(activity.title). Tap to play video."
        }
    }
    
    private var accessibilityHint: String {
        if activity.isVideoCollection {
            return "Double tap to play video collection"
        } else {
            return "Double tap to see a video about \(activity.title)"
        }
    }
}

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    ActivityCardView(
        activity: ActivityItem.sampleActivities[0],
        onTap: {
            print("Card tapped")
        },
        onEdit: nil
    )
    .padding()
}