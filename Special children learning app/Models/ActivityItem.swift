//
//  ActivityItem.swift
//  Special children learning app
//
//  Created by Steven Hertz on 9/3/25.
//

import Foundation
import SwiftUI
import Photos

struct ActivityItem: Identifiable, Hashable, Equatable, Codable {
    let id: UUID
    let title: String
    let imageName: String
    var videoFileName: String?
    var videoAsset: PHAsset?
    var photoAsset: PHAsset?
    var videoAssets: [PHAsset]?
    var photoAssets: [PHAsset]?
    var mediaItems: [SavedMediaItem]? // All media items with names and audio

    let audioDescription: String
    let backgroundColor: String
    
    // Custom CodingKeys to handle non-Codable PHAsset properties
    enum CodingKeys: String, CodingKey {
        case id, title, imageName, videoFileName, audioDescription, backgroundColor, mediaItems
        case videoAssetIdentifier
        case photoAssetIdentifier
        case videoAssetIdentifiers
        case photoAssetIdentifiers
    }

    // Initializer for local video files
    init(title: String, imageName: String, videoFileName: String, audioDescription: String, backgroundColor: String) {
        self.id = UUID()
        self.title = title
        self.imageName = imageName
        self.videoFileName = videoFileName
        self.videoAsset = nil
        self.videoAssets = nil
        self.photoAsset = nil
        self.photoAssets = nil
        self.mediaItems = nil
        self.audioDescription = audioDescription
        self.backgroundColor = backgroundColor
    }
    
    init(title: String, imageName: String, videoAsset: PHAsset, audioDescription: String, backgroundColor: String) {
        self.id = UUID()
        self.title = title
        self.imageName = imageName
        self.videoAsset = videoAsset
        self.mediaItems = nil
        self.audioDescription = audioDescription
        self.backgroundColor = backgroundColor
    }
    
    init(title: String, imageName: String, photoAsset: PHAsset, audioDescription: String, backgroundColor: String) {
        self.id = UUID()
        self.title = title
        self.imageName = imageName
        self.photoAsset = photoAsset
        self.mediaItems = nil
        self.audioDescription = audioDescription
        self.backgroundColor = backgroundColor
    }
    
    init(title: String, imageName: String, videoAssets: [PHAsset], audioDescription: String, backgroundColor: String) {
        self.id = UUID()
        self.title = title
        self.imageName = imageName
        self.videoAssets = videoAssets
        self.photoAssets = nil
        self.mediaItems = nil
        self.audioDescription = audioDescription
        self.backgroundColor = backgroundColor
    }
    
    init(title: String, imageName: String, photoAssets: [PHAsset], audioDescription: String, backgroundColor: String) {
        self.id = UUID()
        self.title = title
        self.imageName = imageName
        self.videoAssets = nil
        self.photoAssets = photoAssets
        self.mediaItems = nil
        self.audioDescription = audioDescription
        self.backgroundColor = backgroundColor
    }
    
    init(title: String, imageName: String, videoAssets: [PHAsset]?, photoAssets: [PHAsset]?, audioDescription: String, backgroundColor: String) {
        self.id = UUID()
        self.title = title
        self.imageName = imageName
        self.videoAssets = videoAssets
        self.photoAssets = photoAssets
        self.mediaItems = nil
        self.audioDescription = audioDescription
        self.backgroundColor = backgroundColor
    }
    
    // NEW: Initializer with media items
    init(title: String, imageName: String, videoAssets: [PHAsset]?, photoAssets: [PHAsset]?, mediaItems: [SavedMediaItem]?, audioDescription: String, backgroundColor: String) {
        self.id = UUID()
        self.title = title
        self.imageName = imageName
        self.videoAssets = videoAssets
        self.photoAssets = photoAssets
        self.mediaItems = mediaItems
        self.audioDescription = audioDescription
        self.backgroundColor = backgroundColor
    }
    
    // NEW: UUID-preserving initializers for persistence conversion
    init(id: UUID, title: String, imageName: String, videoAsset: PHAsset, audioDescription: String, backgroundColor: String) {
        self.id = id
        self.title = title
        self.imageName = imageName
        self.videoFileName = nil
        self.videoAsset = videoAsset
        self.photoAsset = nil
        self.videoAssets = nil
        self.photoAssets = nil
        self.mediaItems = nil
        self.audioDescription = audioDescription
        self.backgroundColor = backgroundColor
    }
    
    init(id: UUID, title: String, imageName: String, photoAsset: PHAsset, audioDescription: String, backgroundColor: String) {
        self.id = id
        self.title = title
        self.imageName = imageName
        self.videoFileName = nil
        self.videoAsset = nil
        self.photoAsset = photoAsset
        self.videoAssets = nil
        self.photoAssets = nil
        self.mediaItems = nil
        self.audioDescription = audioDescription
        self.backgroundColor = backgroundColor
    }
    
    init(id: UUID, title: String, imageName: String, videoAssets: [PHAsset]?, photoAssets: [PHAsset]?, mediaItems: [SavedMediaItem]?, audioDescription: String, backgroundColor: String) {
        self.id = id
        self.title = title
        self.imageName = imageName
        self.videoFileName = nil
        self.videoAsset = nil
        self.photoAsset = nil
        self.videoAssets = videoAssets
        self.photoAssets = photoAssets
        self.mediaItems = mediaItems
        self.audioDescription = audioDescription
        self.backgroundColor = backgroundColor
    }
    
    // NEW: UUID-preserving initializer for local video files
    init(id: UUID, title: String, imageName: String, videoFileName: String, audioDescription: String, backgroundColor: String) {
        self.id = id
        self.title = title
        self.imageName = imageName
        self.videoFileName = videoFileName
        self.videoAsset = nil
        self.photoAsset = nil
        self.videoAssets = nil
        self.photoAssets = nil
        self.mediaItems = nil
        self.audioDescription = audioDescription
        self.backgroundColor = backgroundColor
    }
    
    // MARK: - Codable Conformance
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        imageName = try container.decode(String.self, forKey: .imageName)
        videoFileName = try container.decodeIfPresent(String.self, forKey: .videoFileName)
        audioDescription = try container.decode(String.self, forKey: .audioDescription)
        backgroundColor = try container.decode(String.self, forKey: .backgroundColor)
        mediaItems = try container.decodeIfPresent([SavedMediaItem].self, forKey: .mediaItems)

        // Decode single video asset identifier and fetch the asset
        if let videoAssetIdentifier = try container.decodeIfPresent(String.self, forKey: .videoAssetIdentifier) {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [videoAssetIdentifier], options: nil)
            videoAsset = fetchResult.firstObject
        }

        // Decode single photo asset identifier and fetch the asset
        if let photoAssetIdentifier = try container.decodeIfPresent(String.self, forKey: .photoAssetIdentifier) {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [photoAssetIdentifier], options: nil)
            photoAsset = fetchResult.firstObject
        }

        // Decode video asset identifiers and fetch the assets
        if let videoAssetIdentifiers = try container.decodeIfPresent([String].self, forKey: .videoAssetIdentifiers) {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: videoAssetIdentifiers, options: nil)
            var assets: [PHAsset] = []
            fetchResult.enumerateObjects { asset, _, _ in assets.append(asset) }
            videoAssets = assets
        }

        // Decode photo asset identifiers and fetch the assets
        if let photoAssetIdentifiers = try container.decodeIfPresent([String].self, forKey: .photoAssetIdentifiers) {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: photoAssetIdentifiers, options: nil)
            var assets: [PHAsset] = []
            fetchResult.enumerateObjects { asset, _, _ in assets.append(asset) }
            photoAssets = assets
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(imageName, forKey: .imageName)
        try container.encodeIfPresent(videoFileName, forKey: .videoFileName)
        try container.encode(audioDescription, forKey: .audioDescription)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encodeIfPresent(mediaItems, forKey: .mediaItems)

        // Encode PHAsset local identifiers
        try container.encodeIfPresent(videoAsset?.localIdentifier, forKey: .videoAssetIdentifier)
        try container.encodeIfPresent(photoAsset?.localIdentifier, forKey: .photoAssetIdentifier)
        try container.encodeIfPresent(videoAssets?.map { $0.localIdentifier }, forKey: .videoAssetIdentifiers)
        try container.encodeIfPresent(photoAssets?.map { $0.localIdentifier }, forKey: .photoAssetIdentifiers)
    }

    var isVideoCollection: Bool {
        videoAssets != nil && videoAssets!.count > 1
    }
    
    var isPhotoCollection: Bool {
        photoAssets != nil && photoAssets!.count > 1
    }
    
    var isMixedMediaCollection: Bool {
        (videoAssets?.count ?? 0) > 0 && (photoAssets?.count ?? 0) > 0
    }
    
    var isPhoto: Bool {
        photoAsset != nil
    }
    
    var isVideo: Bool {
        videoAsset != nil
    }
    
    // NEW: Get individual names for media items
    func getMediaItemName(for asset: PHAsset) -> String? {
        return mediaItems?.first { $0.assetIdentifier == asset.localIdentifier }?.customName
    }
    
    static let sampleActivities: [ActivityItem] = [
        ActivityItem(
            title: "Eat Breakfast",
            imageName: "fork.knife",
            videoFileName: "breakfast_video",
            audioDescription: "A child is eating a healthy breakfast with cereal, toast, and juice",
            backgroundColor: "sage"
        )
//        ActivityItem(
//            title: "Brush Teeth",
//            imageName: "mouth",
//            videoFileName: "brushteeth_video",
//            audioDescription: "A child is brushing their teeth to keep them clean and healthy",
//            backgroundColor: "softBlue"
//        ),
//        ActivityItem(
//            title: "Play with Blocks",
//            imageName: "cube.box",
//            videoFileName: "blocks_video",
//            audioDescription: "A child is playing and building with colorful blocks",
//            backgroundColor: "warmBeige"
//        ),
//        ActivityItem(
//            title: "Read a Book",
//            imageName: "book",
//            videoFileName: "reading_video",
//            audioDescription: "A child is reading a book and learning new words",
//            backgroundColor: "softBlue"
//        ),
//        ActivityItem(
//            title: "Say Hello",
//            imageName: "hand.wave",
//            videoFileName: "hello_video",
//            audioDescription: "A child is waving hello to say hi to friends",
//            backgroundColor: "sage"
//        ),
//        ActivityItem(
//            title: "Get Dressed",
//            imageName: "tshirt",
//            videoFileName: "dressed_video",
//            audioDescription: "A child is getting dressed and putting on clothes",
//            backgroundColor: "softBlue"
//        )
    ]
    
    // Add Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ActivityItem, rhs: ActivityItem) -> Bool {
        return lhs.id == rhs.id
    }
}