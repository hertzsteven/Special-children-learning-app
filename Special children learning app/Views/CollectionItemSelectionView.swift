//
//  CollectionItemSelectionView.swift
//  Special children learning app
//
//  Created by AI Assistant on 9/4/25.
//

import SwiftUI
import Photos

struct CollectionItemSelectionView: View {
    let activity: MediaCollection
    let onDismiss: () -> Void
    let onSelectionComplete: (MediaCollection) -> Void
    
    @State private var selectedItems: Set<String> = []
    @State private var mediaItems: [(asset: PHAsset, name: String?)] = []
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var isLoading = true
    @StateObject private var photoLibraryManager = PhotoLibraryManager()
    
    private var allAssets: [PHAsset] {
        var assets: [PHAsset] = []
        if let videoAssets = activity.videoAssets {
            assets.append(contentsOf: videoAssets)
        }
        if let photoAssets = activity.photoAssets {
            assets.append(contentsOf: photoAssets)
        }
        if let videoAsset = activity.videoAsset {
            assets.append(videoAsset)
        }
        if let photoAsset = activity.photoAsset {
            assets.append(photoAsset)
        }
        return assets
    }
    
    private var selectedAssets: [PHAsset] {
        return mediaItems.compactMap { item in
            selectedItems.contains(item.asset.localIdentifier) ? item.asset : nil
        }
    }
    
    private var allSelected: Bool {
        selectedItems.count == mediaItems.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with collection info
            headerView
            
            Divider()
            
            if isLoading {
                loadingView
            } else {
                // Items list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(mediaItems, id: \.asset.localIdentifier) { item in
                            MediaItemRow(
                                asset: item.asset,
                                name: item.name,
                                thumbnail: thumbnails[item.asset.localIdentifier],
                                isSelected: selectedItems.contains(item.asset.localIdentifier)
                            ) {
                                toggleSelection(for: item.asset)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            
            Divider()
            
            // Bottom controls
            bottomControlsView
        }
        .background(Color(.systemGray6))
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            loadMediaItems()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            // Top navigation
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .font(.body)
                .foregroundColor(.blue)
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(activity.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("\(mediaItems.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(allSelected ? "Deselect All" : "Select All") {
                    toggleSelectAll()
                }
                .font(.body)
                .foregroundColor(.blue)
            }
            
            // Selection indicator - more prominent
            if !selectedItems.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text("\(selectedItems.count) of \(mediaItems.count) selected")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(Color(.systemGray6))
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading media items...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var bottomControlsView: some View {
        VStack(spacing: 0) {
            if !selectedItems.isEmpty {
                Button("View Selected (\(selectedItems.count))") {
                    viewSelectedItems()
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            } else {
                HStack {
                    Image(systemName: "hand.tap")
                        .foregroundColor(.secondary)
                    Text("Select items to view")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 16)
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.systemGray4)),
            alignment: .top
        )
    }
    
    private func loadMediaItems() {
        Task {
            var items: [(asset: PHAsset, name: String?)] = []
            
            // Load all assets with their names
            for asset in allAssets {
                let name = activity.getMediaItemName(for: asset)
                items.append((asset: asset, name: name))
                
                // Load thumbnail
                let thumbnail = await photoLibraryManager.loadThumbnail(
                    for: asset,
                    targetSize: CGSize(width: 100, height: 100)
                )
                
                await MainActor.run {
                    if let thumbnail = thumbnail {
                        self.thumbnails[asset.localIdentifier] = thumbnail
                    }
                }
            }
            
            await MainActor.run {
                self.mediaItems = items
                // Select all by default
                self.selectedItems = Set(items.map { $0.asset.localIdentifier })
                self.isLoading = false
            }
        }
    }
    
    private func toggleSelection(for asset: PHAsset) {
        if selectedItems.contains(asset.localIdentifier) {
            selectedItems.remove(asset.localIdentifier)
        } else {
            selectedItems.insert(asset.localIdentifier)
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func toggleSelectAll() {
        if allSelected {
            selectedItems.removeAll()
        } else {
            selectedItems = Set(mediaItems.map { $0.asset.localIdentifier })
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func viewSelectedItems() {
        // Create a new ActivityItem with only selected assets
        let selectedVideoAssets = selectedAssets.filter { $0.mediaType == .video }
        let selectedPhotoAssets = selectedAssets.filter { $0.mediaType == .image }
        
        // Create filtered media items for names
        let selectedMediaItems = activity.mediaItems?.filter { mediaItem in
            selectedItems.contains(mediaItem.assetIdentifier)
        }
        
        let filteredActivity = MediaCollection(
            title: activity.title,
            imageName: activity.imageName,
            videoAssets: selectedVideoAssets.isEmpty ? nil : selectedVideoAssets,
            photoAssets: selectedPhotoAssets.isEmpty ? nil : selectedPhotoAssets,
            mediaItems: selectedMediaItems,
            audioDescription: "Selected \(selectedAssets.count) items from \(activity.title)",
            backgroundColor: activity.backgroundColor
        )
        
        print("DEBUG: Created filtered activity with:")
        print("  - Video assets: \(selectedVideoAssets.count)")
        print("  - Photo assets: \(selectedPhotoAssets.count)")
        print("  - Media items: \(selectedMediaItems?.count ?? 0)")
        print("  - isVideoCollection: \(filteredActivity.isVideoCollection)")
        print("  - isPhotoCollection: \(filteredActivity.isPhotoCollection)")
        print("  - isMixedMediaCollection: \(filteredActivity.isMixedMediaCollection)")
        
        onSelectionComplete(filteredActivity)
    }
}

struct MediaItemRow: View {
    let asset: PHAsset
    let name: String?
    let thumbnail: UIImage?
    let isSelected: Bool
    let onTap: () -> Void
    
    private var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        } else {
            // Fallback to default name based on type and date
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let dateString = formatter.string(from: asset.creationDate ?? Date())
            return asset.mediaType == .video ? "\(dateString) Video" : "\(dateString) Photo"
        }
    }
    
    private var mediaTypeIcon: String {
        asset.mediaType == .video ? "play.circle.fill" : "photo.circle.fill"
    }
    
    private var mediaTypeColor: Color {
        asset.mediaType == .video ? .blue : .green
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 20) { // Increased spacing for better alignment
                // Thumbnail with larger size
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 80)
                    
                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        ProgressView()
                            .scaleEffect(1.0)
                    }
                    
                    // Media type indicator - smaller and more subtle
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: mediaTypeIcon)
                                .font(.system(size: 14))
                                .foregroundColor(mediaTypeColor)
                                .padding(6)
                                .background(Color.white.opacity(0.9))
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        }
                        Spacer()
                    }
                    .padding(8)
                }
                
                // Name and type - better alignment
                VStack(alignment: .leading, spacing: 6) {
                    Text(displayName)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading) // Ensure consistent alignment
                    
                    // Simple media type label
                    Text(asset.mediaType == .video ? "Video" : "Photo")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading) // Consistent alignment
                }
                .frame(maxWidth: .infinity, alignment: .leading) // Force left alignment of the entire VStack
                
                // Selection indicator - fixed positioning
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.clear)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: 2)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 28, height: 28) // Fixed size to prevent shifting
            }
            .padding(.horizontal, 24) // Consistent horizontal padding
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity) // Ensure full width usage
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue.opacity(0.08) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    CollectionItemSelectionView(
        activity: MediaCollection(
            title: "Sample Collection",
            imageName: "photo.stack",
            photoAssets: [],
            audioDescription: "A sample collection",
            backgroundColor: "sage"
        ),
        onDismiss: {
            print("Dismissed")
        },
        onSelectionComplete: { filteredActivity in
            print("Selected items from: \(filteredActivity.title)")
        }
    )
}
