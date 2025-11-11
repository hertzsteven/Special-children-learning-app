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
    var customName: String
    let audioRecordingFileName: String? // NEW: Optional audio recording
    
    init(assetIdentifier: String, customName: String, audioRecordingFileName: String? = nil) {
        self.id = UUID()
        self.assetIdentifier = assetIdentifier
        self.customName = customName
        self.audioRecordingFileName = audioRecordingFileName
    }
    
    // NEW: Init with existing ID (for updates)
    init(id: UUID, assetIdentifier: String, customName: String, audioRecordingFileName: String? = nil) {
        self.id = id
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
struct SavedVideoCollection: Codable, Identifiable, Equatable {
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
    
    // Equatable conformance
    static func == (lhs: SavedVideoCollection, rhs: SavedVideoCollection) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.imageName == rhs.imageName &&
               lhs.assetIdentifiers == rhs.assetIdentifiers &&
               lhs.mediaItems == rhs.mediaItems &&
               lhs.backgroundColor == rhs.backgroundColor &&
               lhs.createdDate == rhs.createdDate
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
    
    // NEW: Rename collection by ID (for use in CollectionEditView)
    func renameCollectionById(_ collectionId: UUID, newTitle: String) {
        if let index = savedCollections.firstIndex(where: { $0.id == collectionId }) {
            let collection = savedCollections[index]
            let updatedCollection = SavedVideoCollection(
                id: collection.id,
                title: newTitle,
                imageName: collection.imageName,
                assetIdentifiers: collection.assetIdentifiers,
                mediaItems: collection.mediaItems,
                backgroundColor: collection.backgroundColor,
                createdDate: collection.createdDate
            )
            savedCollections[index] = updatedCollection
            saveCollections()
            print("✅ Renamed collection to '\(newTitle)'")
        } else {
            print("❌ Could not find collection with ID '\(collectionId)' to rename")
        }
    }

    func saveCollections() {
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
    
    // instead of collapsing to single videoAsset/photoAsset when count == 1.
    func convertToMediaCollectionItems() async -> [MediaCollection] {
        var mediaCollectionItems: [MediaCollection] = []
        
        for collection in savedCollections {
            let identifiersToFetch = collection.allAssetIdentifiers
            
            if let validAssets = await getValidAssets(from: identifiersToFetch), !validAssets.isEmpty {
                let videoAssets = validAssets.filter { $0.mediaType == .video }
                let photoAssets = validAssets.filter { $0.mediaType == .image }
                
                let mediaCollectionItem = MediaCollection(
                    id: collection.id,
                    title: collection.title,
                    imageName: collection.imageName,
                    videoAssets: videoAssets.isEmpty ? nil : videoAssets,
                    photoAssets: photoAssets.isEmpty ? nil : photoAssets,
                    mediaItems: collection.mediaItems,
                    audioDescription: collection.audioDescription,
                    backgroundColor: collection.backgroundColor
                )
                
                mediaCollectionItems.append(mediaCollectionItem)
            } else {
                print("⚠️ Collection '\(collection.title)' has no valid media")
            }
        }
        
        return mediaCollectionItems
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
    
    // MARK: - Collection Update Operations
    
    func updateCollection(_ collectionId: UUID, with updatedItems: [SavedMediaItem]) {
        if let index = savedCollections.firstIndex(where: { $0.id == collectionId }) {
            let collection = savedCollections[index]
            let updatedCollection = SavedVideoCollection(
                id: collection.id,
                title: collection.title,
                imageName: collection.imageName,
                assetIdentifiers: [], // Clear old format
                mediaItems: updatedItems,
                backgroundColor: collection.backgroundColor,
                createdDate: collection.createdDate
            )
            savedCollections[index] = updatedCollection
            saveCollections()
            print("✅ Updated collection '\(collection.title)' with \(updatedItems.count) items")
        }
    }
    
    func addMediaItemToCollection(_ collectionId: UUID, mediaItem: SavedMediaItem) {
        if let index = savedCollections.firstIndex(where: { $0.id == collectionId }) {
            let collection = savedCollections[index]
            var currentItems = collection.mediaItems ?? []
            
            // Check if item already exists (by asset identifier)
            if !currentItems.contains(where: { $0.assetIdentifier == mediaItem.assetIdentifier }) {
                currentItems.append(mediaItem)
                updateCollection(collectionId, with: currentItems)
            } else {
                print("⚠️ Media item already exists in collection")
            }
        }
    }
    
    func removeMediaItemFromCollection(_ collectionId: UUID, mediaItemId: UUID) {
        if let index = savedCollections.firstIndex(where: { $0.id == collectionId }) {
            let collection = savedCollections[index]
            var currentItems = collection.mediaItems ?? []
            
            // Remove the audio file if it exists
            if let itemToRemove = currentItems.first(where: { $0.id == mediaItemId }),
               let audioFileName = itemToRemove.audioRecordingFileName {
                deleteAudioRecording(fileName: audioFileName)
            }
            
            currentItems.removeAll { $0.id == mediaItemId }
            updateCollection(collectionId, with: currentItems)
        }
    }
    
    func updateMediaItemInCollection(_ collectionId: UUID, updatedMediaItem: SavedMediaItem) {
        if let index = savedCollections.firstIndex(where: { $0.id == collectionId }) {
            let collection = savedCollections[index]
            var currentItems = collection.mediaItems ?? []
            
            if let itemIndex = currentItems.firstIndex(where: { $0.id == updatedMediaItem.id }) {
                // If we're changing the audio file, clean up the old one
                let oldItem = currentItems[itemIndex]
                if let oldAudioFileName = oldItem.audioRecordingFileName,
                   oldAudioFileName != updatedMediaItem.audioRecordingFileName {
                    deleteAudioRecording(fileName: oldAudioFileName)
                }
                
                currentItems[itemIndex] = updatedMediaItem
                
                // Update the collection with new items
                let updatedCollection = SavedVideoCollection(
                    id: collection.id,
                    title: collection.title,
                    imageName: collection.imageName,
                    assetIdentifiers: [], // Clear old format
                    mediaItems: currentItems,
                    backgroundColor: collection.backgroundColor,
                    createdDate: collection.createdDate
                )
                savedCollections[index] = updatedCollection
                saveCollections()
                
                print("✅ Updated media item '\(updatedMediaItem.customName)' in collection")
                
                // Force a published update - this should trigger UI refresh
                objectWillChange.send()
            }
        } else {
            print(">>> Failed to find collection with ID '\(collectionId)'")
        }
    }
    
    func updateMediaItemName(_ collectionId: UUID, mediaItemId: UUID, newName: String) {
        if let index = savedCollections.firstIndex(where: { $0.id == collectionId }) {
            let collection = savedCollections[index]
            var currentItems = collection.mediaItems ?? []
            
            if let itemIndex = currentItems.firstIndex(where: { $0.id == mediaItemId }) {
                let oldItem = currentItems[itemIndex]
                let updatedItem = SavedMediaItem(
                    assetIdentifier: oldItem.assetIdentifier,
                    customName: newName,
                    audioRecordingFileName: oldItem.audioRecordingFileName
                )
                // Preserve the original ID
                let finalItem = SavedMediaItem(
                    id: oldItem.id,
                    assetIdentifier: oldItem.assetIdentifier,
                    customName: newName,
                    audioRecordingFileName: oldItem.audioRecordingFileName
                )
                currentItems[itemIndex] = finalItem
                updateCollection(collectionId, with: currentItems)
            }
        }
    }
    
    func updateMediaItemAudio(_ collectionId: UUID, mediaItemId: UUID, newAudioURL: URL?) {
        if let index = savedCollections.firstIndex(where: { $0.id == collectionId }) {
            let collection = savedCollections[index]
            var currentItems = collection.mediaItems ?? []
            
            if let itemIndex = currentItems.firstIndex(where: { $0.id == mediaItemId }) {
                let oldItem = currentItems[itemIndex]
                
                // Handle new audio file
                var newAudioFileName: String? = nil
                if let audioURL = newAudioURL {
                    newAudioFileName = saveAudioRecording(from: audioURL)
                }
                
                // Clean up old audio file if it exists and we're replacing it
                if let oldAudioFileName = oldItem.audioRecordingFileName,
                   newAudioFileName != oldAudioFileName {
                    deleteAudioRecording(fileName: oldAudioFileName)
                }
                
                let updatedItem = SavedMediaItem(
                    id: oldItem.id,
                    assetIdentifier: oldItem.assetIdentifier,
                    customName: oldItem.customName,
                    audioRecordingFileName: newAudioFileName
                )
                currentItems[itemIndex] = updatedItem
                updateCollection(collectionId, with: currentItems)
            }
        }
    }
    
    func getCollection(by id: UUID) -> SavedVideoCollection? {
        return savedCollections.first { $0.id == id }
    }
    
    func getMediaItemsForCollection(_ collectionId: UUID) -> [SavedMediaItem] {
        return getCollection(by: collectionId)?.mediaItems ?? []
    }
    
    // MARK: - Utility Methods
    
    func getCollectionCount() -> Int {
        return savedCollections.count
    }
    
    func clearAllCollections() {
        savedCollections.removeAll()
        saveCollections()
    }
    
    /// Add multiple media items to a collection at once (more efficient than individual adds)
    func addMultipleMediaItemsToCollection(_ collectionId: UUID, mediaItems: [SavedMediaItem]) {
        if let index = savedCollections.firstIndex(where: { $0.id == collectionId }) {
            let collection = savedCollections[index]
            var currentItems = collection.mediaItems ?? []
            
            // Filter out items that already exist (by asset identifier)
            let newItems = mediaItems.filter { newItem in
                !currentItems.contains(where: { $0.assetIdentifier == newItem.assetIdentifier })
            }
            
            if !newItems.isEmpty {
                currentItems.append(contentsOf: newItems)
                updateCollection(collectionId, with: currentItems)
                print("✅ Added \(newItems.count) new media items to collection")
            } else {
                print("⚠️ No new items to add - all items already exist in collection")
            }
        } else {
            print("❌ Could not find collection with ID '\(collectionId)' to add media items")
        }
    }
}
