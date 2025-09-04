//
//  VideoCollectionPersistence.swift
//  Special children learning app
//
//  Created by Steven Hertz on 9/4/25.
//

import Foundation
import Photos

// MARK: - Codable Models for Persistence
struct SavedVideoCollection: Codable, Identifiable {
    let id: UUID
    let title: String
    let imageName: String
    let assetIdentifiers: [String]
    let backgroundColor: String
    let createdDate: Date
    
    var audioDescription: String {
        "A collection of \(assetIdentifiers.count) videos from your library"
    }
}

// MARK: - Persistence Manager
@MainActor
class VideoCollectionPersistence: ObservableObject {
    static let shared = VideoCollectionPersistence()
    
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let collectionsFileName = "video_collections.json"
    
    private var collectionsFileURL: URL {
        documentsDirectory.appendingPathComponent(collectionsFileName)
    }
    
    @Published var savedCollections: [SavedVideoCollection] = []
    
    private init() {
        loadCollections()
    }
    
    // MARK: - Save/Load Operations
    
    func saveCollection(title: String, assetIdentifiers: [String], imageName: String = "play.rectangle.on.rectangle", backgroundColor: String = "warmBeige") {
        let collection = SavedVideoCollection(
            id: UUID(),
            title: title,
            imageName: imageName,
            assetIdentifiers: assetIdentifiers,
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
            if let validAssets = await getValidAssets(from: collection.assetIdentifiers), !validAssets.isEmpty {
                let activityItem = ActivityItem(
                    title: collection.title,
                    imageName: collection.imageName,
                    videoAssets: validAssets,
                    audioDescription: collection.audioDescription,
                    backgroundColor: collection.backgroundColor
                )
                activityItems.append(activityItem)
            } else {
                // Handle missing videos - could show placeholder or remove
                print("⚠️ Collection '\(collection.title)' has no valid videos")
            }
        }
        
        return activityItems
    }
    
    private func getValidAssets(from identifiers: [String]) async -> [PHAsset]? {
        return await withCheckedContinuation { continuation in
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            var assets: [PHAsset] = []
            
            fetchResult.enumerateObjects { asset, _, _ in
                // Only include video assets that still exist
                if asset.mediaType == .video {
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