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
    let photoCount: Int
    let totalMediaCount: Int
    
    init(assetCollection: PHAssetCollection, videosOnly: Bool = true) {
        self.id = assetCollection.localIdentifier
        self.title = assetCollection.localizedTitle ?? "Unknown Album"
        self.assetCollection = assetCollection
        
        // Fetch video count
        let videoFetchOptions = PHFetchOptions()
        videoFetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        videoFetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let videoAssets = PHAsset.fetchAssets(in: assetCollection, options: videoFetchOptions)
        self.videoCount = videoAssets.count
        
        if videosOnly {
            self.photoCount = 0
            self.totalMediaCount = videoCount
            self.thumbnailAsset = videoAssets.firstObject
        } else {
            // Fetch photo count
            let photoFetchOptions = PHFetchOptions()
            photoFetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let photoAssets = PHAsset.fetchAssets(in: assetCollection, options: photoFetchOptions)
            self.photoCount = photoAssets.count
            self.totalMediaCount = videoCount + photoCount
            
            // Use video thumbnail if available, otherwise photo
            self.thumbnailAsset = videoAssets.firstObject ?? photoAssets.firstObject
        }
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

struct MediaItem: Identifiable, Hashable {
    let id: String
    let asset: PHAsset
    let duration: TimeInterval?
    let creationDate: Date?
    let isVideo: Bool
    
    init(asset: PHAsset, duration: TimeInterval? = nil, creationDate: Date? = nil) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.duration = asset.mediaType == .video ? (duration ?? asset.duration) : nil
        self.creationDate = creationDate ?? asset.creationDate
        self.isVideo = asset.mediaType == .video
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
                    let album = PhotoAlbum(assetCollection: collection, videosOnly: true)
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
                        let album = PhotoAlbum(assetCollection: collection, videosOnly: true)
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
    
    func fetchAllMediaAlbums() async {
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
                    let album = PhotoAlbum(assetCollection: collection, videosOnly: false)
                    if album.totalMediaCount > 0 {
                        albumList.append(album)
                    }
                }
                
                // Process smart albums
                smartAlbums.enumerateObjects { collection, _, _ in
                    // Skip certain system albums
                    let excludedSubtypes: [PHAssetCollectionSubtype] = [
                        .smartAlbumAllHidden,
                        .smartAlbumSelfPortraits,
                        .smartAlbumDepthEffect
                    ]
                    
                    if !excludedSubtypes.contains(collection.assetCollectionSubtype) {
                        let album = PhotoAlbum(assetCollection: collection, videosOnly: false)
                        if album.totalMediaCount > 0 {
                            albumList.append(album)
                        }
                    }
                }
                
                continuation.resume(returning: albumList.sorted { $0.title < $1.title })
            }
            
            albums = fetchedAlbums
        } catch {
            errorMessage = "Failed to load media albums: \(error.localizedDescription)"
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
    
    func fetchAllMedia(from album: PhotoAlbum) async -> [MediaItem] {
        await withCheckedContinuation { continuation in
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d", 
                                               PHAssetMediaType.image.rawValue, 
                                               PHAssetMediaType.video.rawValue)
            fetchOptions.sortDescriptors = [
                NSSortDescriptor(key: "creationDate", ascending: false)
            ]
            
            let assets = PHAsset.fetchAssets(in: album.assetCollection, options: fetchOptions)
            var mediaItems: [MediaItem] = []
            
            assets.enumerateObjects { asset, _, _ in
                mediaItems.append(MediaItem(asset: asset))
            }
            
            continuation.resume(returning: mediaItems)
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

    func fetchPhotoAlbums() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedAlbums = await withCheckedContinuation { (continuation: CheckedContinuation<[PhotoAlbum], Never>) in
                var albumList: [PhotoAlbum] = []
                
                let userAlbums = PHAssetCollection.fetchAssetCollections(
                    with: .album,
                    subtype: .any,
                    options: nil
                )
                
                let smartAlbums = PHAssetCollection.fetchAssetCollections(
                    with: .smartAlbum,
                    subtype: .any,
                    options: nil
                )
                
                userAlbums.enumerateObjects { collection, _, _ in
                    let album = PhotoAlbum(assetCollection: collection, videosOnly: false)
                    if album.photoCount > 0 {
                        albumList.append(album)
                    }
                }
                
                smartAlbums.enumerateObjects { collection, _, _ in
                    let excludedSubtypes: [PHAssetCollectionSubtype] = [
                        .smartAlbumAllHidden,
                        .smartAlbumSelfPortraits,
                        .smartAlbumDepthEffect
                    ]
                    
                    if !excludedSubtypes.contains(collection.assetCollectionSubtype) {
                        let album = PhotoAlbum(assetCollection: collection, videosOnly: false)
                        if album.photoCount > 0 {
                            albumList.append(album)
                        }
                    }
                }
                
                continuation.resume(returning: albumList.sorted { $0.title < $1.title })
            }
            
            albums = fetchedAlbums
        } catch {
            errorMessage = "Failed to load photo albums: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func fetchPhotos(from album: PhotoAlbum) async -> [MediaItem] {
        await withCheckedContinuation { continuation in
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            fetchOptions.sortDescriptors = [
                NSSortDescriptor(key: "creationDate", ascending: false)
            ]
            
            let assets = PHAsset.fetchAssets(in: album.assetCollection, options: fetchOptions)
            var mediaItems: [MediaItem] = []
            
            assets.enumerateObjects { asset, _, _ in
                mediaItems.append(MediaItem(asset: asset))
            }
            
            continuation.resume(returning: mediaItems)
        }
    }
}

extension PHAuthorizationStatus {
    var isAuthorized: Bool {
        self == .authorized || self == .limited
    }
}