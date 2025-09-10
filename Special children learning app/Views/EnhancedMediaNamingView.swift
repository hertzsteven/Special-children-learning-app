//
//  EnhancedMediaNamingView.swift
//  Special children learning app
//
//  Created by AI Assistant on 12/19/24.
//


//  EnhancedMediaNamingView.swift
//  Special children learning app
//
//  Created by AI Assistant on 12/19/24.
//

import SwiftUI
import Photos
import AVFoundation

struct EnhancedMediaNamingView: View {
    let mediaItems: [MediaItemForNaming]
    let onCollectionComplete: ([SavedMediaItem], String) -> Void
    let onCancel: () -> Void
    let skipCollectionNaming: Bool // NEW: Parameter to skip collection naming
    
    @State private var currentIndex = 0
    @State private var workingItems: [MediaItemForNaming]
    @State private var currentName = ""
    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail = false
    @State private var showingCollectionNaming = false
    @State private var collectionName = ""
    
    // Audio recording states
    @StateObject private var voiceMemoModel = VoiceMemoModel()
    @State private var currentAudioURL: URL?
    @State private var hasRecordedAudio = false
    @State private var audioPlayer: AVAudioPlayer? = nil
    
    @StateObject private var photoLibraryManager = PhotoLibraryManager()
    
    init(
        mediaItems: [MediaItemForNaming],
        onCollectionComplete: @escaping ([SavedMediaItem], String) -> Void,
        onCancel: @escaping () -> Void,
        skipCollectionNaming: Bool = true // NEW: Default to false for backward compatibility
    ) {
        self.mediaItems = mediaItems
        self.onCollectionComplete = onCollectionComplete
        self.onCancel = onCancel
        self.skipCollectionNaming = skipCollectionNaming
        self._workingItems = State(initialValue: mediaItems)
        self._currentName = State(initialValue: mediaItems.first?.customName ?? "")
        self._collectionName = State(initialValue: "My Photo Collection")
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
                    emptyStateView
                } else if showingCollectionNaming {
                    collectionNamingView
                } else if let item = currentItem {
                    mainContentView(for: item)
                } else {
                    // MODIFIED: Check if we should skip collection naming
                    if skipCollectionNaming {
                        completionViewWithDirectSave
                    } else {
                        completionTransitionView
                    }
                }
                
                Divider()
                
                // Bottom controls
                if !workingItems.isEmpty && !showingCollectionNaming {
                    bottomControlsView
                }
            }
        }
        .onAppear {
            loadCurrentItem()
        }
        .sheet(isPresented: $voiceMemoModel.isPromptPresented) {
            SaveRecordingView(model: voiceMemoModel)
                .onDisappear {
                    if let url = voiceMemoModel.currentFileURL {
                        // User saved the recording
                        currentAudioURL = url
                        hasRecordedAudio = true
                    }
                }
        }
    }
    
    // NEW: Completion view that directly saves without collection naming
    private var completionViewWithDirectSave: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text("Items Added!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Your \(workingItems.filter { !$0.isSkipped }.count) items have been named and will be added to the collection.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
//            Button("Add to Collectionxxxx") {
//                saveDirectlyToCollection()
//            }
//            .font(.headline)
//            .foregroundColor(.white)
//            .padding(.horizontal, 32)
//            .padding(.vertical, 12)
//            .background(Color.green)
//            .cornerRadius(25)
            
            Spacer()
        }
        .onAppear {
            // Auto-save after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                saveDirectlyToCollection()
            }
        }
    }
    
    // NEW: Save directly without collection naming
    private func saveDirectlyToCollection() {
        let namedItems = workingItems.filter { !$0.isSkipped && !$0.customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        // Convert to SavedMediaItem with audio recordings
        var savedMediaItems: [SavedMediaItem] = []
        let persistence = VideoCollectionPersistence.shared
        
        for item in namedItems {
            var audioFileName: String?
            
            // Save audio file if we have one
            if let audioURL = item.audioURL {
                audioFileName = persistence.saveAudioRecording(from: audioURL)
            }
            
            let savedItem = SavedMediaItem(
                assetIdentifier: item.asset.localIdentifier,
                customName: item.customName,
                audioRecordingFileName: audioFileName
            )
            
            savedMediaItems.append(savedItem)
        }
        
        // Use empty string for collection name since we're adding to existing
        onCollectionComplete(savedMediaItems, "")
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(.red)
                
                Spacer()
                
                Text(skipCollectionNaming ? "Name Media Items" : "Name Your Media")
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
    
    private var emptyStateView: some View {
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
    }
    
    private var completionTransitionView: some View {
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
    
    private func mainContentView(for item: MediaItemForNaming) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Media preview
                mediaPreviewView(for: item)
                
                // Naming section
                namingSection(for: item)
                
                // Audio recording section
                audioRecordingSection()
                
                Spacer(minLength: 100)
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
                
                TextField("Enter a name...", text: $currentName)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .onSubmit {
                        if canProceedToNext {
                            saveCurrentAndProceed()
                        }
                    }
                    .onChange(of: currentName) { _, newValue in
                        if newValue.count > 50 {
                            currentName = String(newValue.prefix(50))
                        }
                    }
                
                if currentName.isEmpty {
                    Text("Please enter a name to continue")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.7))
                }
            }
        }
    }
    
    private func audioRecordingSection() -> some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "mic.circle.fill")
                        .foregroundColor(.orange)
                    Text("Audio Description (Optional)")
                        .font(.headline)
                    Spacer()
                }
                
                Text("Record an audio description or note for this \(currentItem?.isVideo == true ? "video" : "photo").")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                if hasRecordedAudio {
                    // Show recorded audio info
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Audio Recorded")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            Button("Play Recording") {
                                if let url = currentAudioURL {
                                    playAudioFile(at: url)
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            
                            Button("Record New") {
                                hasRecordedAudio = false
                                currentAudioURL = nil
                                voiceMemoModel.toggleRecord()
                            }
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    // Record audio button
                    Button(action: {
                        voiceMemoModel.toggleRecord()
                    }) {
                        HStack {
                            Image(systemName: voiceMemoModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .foregroundColor(voiceMemoModel.isRecording ? .red : .orange)
                            
                            Text(voiceMemoModel.isRecording ? "Stop - Recording..." : "Record Audio")
                                .fontWeight(.medium)
                            
                            if voiceMemoModel.isRecording {
                                Text("(\(formatTime(voiceMemoModel.elapsed)))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(voiceMemoModel.isRecording ? .red : .orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(voiceMemoModel.isRecording ? Color.red : Color.orange, lineWidth: 2)
                        )
                    }
                    .disabled(voiceMemoModel.isPromptPresented)
                }
            }
        }
        .padding(.top, 8)
    }
    
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

                // MODIFIED: Different button text when skipping collection naming
                let buttonText = if skipCollectionNaming {
                    currentIndex == workingItems.count - 1 ? "Add to Collection" : "Next"
                } else {
                    currentIndex == workingItems.count - 1 ? "Next: Name Collection" : "Next"
                }

                Button(buttonText) {
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
            }
        }
        .padding()
        .padding(.bottom, 10)
    }
    
    // MARK: - Helper Functions
    
    private func loadCurrentItem() {
        guard let item = currentItem else { return }

        currentName = item.customName
        thumbnailImage = nil
        hasRecordedAudio = false
        currentAudioURL = nil

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
    
    private func saveCurrentAndProceed() {
        guard canProceedToNext, currentIndex < workingItems.count else { return }
        
        // Save current name
        workingItems[currentIndex].customName = currentName.trimmingCharacters(in: .whitespacesAndNewlines)
        workingItems[currentIndex].isSkipped = false
        
        // Store audio URL if we have one
        if hasRecordedAudio {
            workingItems[currentIndex].audioURL = currentAudioURL
        }
        
        proceedToNext()
    }
    
    private func skipCurrentAndProceed() {
        guard currentIndex < workingItems.count else { return }
        
        workingItems[currentIndex].isSkipped = true
        proceedToNext()
    }
    
    private func proceedToNext() {
        if currentIndex < workingItems.count - 1 {
            currentIndex += 1
            loadCurrentItem()
        } else {
            currentIndex = workingItems.count
            // MODIFIED: Check if we should skip collection naming
            if skipCollectionNaming {
                // Don't show collection naming, just finish
                // The completion view will handle saving
            } else {
                showingCollectionNaming = true
            }
        }
    }

    private func saveCollection() {
        let namedItems = workingItems.filter { !$0.isSkipped && !$0.customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let cleanCollectionName = collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Convert to SavedMediaItem with audio recordings
        var savedMediaItems: [SavedMediaItem] = []
        let persistence = VideoCollectionPersistence.shared
        
        for item in namedItems {
            var audioFileName: String?
            
            // Save audio file if we have one
            if let audioURL = item.audioURL {
                audioFileName = persistence.saveAudioRecording(from: audioURL)
            }
            
            let savedItem = SavedMediaItem(
                assetIdentifier: item.asset.localIdentifier,
                customName: item.customName,
                audioRecordingFileName: audioFileName
            )
            
            savedMediaItems.append(savedItem)
        }
        
        onCollectionComplete(savedMediaItems, cleanCollectionName)
    }
    
    private func playAudioFile(at url: URL) {
        // Keep a strong reference to the player so it isn't deallocated immediately
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true, options: [])
            
            // Ensure the file exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("Audio file does not exist at path: \(url.path)")
                return
            }
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Error playing audio: \(error)")
        }
    }
    
    private func formatTime(_ t: TimeInterval) -> String {
        let s = Int(t)
        let ms = Int((t - Double(s)) * 100)
        let m = s / 60
        let r = s % 60
        return String(format: "%02d:%02d.%02d", m, r, ms)
    }
}

// MARK: - Static Helper for Creating MediaItemForNaming

extension MediaItemForNaming {
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

//
//struct EnhancedMediaNamingView: View {
//    let mediaItems: [MediaItemForNaming]
//    let onCollectionComplete: ([SavedMediaItem], String) -> Void
//    let onCancel: () -> Void
//    
//    @State private var currentIndex = 0
//    @State private var workingItems: [MediaItemForNaming]
//    @State private var currentName = ""
//    @State private var thumbnailImage: UIImage?
//    @State private var isLoadingThumbnail = false
//    @State private var showingCollectionNaming = false
//    @State private var collectionName = ""
//    
//    // Audio recording states
//    @StateObject private var voiceMemoModel = VoiceMemoModel()
//    @State private var currentAudioURL: URL?
//    @State private var hasRecordedAudio = false
//    
//    @StateObject private var photoLibraryManager = PhotoLibraryManager()
//    
//    init(
//        mediaItems: [MediaItemForNaming],
//        onCollectionComplete: @escaping ([SavedMediaItem], String) -> Void,
//        onCancel: @escaping () -> Void
//    ) {
//        self.mediaItems = mediaItems
//        self.onCollectionComplete = onCollectionComplete
//        self.onCancel = onCancel
//        self._workingItems = State(initialValue: mediaItems)
//        self._currentName = State(initialValue: mediaItems.first?.customName ?? "")
//        self._collectionName = State(initialValue: "My Photo Collection")
//    }
//    
//    private var currentItem: MediaItemForNaming? {
//        guard currentIndex < workingItems.count else { return nil }
//        return workingItems[currentIndex]
//    }
//    
//    private var progressText: String {
//        if workingItems.isEmpty { return "0 of 0" }
//        let clampedIndex = min(currentIndex, max(workingItems.count - 1, 0))
//        return "\(clampedIndex + 1) of \(workingItems.count)"
//    }
//    
//    private var canProceedToNext: Bool {
//        !currentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
//    }
//    
//    var body: some View {
//        ZStack {
//            Color(.systemBackground)
//                .ignoresSafeArea(.all)
//            
//            VStack(spacing: 0) {
//                // Header
//                headerView
//                
//                Divider()
//                
//                // Main content
//                if workingItems.isEmpty {
//                    emptyStateView
//                } else if showingCollectionNaming {
//                    collectionNamingView
//                } else if let item = currentItem {
//                    mainContentView(for: item)
//                } else {
//                    completionTransitionView
//                }
//                
//                Divider()
//                
//                // Bottom controls
//                if !workingItems.isEmpty && !showingCollectionNaming {
//                    bottomControlsView
//                }
//            }
//        }
//        .onAppear {
//            loadCurrentItem()
//        }
//        .sheet(isPresented: $voiceMemoModel.isPromptPresented) {
//            SaveRecordingView(model: voiceMemoModel)
//                .onDisappear {
//                    if let url = voiceMemoModel.currentFileURL {
//                        // User saved the recording
//                        currentAudioURL = url
//                        hasRecordedAudio = true
//                    }
//                }
//        }
//    }
//    
//    private var headerView: some View {
//        VStack(spacing: 12) {
//            HStack {
//                Button("Cancel") {
//                    onCancel()
//                }
//                .foregroundColor(.red)
//                
//                Spacer()
//                
//                Text("Name Your Media")
//                    .font(.headline)
//                    .fontWeight(.semibold)
//                
//                Spacer()
//                
//                Text(progressText)
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 6)
//                    .background(Color(.systemGray6))
//                    .cornerRadius(12)
//            }
//            
//            // Progress bar
//            ProgressView(value: Double(currentIndex), total: Double(workingItems.count))
//                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
//        }
//        .padding()
//        .padding(.top, 10)
//    }
//    
//    private var emptyStateView: some View {
//        VStack(spacing: 20) {
//            Image(systemName: "exclamationmark.triangle")
//                .font(.system(size: 60))
//                .foregroundColor(.orange)
//            
//            Text("No Media Items")
//                .font(.title2)
//                .fontWeight(.bold)
//            
//            Text("There were no media items to name. Please go back and select some photos or videos.")
//                .font(.subheadline)
//                .foregroundColor(.secondary)
//                .multilineTextAlignment(.center)
//                .padding(.horizontal)
//            
//            Button("Go Back") {
//                onCancel()
//            }
//            .padding()
//            .background(Color.blue)
//            .foregroundColor(.white)
//            .cornerRadius(10)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//    
//    private var completionTransitionView: some View {
//        VStack(spacing: 24) {
//            Spacer()
//            
//            Image(systemName: "checkmark.circle.fill")
//                .font(.system(size: 60))
//                .foregroundColor(.green)
//            
//            VStack(spacing: 8) {
//                Text("Great Job!")
//                    .font(.title2)
//                    .fontWeight(.bold)
//                
//                Text("You've named all your media items. Now let's give your collection a name.")
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//                    .multilineTextAlignment(.center)
//                    .padding(.horizontal)
//            }
//            
//            Button("Name Collection") {
//                showingCollectionNaming = true
//            }
//            .font(.headline)
//            .foregroundColor(.white)
//            .padding(.horizontal, 32)
//            .padding(.vertical, 12)
//            .background(Color.blue)
//            .cornerRadius(25)
//            
//            Spacer()
//        }
//    }
//    
//    private func mainContentView(for item: MediaItemForNaming) -> some View {
//        ScrollView {
//            VStack(spacing: 24) {
//                // Media preview
//                mediaPreviewView(for: item)
//                
//                // Naming section
//                namingSection(for: item)
//                
//                // Audio recording section
//                audioRecordingSection()
//                
//                Spacer(minLength: 100)
//            }
//            .padding()
//        }
//    }
//    
//    private func mediaPreviewView(for item: MediaItemForNaming) -> some View {
//        VStack(spacing: 16) {
//            // Media type indicator
//            HStack {
//                Image(systemName: item.mediaTypeIcon)
//                    .foregroundColor(item.isVideo ? .blue : .green)
//                Text(item.isVideo ? "Video" : "Photo")
//                    .font(.headline)
//                    .foregroundColor(item.isVideo ? .blue : .green)
//                Spacer()
//            }
//            
//            // Thumbnail
//            ZStack {
//                RoundedRectangle(cornerRadius: 16)
//                    .fill(Color(.systemGray6))
//                    .frame(height: 200)
//                
//                if isLoadingThumbnail {
//                    ProgressView()
//                        .scaleEffect(1.2)
//                } else if let image = thumbnailImage {
//                    Image(uiImage: image)
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .frame(maxHeight: 200)
//                        .cornerRadius(16)
//                } else {
//                    VStack(spacing: 12) {
//                        Image(systemName: item.isVideo ? "video" : "photo")
//                            .font(.system(size: 40))
//                            .foregroundColor(.secondary)
//                        Text("Loading preview...")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
//                }
//                
//                // Play icon for videos
//                if item.isVideo && thumbnailImage != nil {
//                    Image(systemName: "play.circle.fill")
//                        .font(.system(size: 50))
//                        .foregroundColor(.white)
//                        .background(Color.black.opacity(0.3))
//                        .clipShape(Circle())
//                }
//            }
//        }
//    }
//    
//    private func namingSection(for item: MediaItemForNaming) -> some View {
//        VStack(spacing: 16) {
//            VStack(alignment: .leading, spacing: 8) {
//                Text("Give this \(item.isVideo ? "video" : "photo") a name")
//                    .font(.headline)
//                
//                Text("Choose a name that will help you remember what this \(item.isVideo ? "video" : "photo") is about.")
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//            }
//            
//            VStack(alignment: .leading, spacing: 8) {
//                HStack {
//                    Text("Name")
//                        .font(.subheadline)
//                        .fontWeight(.medium)
//                    Spacer()
//                    Text("\(currentName.count)/50")
//                        .font(.caption2)
//                        .foregroundColor(.secondary)
//                }
//                
//                TextField("Enter a name...", text: $currentName)
//                    .textFieldStyle(.roundedBorder)
//                    .font(.body)
//                    .textInputAutocapitalization(.words)
//                    .submitLabel(.next)
//                    .onSubmit {
//                        if canProceedToNext {
//                            saveCurrentAndProceed()
//                        }
//                    }
//                    .onChange(of: currentName) { _, newValue in
//                        if newValue.count > 50 {
//                            currentName = String(newValue.prefix(50))
//                        }
//                    }
//                
//                if currentName.isEmpty {
//                    Text("Please enter a name to continue")
//                        .font(.caption)
//                        .foregroundColor(.red.opacity(0.7))
//                }
//            }
//        }
//    }
//    
//    private func audioRecordingSection() -> some View {
//        VStack(spacing: 16) {
//            VStack(alignment: .leading, spacing: 8) {
//                HStack {
//                    Image(systemName: "mic.circle.fill")
//                        .foregroundColor(.orange)
//                    Text("Audio Description (Optional)")
//                        .font(.headline)
//                    Spacer()
//                }
//                
//                Text("Record an audio description or note for this \(currentItem?.isVideo == true ? "video" : "photo").")
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//            }
//            
//            VStack(spacing: 12) {
//                if hasRecordedAudio {
//                    // Show recorded audio info
//                    VStack(spacing: 8) {
//                        HStack {
//                            Image(systemName: "checkmark.circle.fill")
//                                .foregroundColor(.green)
//                            Text("Audio Recorded")
//                                .font(.subheadline)
//                                .fontWeight(.medium)
//                            Spacer()
//                        }
//                        
//                        HStack(spacing: 12) {
//                            Button("Play Recording") {
//                                if let url = currentAudioURL {
//                                    playAudioFile(at: url)
//                                }
//                            }
//                            .font(.caption)
//                            .foregroundColor(.blue)
//                            .padding(.horizontal, 12)
//                            .padding(.vertical, 6)
//                            .background(Color.blue.opacity(0.1))
//                            .cornerRadius(12)
//                            
//                            Button("Record New") {
//                                hasRecordedAudio = false
//                                currentAudioURL = nil
//                                voiceMemoModel.toggleRecord()
//                            }
//                            .font(.caption)
//                            .foregroundColor(.orange)
//                            .padding(.horizontal, 12)
//                            .padding(.vertical, 6)
//                            .background(Color.orange.opacity(0.1))
//                            .cornerRadius(12)
//                            
//                            Spacer()
//                        }
//                    }
//                    .padding()
//                    .background(Color.green.opacity(0.1))
//                    .cornerRadius(12)
//                } else {
//                    // Record audio button
//                    Button(action: {
//                        voiceMemoModel.toggleRecord()
//                    }) {
//                        HStack {
//                            Image(systemName: voiceMemoModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
//                                .foregroundColor(voiceMemoModel.isRecording ? .red : .orange)
//                            
//                            Text(voiceMemoModel.isRecording ? "Recording..." : "Record Audio")
//                                .fontWeight(.medium)
//                            
//                            if voiceMemoModel.isRecording {
//                                Text("(\(formatTime(voiceMemoModel.elapsed)))")
//                                    .font(.caption)
//                                    .foregroundColor(.secondary)
//                            }
//                        }
//                        .font(.subheadline)
//                        .foregroundColor(voiceMemoModel.isRecording ? .red : .orange)
//                        .padding(.horizontal, 16)
//                        .padding(.vertical, 10)
//                        .background(
//                            RoundedRectangle(cornerRadius: 20)
//                                .stroke(voiceMemoModel.isRecording ? Color.red : Color.orange, lineWidth: 2)
//                        )
//                    }
//                    .disabled(voiceMemoModel.isPromptPresented)
//                }
//            }
//        }
//        .padding(.top, 8)
//    }
//    
//    private var collectionNamingView: some View {
//        ScrollView {
//            VStack(spacing: 24) {
//                // Collection icon and title
//                VStack(spacing: 16) {
//                    Image(systemName: "rectangle.stack.fill")
//                        .font(.system(size: 60))
//                        .foregroundColor(.blue)
//                    
//                    VStack(spacing: 8) {
//                        Text("Name Your Collection")
//                            .font(.title2)
//                            .fontWeight(.bold)
//                        
//                        Text("Give your collection of \(workingItems.filter { !$0.isSkipped }.count) items a memorable name")
//                            .font(.subheadline)
//                            .foregroundColor(.secondary)
//                            .multilineTextAlignment(.center)
//                    }
//                }
//                
//                // Collection naming
//                VStack(alignment: .leading, spacing: 8) {
//                    HStack {
//                        Text("Collection Name")
//                            .font(.subheadline)
//                            .fontWeight(.medium)
//                        Spacer()
//                        Text("\(collectionName.count)/50")
//                            .font(.caption2)
//                            .foregroundColor(.secondary)
//                    }
//                    
//                    TextField("Enter collection name...", text: $collectionName)
//                        .textFieldStyle(RoundedBorderTextFieldStyle())
//                        .textInputAutocapitalization(.words)
//                        .submitLabel(.done)
//                        .onSubmit {
//                            saveCollection()
//                        }
//                        .onChange(of: collectionName) { _, newValue in
//                            if newValue.count > 50 {
//                                collectionName = String(newValue.prefix(50))
//                            }
//                        }
//                }
//                
//                // Action buttons
//                HStack(spacing: 16) {
//                    Button("Back") {
//                        showingCollectionNaming = false
//                    }
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//                    .padding(.horizontal, 20)
//                    .padding(.vertical, 12)
//                    .background(Color(.systemGray6))
//                    .cornerRadius(25)
//                    
//                    Spacer()
//                    
//                    Button("Create Collection") {
//                        saveCollection()
//                    }
//                    .font(.subheadline)
//                    .fontWeight(.semibold)
//                    .foregroundColor(.white)
//                    .padding(.horizontal, 32)
//                    .padding(.vertical, 12)
//                    .background(collectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.green)
//                    .cornerRadius(25)
//                    .disabled(collectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
//                }
//                
//                Spacer(minLength: 100)
//            }
//            .padding()
//        }
//    }
//    
//    private var bottomControlsView: some View {
//        HStack(spacing: 16) {
//            if currentItem != nil {
//                Button("Skip") {
//                    skipCurrentAndProceed()
//                }
//                .font(.subheadline)
//                .foregroundColor(.secondary)
//                .padding(.horizontal, 20)
//                .padding(.vertical, 12)
//                .background(Color(.systemGray6))
//                .cornerRadius(25)
//
//                Spacer()
//
//                Button(currentIndex == workingItems.count - 1 ? "Next: Name Collection" : "Next") {
//                    saveCurrentAndProceed()
//                }
//                .font(.subheadline)
//                .fontWeight(.semibold)
//                .foregroundColor(.white)
//                .padding(.horizontal, 24)
//                .padding(.vertical, 12)
//                .background(canProceedToNext ? Color.blue : Color.gray)
//                .cornerRadius(25)
//                .disabled(!canProceedToNext)
//            }
//        }
//        .padding()
//        .padding(.bottom, 10)
//    }
//    
//    // MARK: - Helper Functions
//    
//    private func loadCurrentItem() {
//        guard let item = currentItem else { return }
//
//        currentName = item.customName
//        thumbnailImage = nil
//        hasRecordedAudio = false
//        currentAudioURL = nil
//
//        Task {
//            isLoadingThumbnail = true
//
//            let image = await photoLibraryManager.loadThumbnail(
//                for: item.asset,
//                targetSize: CGSize(width: 400, height: 400)
//            )
//
//            await MainActor.run {
//                self.thumbnailImage = image
//                self.isLoadingThumbnail = false
//            }
//        }
//    }
//    
//    private func saveCurrentAndProceed() {
//        guard canProceedToNext, currentIndex < workingItems.count else { return }
//        
//        // Save current name
//        workingItems[currentIndex].customName = currentName.trimmingCharacters(in: .whitespacesAndNewlines)
//        workingItems[currentIndex].isSkipped = false
//        
//        // Store audio URL if we have one
//        if hasRecordedAudio {
//            workingItems[currentIndex].audioURL = currentAudioURL
//        }
//        
//        proceedToNext()
//    }
//    
//    private func skipCurrentAndProceed() {
//        guard currentIndex < workingItems.count else { return }
//        
//        workingItems[currentIndex].isSkipped = true
//        proceedToNext()
//    }
//    
//    private func proceedToNext() {
//        if currentIndex < workingItems.count - 1 {
//            currentIndex += 1
//            loadCurrentItem()
//        } else {
//            currentIndex = workingItems.count
//            showingCollectionNaming = true
//        }
//    }
//
//    private func saveCollection() {
//        let namedItems = workingItems.filter { !$0.isSkipped && !$0.customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
//        let cleanCollectionName = collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
//        
//        // Convert to SavedMediaItem with audio recordings
//        var savedMediaItems: [SavedMediaItem] = []
//        let persistence = VideoCollectionPersistence.shared
//        
//        for item in namedItems {
//            var audioFileName: String?
//            
//            // Save audio file if we have one
//            if let audioURL = item.audioURL {
//                audioFileName = persistence.saveAudioRecording(from: audioURL)
//            }
//            
//            let savedItem = SavedMediaItem(
//                assetIdentifier: item.asset.localIdentifier,
//                customName: item.customName,
//                audioRecordingFileName: audioFileName
//            )
//            
//            savedMediaItems.append(savedItem)
//        }
//        
//        onCollectionComplete(savedMediaItems, cleanCollectionName)
//    }
//    
//    private func playAudioFile(at url: URL) {
//        // Simple audio playback - you could enhance this with your VoiceMemoModel
//        do {
//            let audioSession = AVAudioSession.sharedInstance()
//            try audioSession.setCategory(.playback, mode: .default)
//            try audioSession.setActive(true)
//            
//            let player = try AVAudioPlayer(contentsOf: url)
//            player.play()
//        } catch {
//            print("Error playing audio: \(error)")
//        }
//    }
//    
//    private func formatTime(_ t: TimeInterval) -> String {
//        let s = Int(t)
//        let ms = Int((t - Double(s)) * 100)
//        let m = s / 60
//        let r = s % 60
//        return String(format: "%02d:%02d.%02d", m, r, ms)
//    }
//}
//
//// MARK: - Static Helper for Creating MediaItemForNaming
//
//extension MediaItemForNaming {
//    static func createFromAssets(_ assets: [PHAsset]) -> [MediaItemForNaming] {
//        print("createFromAssets called with \(assets.count) assets")
//        
//        // Sort assets by creation date (newest first)
//        let sortedAssets = assets.sorted { (asset1, asset2) -> Bool in
//            let date1 = asset1.creationDate ?? Date.distantPast
//            let date2 = asset2.creationDate ?? Date.distantPast
//            return date1 > date2
//        }
//        
//        var items: [MediaItemForNaming] = []
//        
//        // Process all assets together (simpler approach)
//        for (index, asset) in sortedAssets.enumerated() {
//            var item = MediaItemForNaming(asset: asset, customName: "")
//            // Use the computed defaultName
//            item.customName = item.defaultName
//            
//            print("Created item \(index): \(item.customName) for \(asset.mediaType == .video ? "video" : "photo")")
//            items.append(item)
//        }
//        
//        print("createFromAssets returning \(items.count) items")
//        return items
//    }
//}
