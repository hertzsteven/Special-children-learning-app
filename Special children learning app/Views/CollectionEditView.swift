//
//  CollectionEditView.swift
//  Special children learning app
//
//  Created by AI Assistant
//

import SwiftUI
import Photos

struct CollectionEditView: View {
    let activityItem: ActivityItem
    let onCollectionUpdated: (ActivityItem) -> Void
    
    @State private var mediaItems: [SavedMediaItem]
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var showingMediaItemEditor = false
    @State private var itemToEdit: SavedMediaItem?
    
    init(activity: ActivityItem, onCollectionUpdated: @escaping (ActivityItem) -> Void) {
        print("-----",activity.title)
        print("-----",activity.id)
        dump(activity)

        print("-----")
        self.activityItem = activity
        self.onCollectionUpdated = onCollectionUpdated
        self._mediaItems = State(initialValue: activity.mediaItems ?? [])
    }
    
    var body: some View {
        List {
            ForEach(mediaItems) { item in
                Button(action: {
                    itemToEdit = item
                    showingMediaItemEditor = true
                }) {
                    HStack(spacing: 16) {
                        // Thumbnail
                        if let thumbnail = thumbnails[item.assetIdentifier] {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 60, height: 60)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                }
                        }
                        
                        // Name and audio indicator
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.customName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if item.audioRecordingFileName != nil {
                                HStack(spacing: 4) {
                                    Image(systemName: "mic.fill")
                                        .font(.caption)
                                    Text("Audio")
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .onMove(perform: moveItems)
            .onDelete(perform: deleteItems)
        }
        .listStyle(PlainListStyle())
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Edit '\(activityItem.title)'").font(.headline)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .onAppear {
            loadThumbnails()
        }
        .sheet(isPresented: $showingMediaItemEditor) {
            if let itemToEdit = itemToEdit {
                MediaItemEditView(
                    mediaItem: itemToEdit,
                    onSave: { updatedItem in
                        // Update local state
                        if let index = mediaItems.firstIndex(where: { $0.id == updatedItem.id }) {
                            mediaItems.remove(at: index)
                            mediaItems.insert(updatedItem, at: index)
//                            mediaItems[index].customName = updatedItem.customName
                            dump(mediaItems[index])
                            print(index)
                        }
                        
                        // Persist change
                        VideoCollectionPersistence.shared.updateMediaItemInCollection(activityItem.id, updatedMediaItem: updatedItem)
                        
                        // Notify parent view
                        notifyParentOfUpdate()
                        
                        showingMediaItemEditor = false
                    },
                    onCancel: {
                        showingMediaItemEditor = false
                    }
                )
            }
        }
    }
    
    private func loadThumbnails() {
        let identifiers = mediaItems.map { $0.assetIdentifier }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        
        fetchResult.enumerateObjects { asset, _, _ in
            manager.requestImage(
                for: asset,
                targetSize: CGSize(width: 120, height: 120),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image = image {
                    DispatchQueue.main.async {
                        self.thumbnails[asset.localIdentifier] = image
                    }
                }
            }
        }
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        mediaItems.move(fromOffsets: source, toOffset: destination)
        VideoCollectionPersistence.shared.updateCollection(activityItem.id, with: mediaItems)
        notifyParentOfUpdate()
    }
    
    private func deleteItems(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { mediaItems[$0] }
        mediaItems.remove(atOffsets: offsets)
        
        for item in itemsToDelete {
            VideoCollectionPersistence.shared.removeMediaItemFromCollection(activityItem.id, mediaItemId: item.id)
        }
        notifyParentOfUpdate()
    }
    
    private func notifyParentOfUpdate() {
        let updatedActivity = activityItem.updatingMediaItems(with: mediaItems)
        onCollectionUpdated(updatedActivity)
    }
}

extension ActivityItem {
    func updatingMediaItems(with newItems: [SavedMediaItem]) -> ActivityItem {
        var updatedActivity = self
        updatedActivity.mediaItems = newItems
        
        // Re-fetch assets based on new order and items
        let identifiers = newItems.map { $0.assetIdentifier }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        
        var assets: [PHAsset] = []
        let orderedIdentifiers = newItems.map { $0.assetIdentifier }
        
        var fetchedAssets: [String: PHAsset] = [:]
        fetchResult.enumerateObjects { asset, _, _ in
            fetchedAssets[asset.localIdentifier] = asset
        }
        
        // Reorder assets to match newItems order
        assets = orderedIdentifiers.compactMap { fetchedAssets[$0] }
        
        updatedActivity.videoAssets = assets.filter { $0.mediaType == .video }
        updatedActivity.photoAssets = assets.filter { $0.mediaType == .image }
        
        return updatedActivity
    }
}

#Preview {
    NavigationView {
        CollectionEditView(
            activity: ActivityItem.sampleActivities.first(where: { $0.isVideoCollection })!,
            onCollectionUpdated: { _ in }
        )
    }
}
