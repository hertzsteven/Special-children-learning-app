//
//  ActivityItem.swift
//  Special children learning app
//
//  Created by Steven Hertz on 9/3/25.
//

import Foundation
import SwiftUI
import Photos

struct ActivityItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let imageName: String
    let videoFileName: String?
    let videoAsset: PHAsset?
    let videoAssets: [PHAsset]?
    let photoAsset: PHAsset?
    let photoAssets: [PHAsset]?
    let mediaItems: [SavedMediaItem]? // NEW: Individual media items with names
    let audioDescription: String
    let backgroundColor: String
    
    var isVideoCollection: Bool {
        return videoAssets != nil && (videoAssets?.count ?? 0) >= 1  // Changed from > 1 to >= 1
    }
    
    var isPhotoCollection: Bool {
        return photoAssets != nil && (photoAssets?.count ?? 0) >= 1  // Changed from > 1 to >= 1
    }
    
    var isMixedMediaCollection: Bool {
        let totalAssets = (videoAssets?.count ?? 0) + (photoAssets?.count ?? 0)
        return totalAssets > 1 && (videoAssets?.count ?? 0) > 0 && (photoAssets?.count ?? 0) > 0
    }
    
    var isPhoto: Bool {
        return photoAsset != nil
    }
    
    var isVideo: Bool {
        return videoAsset != nil
    }
    
    // NEW: Get individual names for media items
    func getMediaItemName(for asset: PHAsset) -> String? {
        return mediaItems?.first { $0.assetIdentifier == asset.localIdentifier }?.customName
    }
    
    init(title: String, imageName: String, videoFileName: String, audioDescription: String, backgroundColor: String) {
        self.title = title
        self.imageName = imageName
        self.videoFileName = videoFileName
        self.videoAsset = nil
        self.videoAssets = nil
        self.photoAsset = nil
        self.photoAssets = nil
        self.mediaItems = nil // Add this line
        self.audioDescription = audioDescription
        self.backgroundColor = backgroundColor
    }
    
    init(title: String, imageName: String, videoAsset: PHAsset, audioDescription: String, backgroundColor: String) {
        self.title = title
        self.imageName = imageName
        self.videoFileName = nil
        self.videoAsset = videoAsset
        self.videoAssets = nil
        self.photoAsset = nil
        self.photoAssets = nil
        self.mediaItems = nil // Add this line
        self.audioDescription = audioDescription
        self.backgroundColor = backgroundColor
    }
    
    init(title: String, imageName: String, photoAsset: PHAsset, audioDescription: String, backgroundColor: String) {
        self.title = title
        self.imageName = imageName
        self.videoFileName = nil
        self.videoAsset = nil
        self.videoAssets = nil
        self.photoAsset = photoAsset
        self.photoAssets = nil
        self.mediaItems = nil // Add this line
        self.audioDescription = audioDescription
        self.backgroundColor = backgroundColor
    }
    
    init(title: String, imageName: String, videoAssets: [PHAsset], audioDescription: String, backgroundColor: String) {
        self.title = title
        self.imageName = imageName
        self.videoFileName = nil
        self.videoAsset = nil
        self.videoAssets = videoAssets
        self.photoAsset = nil
        self.photoAssets = nil
        self.mediaItems = nil // Add this line
        self.audioDescription = audioDescription
        self.backgroundColor = backgroundColor
    }
    
    init(title: String, imageName: String, photoAssets: [PHAsset], audioDescription: String, backgroundColor: String) {
        self.title = title
        self.imageName = imageName
        self.videoFileName = nil
        self.videoAsset = nil
        self.videoAssets = nil
        self.photoAsset = nil
        self.photoAssets = photoAssets
        self.mediaItems = nil // Add this line
        self.audioDescription = audioDescription
        self.backgroundColor = backgroundColor
    }
    
    init(title: String, imageName: String, videoAssets: [PHAsset]?, photoAssets: [PHAsset]?, audioDescription: String, backgroundColor: String) {
        self.title = title
        self.imageName = imageName
        self.videoFileName = nil
        self.videoAsset = nil
        self.videoAssets = videoAssets
        self.photoAsset = nil
        self.photoAssets = photoAssets
        self.mediaItems = nil // Add this line
        self.audioDescription = audioDescription
        self.backgroundColor = backgroundColor
    }
    
    // NEW: Initializer with media items
    init(title: String, imageName: String, videoAssets: [PHAsset]?, photoAssets: [PHAsset]?, mediaItems: [SavedMediaItem]?, audioDescription: String, backgroundColor: String) {
        self.title = title
        self.imageName = imageName
        self.videoFileName = nil
        self.videoAsset = nil
        self.videoAssets = videoAssets
        self.photoAsset = nil
        self.photoAssets = photoAssets
        self.mediaItems = mediaItems
        self.audioDescription = audioDescription
        self.backgroundColor = backgroundColor
    }
    
    static let sampleActivities: [ActivityItem] = [
        ActivityItem(
            title: "Eat Breakfast",
            imageName: "fork.knife",
            videoFileName: "breakfast_video",
            audioDescription: "A child is eating a healthy breakfast with cereal, toast, and juice",
            backgroundColor: "sage"
        ),
        ActivityItem(
            title: "Brush Teeth",
            imageName: "mouth",
            videoFileName: "brushteeth_video", 
            audioDescription: "A child is brushing their teeth to keep them clean and healthy",
            backgroundColor: "softBlue"
        ),
        ActivityItem(
            title: "Play with Blocks",
            imageName: "cube.box",
            videoFileName: "blocks_video",
            audioDescription: "A child is playing and building with colorful blocks",
            backgroundColor: "warmBeige"
        ),
        ActivityItem(
            title: "Read a Book",
            imageName: "book",
            videoFileName: "reading_video",
            audioDescription: "A child is reading a book and learning new words",
            backgroundColor: "softBlue"
        ),
        ActivityItem(
            title: "Say Hello",
            imageName: "hand.wave",
            videoFileName: "hello_video",
            audioDescription: "A child is waving hello to say hi to friends",
            backgroundColor: "sage"
        ),
        ActivityItem(
            title: "Get Dressed",
            imageName: "tshirt",
            videoFileName: "dressed_video",
            audioDescription: "A child is getting dressed and putting on clothes",
            backgroundColor: "softBlue"
        )
    ]
    
    // Add Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ActivityItem, rhs: ActivityItem) -> Bool {
        return lhs.id == rhs.id
    }
}