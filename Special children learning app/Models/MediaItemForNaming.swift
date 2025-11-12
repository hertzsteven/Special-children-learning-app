//
//  MediaItemForNaming.swift
//  Special children learning app
//
//  Created by Steven Hertz on 11/12/25.
//


import SwiftUI
import Photos
import Foundation

struct MediaItemForNaming: Identifiable {
    let id = UUID()
    let asset: PHAsset
    var customName: String
    var isSkipped: Bool = false
    var audioURL: URL? = nil // NEW: Audio recording URL
    
    var isVideo: Bool {
        asset.mediaType == .video
    }
    
    var mediaTypeIcon: String {
        isVideo ? "video.circle.fill" : "photo.circle.fill"
    }
    
    var defaultName: String {
        // Generate a better default name based on creation date and type
        let formatter = DateFormatter()
        let creationDate = asset.creationDate ?? Date()
        
        if isVideo {
            formatter.dateFormat = "EEEE" // Day of week
            let dayOfWeek = formatter.string(from: creationDate)
            
            formatter.dateFormat = "h:mm a" // Time
            let time = formatter.string(from: creationDate)
            
            return "\(dayOfWeek) Video"
        } else {
            formatter.dateFormat = "MMMM d" // Month and day
            let monthDay = formatter.string(from: creationDate)
            
            return "\(monthDay) Photo"
        }
    }
}
