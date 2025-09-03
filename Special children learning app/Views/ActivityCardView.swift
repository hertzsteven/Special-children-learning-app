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
    
    var body: some View {
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
                
                // Activity Title
                Text(activity.title)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityLabel("\(activity.title). Tap to play video.")
        .accessibilityHint("Double tap to see a video about \(activity.title)")
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
    ActivityCardView(activity: ActivityItem.sampleActivities[0]) {
        print("Card tapped")
    }
    .padding()
}