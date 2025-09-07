//
//  VideoCollectionPersistence.swift
//  Special children learning app
//
//  Created by Steven Hertz on 9/4/25.
//

import Foundation
import Photos

// MARK: - Individual Media Item with Name and Audio
struct SavedMediaItem: Codable, Identifiable, Hashable {
    let id: UUID
    let assetIdentifier: String
    let customName: String
    let audioRecordingFileName: String? // NEW: Optional audio recording
    
    init(assetIdentifier: String, customName: String, audioRecordingFileName: String? = nil) {
        self.id = UUID()
        self.assetIdentifier = assetIdentifier
        self.customName = customName
        self.audioRecordingFileName = audioRecordingFileName
    }
    
    // NEW: Get full URL for audio file
    var audioRecordingURL: URL? {
        guard let fileName = audioRecordingFileName else { return nil }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("audio_recordings")
            .appendingPathComponent(fileName)
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(assetIdentifier)
        hasher.combine(customName)
        hasher.combine(audioRecordingFileName)
    }
    
    static func == (lhs: SavedMediaItem, rhs: SavedMediaItem) -> Bool {
        return lhs.id == rhs.id && lhs.assetIdentifier == rhs.assetIdentifier
    }
}

// MARK: - Codable Models for Persistence
struct SavedVideoCollection: Codable, Identifiable {
    let id: UUID
    let title: String
    let imageName: String
    let assetIdentifiers: [String] // Keep for backward compatibility
    let mediaItems: [SavedMediaItem]? // NEW: Individual media with names
    let backgroundColor: String
    let createdDate: Date
    
    var audioDescription: String {
        let count = mediaItems?.count ?? assetIdentifiers.count
        return "A collection of \(count) items from your library"
    }
    
    // Computed property to get all identifiers (for backward compatibility)
    var allAssetIdentifiers: [String] {
        return mediaItems?.map { $0.assetIdentifier } ?? assetIdentifiers
    }
}

// MARK: - Persistence Manager
@MainActor
class VideoCollectionPersistence: ObservableObject {
    static let shared = VideoCollectionPersistence()
    
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let collectionsFileName = "video_collections.json"
    private let audioRecordingsDirectory = "audio_recordings" // NEW: Audio recordings folder
    
    private var collectionsFileURL: URL {
        documentsDirectory.appendingPathComponent(collectionsFileName)
    }
    
    // NEW: Audio recordings directory URL
    private var audioRecordingsDirectoryURL: URL {
        documentsDirectory.appendingPathComponent(audioRecordingsDirectory)
    }
    
    @Published var savedCollections: [SavedVideoCollection] = []
    
    private init() {
        createAudioRecordingsDirectoryIfNeeded()
        loadCollections()
    }
    
    // NEW: Create audio recordings directory
    private func createAudioRecordingsDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(
                at: audioRecordingsDirectoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            print("✅ Audio recordings directory created/verified")
        } catch {
            print("❌ Failed to create audio recordings directory: \(error)")
        }
    }
    
    // NEW: Save audio file and return filename
    func saveAudioRecording(from sourceURL: URL) -> String? {
        let fileName = "audio_\(UUID().uuidString).m4a"
        let destinationURL = audioRecordingsDirectoryURL.appendingPathComponent(fileName)
        
        do {
            // Copy the audio file to our recordings directory
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            print("✅ Saved audio recording: \(fileName)")
            return fileName
        } catch {
            print("❌ Failed to save audio recording: \(error)")
            return nil
        }
    }
    
    // NEW: Delete audio file
    func deleteAudioRecording(fileName: String) {
        let fileURL = audioRecordingsDirectoryURL.appendingPathComponent(fileName)
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("✅ Deleted audio recording: \(fileName)")
        } catch {
            print("❌ Failed to delete audio recording: \(error)")
        }
    }
    
    // MARK: - Save/Load Operations
    
    func saveCollection(title: String, assetIdentifiers: [String], imageName: String = "play.rectangle.on.rectangle", backgroundColor: String = "warmBeige") {
        let collection = SavedVideoCollection(
            id: UUID(),
            title: title,
            imageName: imageName,
            assetIdentifiers: assetIdentifiers,
            mediaItems: nil, // Legacy method - no individual names
            backgroundColor: backgroundColor,
            createdDate: Date()
        )
        
        savedCollections.append(collection)
        saveCollections()
    }
    
    // NEW: Save collection with individual media names
    func saveCollectionWithMediaItems(title: String, mediaItems: [SavedMediaItem], imageName: String = "rectangle.stack", backgroundColor: String = "warmBeige") {
        let collection = SavedVideoCollection(
            id: UUID(),
            title: title,
            imageName: imageName,
            assetIdentifiers: [], // Empty for new format
            mediaItems: mediaItems,
            backgroundColor: backgroundColor,
            createdDate: Date()
        )
        
        savedCollections.append(collection)
        saveCollections()
    }
    
    func deleteCollection(_ collection: SavedVideoCollection) {
        savedCollections.removeAll { $0.id == collection.id }
        saveCollections()
    }
    
    func renameCollection(_ collection: SavedVideoCollection, newTitle: String) {
        if let index = savedCollections.firstIndex(where: { $0.id == collection.id }) {
            let updatedCollection = SavedVideoCollection(
                id: collection.id,
                title: newTitle,
                imageName: collection.imageName,
                assetIdentifiers: collection.assetIdentifiers,
                mediaItems: collection.mediaItems, // Add this missing parameter
                backgroundColor: collection.backgroundColor,
                createdDate: collection.createdDate
            )
            savedCollections[index] = updatedCollection
            saveCollections()
        }
    }
    
    private func saveCollections() {
        do {
            let data = try JSONEncoder().encode(savedCollections)
            try data.write(to: collectionsFileURL)
            print("✅ Saved \(savedCollections.count) video collections")
        } catch {
            print("❌ Failed to save collections: \(error)")
        }
    }
    
    private func loadCollections() {
        do {
            let data = try Data(contentsOf: collectionsFileURL)
            savedCollections = try JSONDecoder().decode([SavedVideoCollection].self, from: data)
            print("✅ Loaded \(savedCollections.count) saved video collections")
        } catch {
            print("📝 No saved collections found (this is normal on first launch)")
            savedCollections = []
        }
    }
    
    // MARK: - Convert to ActivityItems
    
    func convertToActivityItems() async -> [ActivityItem] {
        var activityItems: [ActivityItem] = []
        
        for collection in savedCollections {
            // Use the computed property that handles both old and new formats
            let identifiersToFetch = collection.allAssetIdentifiers
            
            if let validAssets = await getValidAssets(from: identifiersToFetch), !validAssets.isEmpty {
                
                let videoAssets = validAssets.filter { $0.mediaType == .video }
                let photoAssets = validAssets.filter { $0.mediaType == .image }
                
                let activityItem: ActivityItem
                
                if videoAssets.count == 1 && photoAssets.isEmpty {
                    // Single video
                    activityItem = ActivityItem(
                        title: collection.title,
                        imageName: collection.imageName,
                        videoAsset: videoAssets.first!,
                        audioDescription: collection.audioDescription,
                        backgroundColor: collection.backgroundColor
                    )
                } else if photoAssets.count == 1 && videoAssets.isEmpty {
                    // Single photo
                    activityItem = ActivityItem(
                        title: collection.title,
                        imageName: collection.imageName,
                        photoAsset: photoAssets.first!,
                        audioDescription: collection.audioDescription,
                        backgroundColor: collection.backgroundColor
                    )
                } else if !videoAssets.isEmpty && photoAssets.isEmpty {
                    // Video collection - NOW includes mediaItems
                    activityItem = ActivityItem(
                        title: collection.title,
                        imageName: collection.imageName,
                        videoAssets: videoAssets,
                        photoAssets: nil,
                        mediaItems: collection.mediaItems,
                        audioDescription: collection.audioDescription,
                        backgroundColor: collection.backgroundColor
                    )
                } else if videoAssets.isEmpty && !photoAssets.isEmpty {
                    // Photo collection - NOW includes mediaItems
                    activityItem = ActivityItem(
                        title: collection.title,
                        imageName: collection.imageName,
                        videoAssets: nil,
                        photoAssets: photoAssets,
                        mediaItems: collection.mediaItems,
                        audioDescription: collection.audioDescription,
                        backgroundColor: collection.backgroundColor
                    )
                } else {
                    // Mixed media collection - NOW includes mediaItems
                    activityItem = ActivityItem(
                        title: collection.title,
                        imageName: collection.imageName,
                        videoAssets: videoAssets.isEmpty ? nil : videoAssets,
                        photoAssets: photoAssets.isEmpty ? nil : photoAssets,
                        mediaItems: collection.mediaItems,
                        audioDescription: collection.audioDescription,
                        backgroundColor: collection.backgroundColor
                    )
                }
                
                activityItems.append(activityItem)
            } else {
                // Handle missing media - could show placeholder or remove
                print("⚠️ Collection '\(collection.title)' has no valid media")
            }
        }
        
        return activityItems
    }
    
    private func getValidAssets(from identifiers: [String]) async -> [PHAsset]? {
        return await withCheckedContinuation { continuation in
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            var assets: [PHAsset] = []
            
            fetchResult.enumerateObjects { asset, _, _ in
                // Include both video and photo assets that still exist
                if asset.mediaType == .video || asset.mediaType == .image {
                    assets.append(asset)
                }
            }
            
            continuation.resume(returning: assets.isEmpty ? nil : assets)
        }
    }
    
    // MARK: - Utility Methods
    
    func getCollectionCount() -> Int {
        return savedCollections.count
    }
    
    func clearAllCollections() {
        savedCollections.removeAll()
        saveCollections()
    }
}