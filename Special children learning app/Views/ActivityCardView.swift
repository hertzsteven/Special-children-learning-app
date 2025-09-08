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
                        
                        // Show a single line of info: prefer mixed → video → photo
                        if activity.isMixedMediaCollection {
                            let videoCount = activity.videoAssets?.count ?? 0
                            let photoCount = activity.photoAssets?.count ?? 0
                            let total = videoCount + photoCount
                            Text("\(total) \(total == 1 ? "item" : "items")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if let count = activity.videoAssets?.count, count > 0 {
                            Text("\(count) \(count == 1 ? "video" : "videos")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if let count = activity.photoAssets?.count, count > 0 {
                            Text("\(count) \(count == 1 ? "photo" : "photos")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(CardButtonStyle())
            
            // NEW: Edit button for collections
            if let onEdit = onEdit {
//               (activity.isVideoCollection || activity.isPhotoCollection || activity.isMixedMediaCollection) {
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    onEdit()
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 44))
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
        if activity.isMixedMediaCollection {
            let total = (activity.videoAssets?.count ?? 0) + (activity.photoAssets?.count ?? 0)
            return "\(activity.title). Collection with \(total) \(total == 1 ? "item" : "items")."
        } else if let count = activity.videoAssets?.count, count > 0 {
            return "\(activity.title). Collection with \(count) \(count == 1 ? "video" : "videos")."
        } else if let count = activity.photoAssets?.count, count > 0 {
            return "\(activity.title). Collection with \(count) \(count == 1 ? "photo" : "photos")."
        } else if activity.isPhoto {
            return "\(activity.title). Photo."
        } else if activity.isVideo {
            return "\(activity.title). Video."
        } else {
            return activity.title
        }
    }
    
    private var accessibilityHint: String {
        if activity.isMixedMediaCollection {
            return "Double tap to view collection"
        } else if let count = activity.videoAssets?.count, count > 0 {
            return "Double tap to play video collection"
        } else if let count = activity.photoAssets?.count, count > 0 {
            return "Double tap to view photo collection"
        } else if activity.isPhoto {
            return "Double tap to view photo"
        } else if activity.isVideo {
            return "Double tap to play video"
        } else {
            return "Double tap to open"
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
