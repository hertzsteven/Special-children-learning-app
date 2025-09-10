//
//  MediaItemEditView.swift
//  Special children learning app
//
//  Created by AI Assistant
//

//import SwiftUI
//import Photos
//
////
////  MediaItemEditView.swift
////  Special children learning app
////
////  Enhanced version with proper audio recording interface
////

import SwiftUI
import Photos
import AVFoundation

struct MediaItemEditView: View {
    let mediaItem: SavedMediaItem
    let collectionId: UUID
    let onSave: (SavedMediaItem) -> Void
    let onCancel: () -> Void
    
    @State private var editedName: String
    @State private var hasAudioRecording: Bool
    @State private var showingAudioRecorder = false
    @State private var thumbnail: UIImage?
    
    // Audio recording states
    @StateObject private var voiceMemoModel = VoiceMemoModel()
    @State private var currentAudioURL: URL?
    @State private var hasNewRecording = false
    @State private var showingExistingAudioOptions = false
    @State private var audioPlayer: AVAudioPlayer? // NEW: To hold the audio player instance
    
    // Existing audio files from project (for demo purposes)
    @State private var projectAudioFiles: [String] = [
        "sample_audio_1.m4a",
        "sample_audio_2.m4a",
        "demo_recording.m4a"
    ]
    
    // NEW: Properties to track changes
    private let initialName: String
    private let initialHasAudio: Bool
    
    private var hasChanges: Bool {
        // Check if name has changed
        if editedName != initialName {
            return true
        }
        
        // Check if audio has been added or removed
        if hasAudioRecording != initialHasAudio {
            return true
        }
        
        // Check if a new recording has been made
        if hasNewRecording {
            return true
        }
        
        return false
    }
    
    init(mediaItem: SavedMediaItem, collectionId: UUID, onSave: @escaping (SavedMediaItem) -> Void, onCancel: @escaping () -> Void) {
        self.mediaItem = mediaItem
        self.collectionId = collectionId
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedName = State(initialValue: mediaItem.customName)
        self._hasAudioRecording = State(initialValue: mediaItem.audioRecordingFileName != nil)
        
        // NEW: Store initial state for comparison
        self.initialName = mediaItem.customName
        self.initialHasAudio = mediaItem.audioRecordingFileName != nil
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Thumbnail Preview
                Group {
                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 200)
                            .overlay {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                    }
                }
                
                // Name Editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.headline)
                    
                    TextField("Enter name", text: $editedName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                }
                
                // Audio Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Audio Recording")
                        .font(.headline)
                    
                    if hasAudioRecording || hasNewRecording {
                        audioRecordingInfoView
                    } else {
                        noAudioInfoView
                    }
                    
                    // Audio controls
                    audioControlsView
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.secondary)
                    
                    Button("Save Changes") {
                        saveChanges()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasChanges || editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationTitle("Edit Media Item")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadThumbnail()
            setupCurrentAudioURL()
        }
        .sheet(isPresented: $voiceMemoModel.isPromptPresented) {
            SaveRecordingView(model: voiceMemoModel)
                .onDisappear {
                    if let url = voiceMemoModel.currentFileURL {
                        // User saved the recording
                        currentAudioURL = url
                        hasNewRecording = true
                        hasAudioRecording = true
                    }
                }
        }
        .sheet(isPresented: $showingAudioRecorder) {
            AudioRecordingInterface(voiceMemoModel: voiceMemoModel)
        }
        .actionSheet(isPresented: $showingExistingAudioOptions) {
            ActionSheet(
                title: Text("Audio Options"),
                message: Text("Choose an audio option"),
                buttons: [
                    .default(Text("Use Sample Audio 1")) {
                        useProjectAudio("sample_audio_1.m4a")
                    },
                    .default(Text("Use Sample Audio 2")) {
                        useProjectAudio("sample_audio_2.m4a")
                    },
                    .default(Text("Record New Audio")) {
                        showingAudioRecorder = true
                    },
                    .cancel()
                ]
            )
        }
    }
    
    // MARK: - Audio Info Views
    
    private var audioRecordingInfoView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(hasNewRecording ? "New recording ready" : "Has custom audio")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let url = currentAudioURL {
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if currentAudioURL != nil {
                    Button("Play") {
                        playCurrentAudio()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var noAudioInfoView: some View {
        HStack {
            Image(systemName: "mic.slash")
                .foregroundColor(.gray)
            Text("No custom audio")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var audioControlsView: some View {
        VStack(spacing: 12) {
            // Record/Replace button
            if voiceMemoModel.isRecording {
                recordingActiveView
            } else {
                recordingInactiveView
            }
            
            // Remove audio button (if has audio)
//            if hasAudioRecording {
//                Button("Remove Audio") {
//                    removeAudio()
//                }
//                .buttonStyle(.bordered)
//                .foregroundColor(.red)
//            }
        }
    }
    
    private var recordingActiveView: some View {
        VStack(spacing: 8) {
            Button(action: {
                voiceMemoModel.toggleRecord()
            }) {
                HStack {
                    Image(systemName: "stop.circle.fill")
                        .foregroundColor(.red)
                    Text("Stop")
                        .fontWeight(.bold)
                        .padding(.trailing, 6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recording...")
                            .fontWeight(.medium)
                        Text("(\(formatTime(voiceMemoModel.elapsed)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .font(.subheadline)
                .foregroundColor(.red)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.red, lineWidth: 2)
                )
            }
            .disabled(voiceMemoModel.isPromptPresented)
            
            // Recording progress bar
            ProgressView(value: voiceMemoModel.elapsed, total: voiceMemoModel.maxRecordingDuration)
                .progressViewStyle(LinearProgressViewStyle(tint: .red))
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
    }
    
    private var recordingInactiveView: some View {
        HStack(spacing: 12) {
//            Button(hasAudioRecording ? "Replace Audio" : "Add Audio") {
//                // For now, show options instead of recording directly
//                showingExistingAudioOptions = true
//            }
//            .buttonStyle(.bordered)
            
            Button("Record New") {
                voiceMemoModel.toggleRecord()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.orange)
            // Remove audio button (if has audio)
            if hasAudioRecording {
                Button("Remove Audio") {
                    removeAudio()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadThumbnail() {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [mediaItem.assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else { return }
        
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        
        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 400, height: 400),
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                self.thumbnail = image
            }
        }
    }
    
    private func setupCurrentAudioURL() {
        if let audioFileName = mediaItem.audioRecordingFileName {
            currentAudioURL = mediaItem.audioRecordingURL
        }
    }
    
    private func useProjectAudio(_ fileName: String) {
        // For demo purposes, copy from bundle to our audio directory
        if let bundleURL = Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".m4a", with: ""), withExtension: "m4a") {
            currentAudioURL = bundleURL
            hasNewRecording = true
            hasAudioRecording = true
        } else {
            // Simulate using project audio by creating a temporary URL
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            currentAudioURL = tempURL
            hasNewRecording = true
            hasAudioRecording = true
        }
    }
    
    private func playCurrentAudio() {
        guard let url = currentAudioURL else { return }
        
        do {
            // Stop any previous playback
            audioPlayer?.stop()
            
            // Configure the audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            // Create and play the audio
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Error playing audio: \(error.localizedDescription)")
        }
    }
    
    private func removeAudio() {
        hasAudioRecording = false
        hasNewRecording = false
        currentAudioURL = nil
    }
    
    private func saveChanges() {
        let persistence = VideoCollectionPersistence.shared
        
        // Handle audio file saving
        var audioFileName: String?
        
        if hasNewRecording, let audioURL = currentAudioURL {
            // Save the new audio file
            audioFileName = persistence.saveAudioRecording(from: audioURL)
        } else if hasAudioRecording && !hasNewRecording {
            // Keep existing audio
            audioFileName = mediaItem.audioRecordingFileName
        } else {
            // No audio or audio was removed
            audioFileName = nil
            
            // Delete existing audio file if removing
            if let existingFileName = mediaItem.audioRecordingFileName {
                persistence.deleteAudioRecording(fileName: existingFileName)
            }
        }
        
        // Create updated media item
        let updatedItem = SavedMediaItem(
            id: mediaItem.id,
            assetIdentifier: mediaItem.assetIdentifier,
            customName: editedName.trimmingCharacters(in: .whitespacesAndNewlines),
            audioRecordingFileName: audioFileName
        )
        
        // Update in persistence
        persistence.updateMediaItemInCollection(collectionId, updatedMediaItem: updatedItem)
        
        // Call completion
        onSave(updatedItem)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let seconds = Int(timeInterval)
        let milliseconds = Int((timeInterval - Double(seconds)) * 100)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d.%02d", minutes, remainingSeconds, milliseconds)
    }
}

// MARK: - Audio Recording Interface

struct AudioRecordingInterface: View {
    @ObservedObject var voiceMemoModel: VoiceMemoModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Text("Record Audio")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Record a custom audio description for this item")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Recording controls
                VStack(spacing: 20) {
                    // Large record button
                    Button(action: {
                        voiceMemoModel.toggleRecord()
                    }) {
                        ZStack {
                            Circle()
                                .fill(voiceMemoModel.isRecording ? Color.red : Color.orange)
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: voiceMemoModel.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                    }
                    .scaleEffect(voiceMemoModel.isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: voiceMemoModel.isRecording)
                    
                    // Recording status
                    VStack(spacing: 8) {
                        Text(voiceMemoModel.isRecording ? "Recording..." : "Tap to Record")
                            .font(.headline)
                            .foregroundColor(voiceMemoModel.isRecording ? .red : .primary)
                        
                        if voiceMemoModel.isRecording {
                            Text(formatTime(voiceMemoModel.elapsed))
                                .font(.title)
                                .monospacedDigit()
                                .foregroundColor(.red)
                            
                            // Progress bar
                            ProgressView(value: voiceMemoModel.elapsed, total: voiceMemoModel.maxRecordingDuration)
                                .progressViewStyle(LinearProgressViewStyle(tint: .red))
                                .scaleEffect(x: 1, y: 3, anchor: .center)
                                .padding(.horizontal, 20)
                        }
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 20) {
                    Button("Cancel") {
                        voiceMemoModel.discardRecording()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.secondary)
                    
                    if voiceMemoModel.currentFileURL != nil && !voiceMemoModel.isRecording {
                        Button("Use Recording") {
                            voiceMemoModel.saveRecording()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .navigationTitle("Audio Recording")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let seconds = Int(timeInterval)
        let milliseconds = Int((timeInterval - Double(seconds)) * 100)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d.%02d", minutes, remainingSeconds, milliseconds)
    }
}

// MARK: - Preview Provider

struct MediaItemEditView_Previews: PreviewProvider {
    static let sampleItemWithAudio = SavedMediaItem(
        assetIdentifier: "test-id-1",
        customName: "Item With Audio",
        audioRecordingFileName: "sample_audio_1.m4a"
    )
    
    static let sampleItemWithoutAudio = SavedMediaItem(
        assetIdentifier: "test-id-2",
        customName: "Item Without Audio",
        audioRecordingFileName: nil
    )
    
    static var previews: some View {
        // Preview for item with existing audio
        MediaItemEditView(
            mediaItem: sampleItemWithAudio,
            collectionId: UUID(),
            onSave: { _ in print("Saved!") },
            onCancel: { print("Cancelled!") }
        )
        .previewDisplayName("With Existing Audio")
        
        // Preview for item without audio
        MediaItemEditView(
            mediaItem: sampleItemWithoutAudio,
            collectionId: UUID(),
            onSave: { _ in print("Saved!") },
            onCancel: { print("Cancelled!") }
        )
        .previewDisplayName("Without Audio")
    }
}
