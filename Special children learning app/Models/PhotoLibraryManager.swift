//
//  PhotoLibraryManager.swift
//  Special children learning app
//
//  Created by Steven Hertz on 9/4/25.
//

import Photos
import SwiftUI
import UIKit

// MARK: - Models for Photo Library
struct PhotoAlbum: Identifiable, Hashable {
    let id: String
    let title: String
    let assetCollection: PHAssetCollection
    let thumbnailAsset: PHAsset?
    let videoCount: Int
    
    init(assetCollection: PHAssetCollection) {
        self.id = assetCollection.localIdentifier
        self.title = assetCollection.localizedTitle ?? "Unknown Album"
        self.assetCollection = assetCollection
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let assets = PHAsset.fetchAssets(in: assetCollection, options: fetchOptions)
        self.videoCount = assets.count
        self.thumbnailAsset = assets.firstObject
    }
}

struct VideoItem: Identifiable, Hashable {
    let id: String
    let asset: PHAsset
    let duration: TimeInterval
    let creationDate: Date?
    
    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.duration = asset.duration
        self.creationDate = asset.creationDate
    }
}

// MARK: - Photo Library Manager
@MainActor
class PhotoLibraryManager: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var albums: [PhotoAlbum] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let imageManager = PHCachingImageManager()
    
    init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    func requestPhotoLibraryAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        
        if status == .authorized || status == .limited {
            await fetchVideoAlbums()
        }
    }
    
    func fetchVideoAlbums() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedAlbums = await withCheckedContinuation { (continuation: CheckedContinuation<[PhotoAlbum], Never>) in
                var albumList: [PhotoAlbum] = []
                
                // Fetch user albums
                let userAlbums = PHAssetCollection.fetchAssetCollections(
                    with: .album,
                    subtype: .any,
                    options: nil
                )
                
                // Fetch smart albums
                let smartAlbums = PHAssetCollection.fetchAssetCollections(
                    with: .smartAlbum,
                    subtype: .any,
                    options: nil
                )
                
                // Process user albums
                userAlbums.enumerateObjects { collection, _, _ in
                    let album = PhotoAlbum(assetCollection: collection)
                    if album.videoCount > 0 {
                        albumList.append(album)
                    }
                }
                
                // Process smart albums (only include those with videos)
                smartAlbums.enumerateObjects { collection, _, _ in
                    // Skip certain system albums
                    let excludedSubtypes: [PHAssetCollectionSubtype] = [
                        .smartAlbumAllHidden,
                        .smartAlbumSelfPortraits,
                        .smartAlbumDepthEffect
                    ]
                    
                    if !excludedSubtypes.contains(collection.assetCollectionSubtype) {
                        let album = PhotoAlbum(assetCollection: collection)
                        if album.videoCount > 0 {
                            albumList.append(album)
                        }
                    }
                }
                
                continuation.resume(returning: albumList.sorted { $0.title < $1.title })
            }
            
            albums = fetchedAlbums
        } catch {
            errorMessage = "Failed to load video albums: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func fetchVideos(from album: PhotoAlbum) async -> [VideoItem] {
        await withCheckedContinuation { continuation in
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
            fetchOptions.sortDescriptors = [
                NSSortDescriptor(key: "creationDate", ascending: false)
            ]
            
            let assets = PHAsset.fetchAssets(in: album.assetCollection, options: fetchOptions)
            var videoItems: [VideoItem] = []
            
            assets.enumerateObjects { asset, _, _ in
                videoItems.append(VideoItem(asset: asset))
            }
            
            continuation.resume(returning: videoItems)
        }
    }
    
    func loadThumbnail(for asset: PHAsset, targetSize: CGSize = CGSize(width: 300, height: 300)) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    func getVideoURL(for asset: PHAsset) async -> URL? {
        await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                if let urlAsset = avAsset as? AVURLAsset {
                    continuation.resume(returning: urlAsset.url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

extension PHAuthorizationStatus {
    var isAuthorized: Bool {
        self == .authorized || self == .limited
    }
}