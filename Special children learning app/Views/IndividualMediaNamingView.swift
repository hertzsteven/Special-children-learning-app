//
//  IndividualMediaNamingView.swift
//  Special children learning app
//
//  Created by AI Assistant on 9/4/25.
//

import SwiftUI
import Photos
import Foundation

struct MediaItemForNaming: Identifiable {
    let id = UUID()
    let asset: PHAsset
    var customName: String
    var isSkipped: Bool = false
    
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

struct IndividualMediaNamingView: View {
    let mediaItems: [MediaItemForNaming]
    let onComplete: ([MediaItemForNaming]) -> Void
    let onCollectionComplete: ([MediaItemForNaming], String) -> Void // NEW: Collection callback
    let onCancel: () -> Void
    
    @State private var currentIndex = 0
    @State private var workingItems: [MediaItemForNaming]
    @State private var currentName = ""
    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail = false
    @State private var showingCollectionNaming = false // NEW: Collection naming step
    @State private var collectionName = ""
    @StateObject private var photoLibraryManager = PhotoLibraryManager()
    
    init(
        mediaItems: [MediaItemForNaming], 
        onComplete: @escaping ([MediaItemForNaming]) -> Void = { _ in }, // Made optional
        onCollectionComplete: @escaping ([MediaItemForNaming], String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mediaItems = mediaItems
        self.onComplete = onComplete
        self.onCollectionComplete = onCollectionComplete
        self.onCancel = onCancel
        self._workingItems = State(initialValue: mediaItems)
        self._currentName = State(initialValue: mediaItems.first?.customName ?? "")
        self._collectionName = State(initialValue: "My Photo Collection")
        
        // Debug: Print the number of items we're starting with
        print("IndividualMediaNamingView initialized with \(mediaItems.count) items")
        for (index, item) in mediaItems.enumerated() {
            print("Item \(index): \(item.customName), isVideo: \(item.isVideo)")
        }
    }
    
    private var currentItem: MediaItemForNaming? {
        guard currentIndex < workingItems.count else { return nil }
        return workingItems[currentIndex]
    }
    
    private var progressText: String {
        if workingItems.isEmpty { return "0 of 0" }
        let clampedIndex = min(currentIndex, max(workingItems.count - 1, 0))
        return "\(clampedIndex + 1) of \(workingItems.count)"
    }
    
    private var canProceedToNext: Bool {
        !currentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                Divider()
                
                // Main content
                if workingItems.isEmpty {
                    // Show error state instead of completion
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("No Media Items")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("There were no media items to name. Please go back and select some photos or videos.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Go Back") {
                            onCancel()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if showingCollectionNaming {
                    // NEW: Collection naming view
                    collectionNamingView
                } else if let item = currentItem {
                    mainContentView(for: item)
                } else {
                    // Individual naming complete, show collection naming
                    VStack(spacing: 24) {
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        VStack(spacing: 8) {
                            Text("Great Job!")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("You've named all your media items. Now let's give your collection a name.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Button("Name Collection") {
                            showingCollectionNaming = true
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(25)
                        
                        Spacer()
                    }
                }
                
                Divider()
                
                // Bottom controls - only show if we have items and not in collection naming
                if !workingItems.isEmpty && !showingCollectionNaming {
                    bottomControlsView
                }
            }
        }
        .onAppear {
            print("IndividualMediaNamingView appeared with \(workingItems.count) working items")
            if let firstItem = workingItems.first {
                currentName = firstItem.customName
                loadCurrentItem()
            }
        }
    }

    // NEW: Collection naming view
    private var collectionNamingView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Collection icon and title
                VStack(spacing: 16) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 8) {
                        Text("Name Your Collection")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Give your collection of \(workingItems.filter { !$0.isSkipped }.count) items a memorable name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Preview of named items
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Items:")
                        .font(.headline)
                    
                    ForEach(workingItems.filter { !$0.isSkipped }, id: \.id) { item in
                        HStack {
                            Image(systemName: item.mediaTypeIcon)
                                .foregroundColor(item.isVideo ? .blue : .green)
                            Text(item.customName)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                
                // Collection naming
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Collection Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(collectionName.count)/50")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    TextField("Enter collection name...", text: $collectionName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit {
                            saveCollection()
                        }
                        .onChange(of: collectionName) { _, newValue in
                            if newValue.count > 50 {
                                collectionName = String(newValue.prefix(50))
                            }
                        }
                }
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Back") {
                        showingCollectionNaming = false
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(25)
                    
                    Spacer()
                    
                    Button("Create Collection") {
                        saveCollection()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(collectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.green)
                    .cornerRadius(25)
                    .disabled(collectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                Spacer(minLength: 100)
            }
            .padding()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(.red)
                
                Spacer()
                
                Text("Name Your Media")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(progressText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            
            // Progress bar
            ProgressView(value: Double(currentIndex), total: Double(workingItems.count))
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .padding()
        .padding(.top, 10)
    }
    
    private func mainContentView(for item: MediaItemForNaming) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Media preview
                mediaPreviewView(for: item)
                
                // Naming section
                namingSection(for: item)
                
                Spacer(minLength: 100) // Space for bottom controls
            }
            .padding()
        }
    }
    
    private func mediaPreviewView(for item: MediaItemForNaming) -> some View {
        VStack(spacing: 16) {
            // Media type indicator
            HStack {
                Image(systemName: item.mediaTypeIcon)
                    .foregroundColor(item.isVideo ? .blue : .green)
                Text(item.isVideo ? "Video" : "Photo")
                    .font(.headline)
                    .foregroundColor(item.isVideo ? .blue : .green)
                Spacer()
            }
            
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .frame(height: 200)
                
                if isLoadingThumbnail {
                    ProgressView()
                        .scaleEffect(1.2)
                } else if let image = thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .cornerRadius(16)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: item.isVideo ? "video" : "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Loading preview...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Play icon for videos
                if item.isVideo && thumbnailImage != nil {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
            }
            
            // Current name display - NEW: Elegant subdued style
            if !item.customName.isEmpty {
                VStack(spacing: 4) {
                    Text("Current name:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    Text(item.customName)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                                )
                        )
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 4)
            }
        }
    }
    
    private func namingSection(for item: MediaItemForNaming) -> some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Give this \(item.isVideo ? "video" : "photo") a name")
                    .font(.headline)
                
                Text("Choose a name that will help you remember what this \(item.isVideo ? "video" : "photo") is about.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(currentName.count)/50")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Enhanced TextField with better styling
                TextField("Enter a name...", text: $currentName)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .padding(.vertical, 4) // Add some padding
                    .background(Color(.systemBackground)) // Ensure background is visible
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(currentName.isEmpty ? Color.red.opacity(0.3) : Color.blue.opacity(0.3), lineWidth: 1)
                    )
                    .onSubmit {
                        if canProceedToNext {
                            saveCurrentAndProceed()
                        }
                    }
                    .onChange(of: currentName) { _, newValue in
                        // Limit to 50 characters
                        if newValue.count > 50 {
                            currentName = String(newValue.prefix(50))
                        }
                    }
                
                // Helper text if field is empty
                if currentName.isEmpty {
                    Text("Please enter a name to continue")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.7))
                }
            }
            
            // Suggested names
            if !currentName.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick suggestions:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestedNames(for: item), id: \.self) { suggestion in
                                Button(suggestion) {
                                    currentName = suggestion
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text("All Done!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("You've named all your media items. They will be saved to your collection.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
    }
    
    private var bottomControlsView: some View {
        HStack(spacing: 16) {
            if currentItem != nil {
                Button("Skip") {
                    skipCurrentAndProceed()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(25)

                Spacer()

                Button(currentIndex == workingItems.count - 1 ? "Next: Name Collection" : "Next") {
                    saveCurrentAndProceed()
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(canProceedToNext ? Color.blue : Color.gray)
                .cornerRadius(25)
                .disabled(!canProceedToNext)
            } else {
            }
        }
        .padding()
        .padding(.bottom, 10)
    }
    
    private func suggestedNames(for item: MediaItemForNaming) -> [String] {
        let baseWords = currentName.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)).filter { !$0.isEmpty }
        let firstWord = baseWords.first ?? (item.isVideo ? "video" : "photo")
        
        var suggestions: [String] = []
        
        if item.isVideo {
            suggestions = [
                "My \(firstWord.capitalized) Video",
                "\(firstWord.capitalized) Clip",
                "Fun \(firstWord.capitalized)",
                "\(firstWord.capitalized) Time"
            ]
        } else {
            suggestions = [
                "My \(firstWord.capitalized) Photo",
                "\(firstWord.capitalized) Picture",
                "Beautiful \(firstWord.capitalized)",
                "\(firstWord.capitalized) Memory"
            ]
        }
        
        return suggestions.filter { $0 != currentName && $0.count <= 50 }
    }
    
    private func saveCurrentAndProceed() {
        guard canProceedToNext, currentIndex < workingItems.count else { return }
        
        // Save current name
        workingItems[currentIndex].customName = currentName.trimmingCharacters(in: .whitespacesAndNewlines)
        workingItems[currentIndex].isSkipped = false
        
        proceedToNext()
    }
    
    private func skipCurrentAndProceed() {
        guard currentIndex < workingItems.count else { return }
        
        // Mark as skipped
        workingItems[currentIndex].isSkipped = true
        
        proceedToNext()
    }
    
    private func proceedToNext() {
        if currentIndex < workingItems.count - 1 {
            currentIndex += 1
            loadCurrentItem()
        } else {
            currentIndex = workingItems.count
            showingCollectionNaming = true
        }
    }

    private func saveCollection() {
        let namedItems = workingItems.filter { !$0.isSkipped && !$0.customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let cleanCollectionName = collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        onCollectionComplete(namedItems, cleanCollectionName)
    }

    // RE-ADD: loadCurrentItem() helper to fix missing symbol error
    private func loadCurrentItem() {
        guard let item = currentItem else { return }

        currentName = item.customName
        thumbnailImage = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Intentionally left empty for focus timing if needed
        }

        Task {
            isLoadingThumbnail = true

            let image = await photoLibraryManager.loadThumbnail(
                for: item.asset,
                targetSize: CGSize(width: 400, height: 400)
            )

            await MainActor.run {
                self.thumbnailImage = image
                self.isLoadingThumbnail = false
            }
        }
    }
    
    static func createFromAssets(_ assets: [PHAsset]) -> [MediaItemForNaming] {
        print("createFromAssets called with \(assets.count) assets")
        
        // Sort assets by creation date (newest first)
        let sortedAssets = assets.sorted { (asset1, asset2) -> Bool in
            let date1 = asset1.creationDate ?? Date.distantPast
            let date2 = asset2.creationDate ?? Date.distantPast
            return date1 > date2
        }
        
        var items: [MediaItemForNaming] = []
        
        // Process all assets together (simpler approach)
        for (index, asset) in sortedAssets.enumerated() {
            var item = MediaItemForNaming(asset: asset, customName: "")
            // Use the computed defaultName
            item.customName = item.defaultName
            
            print("Created item \(index): \(item.customName) for \(asset.mediaType == .video ? "video" : "photo")")
            items.append(item)
        }
        
        print("createFromAssets returning \(items.count) items")
        return items
    }
}

#Preview {
    IndividualMediaNamingView(
        mediaItems: [],
        onComplete: { items in
            print("Completed naming: \(items.map { $0.customName })")
        },
        onCollectionComplete: { namedItems, collectionName in
            print("Collection complete: '\(collectionName)' with \(namedItems.count) items")
        },
        onCancel: {
            print("Cancelled naming")
        }
    )
}