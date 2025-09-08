//
//  MediaItemEditView.swift
//  Special children learning app
//
//  Created by AI Assistant
//

import SwiftUI
import Photos

struct MediaItemEditView: View {
    let mediaItem: SavedMediaItem
    let onSave: (SavedMediaItem) -> Void
    let onCancel: () -> Void
    
    @State private var editedName: String
    @State private var showingAudioRecorder = false
    @State private var hasAudioRecording: Bool
    @State private var thumbnail: UIImage?
    
    init(mediaItem: SavedMediaItem, onSave: @escaping (SavedMediaItem) -> Void, onCancel: @escaping () -> Void) {
        self.mediaItem = mediaItem
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedName = State(initialValue: mediaItem.customName)
        self._hasAudioRecording = State(initialValue: mediaItem.audioRecordingFileName != nil)
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
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
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
                    
                    HStack {
                        if hasAudioRecording {
                            HStack {
                                Image(systemName: "mic.fill")
                                    .foregroundColor(.blue)
                                Text("Has custom audio")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack {
                                Image(systemName: "mic.slash")
                                    .foregroundColor(.gray)
                                Text("No custom audio")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(hasAudioRecording ? "Replace Audio" : "Add Audio") {
                            showingAudioRecorder = true
                        }
                        .buttonStyle(.bordered)
                        
                        if hasAudioRecording {
                            Button("Remove Audio") {
                                hasAudioRecording = false
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                    }
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
                    .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationTitle("Edit Media Item")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadThumbnail()
        }
        .sheet(isPresented: $showingAudioRecorder) {
            // TODO: Implement audio recording view
            // For now, just simulate adding audio
            VStack {
                Text("Audio Recording")
                    .font(.title)
                    .padding()
                
                Text("Audio recording feature would go here")
                    .padding()
                
                Button("Simulate Add Audio") {
                    hasAudioRecording = true
                    showingAudioRecorder = false
                }
                .buttonStyle(.borderedProminent)
                
                Button("Cancel") {
                    showingAudioRecorder = false
                }
                .buttonStyle(.bordered)
                .padding(.top)
            }
            .padding()
        }
    }
    
    private func loadThumbnail() {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [mediaItem.assetIdentifier], options: nil)
        
        if let asset = fetchResult.firstObject {
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            
            manager.requestImage(
                for: asset,
                targetSize: CGSize(width: 300, height: 300),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                DispatchQueue.main.async {
                    self.thumbnail = image
                }
            }
        }
    }
    
    private func saveChanges() {
        let cleanName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔄 MediaItemEditView.saveChanges called")
        print("   - Original item ID: \(mediaItem.id)")
        print("   - Original item name: '\(mediaItem.customName)'")
        print("   - Edited name (raw): '\(editedName)'")
        print("   - Clean name: '\(cleanName)'")
        print("   - Has audio recording: \(hasAudioRecording)")
        print("   - Audio file name: \(hasAudioRecording ? mediaItem.audioRecordingFileName : nil)")
        
        let updatedItem = SavedMediaItem(
            id: mediaItem.id,
            assetIdentifier: mediaItem.assetIdentifier,
            customName: cleanName,
            audioRecordingFileName: hasAudioRecording ? mediaItem.audioRecordingFileName : nil
        )
        
        print("   - Created updated item:")
        print("     - ID: \(updatedItem.id)")
        print("     - Asset ID: \(updatedItem.assetIdentifier)")
        print("     - Custom name: '\(updatedItem.customName)'")
        print("     - Audio file: \(updatedItem.audioRecordingFileName ?? "none")")
        print("   - Calling onSave...")
        
        onSave(updatedItem)
        print("   - onSave completed")
    }
}

#Preview {
    MediaItemEditView(
        mediaItem: SavedMediaItem(
            assetIdentifier: "test-id",
            customName: "Test Media",
            audioRecordingFileName: nil
        ),
        onSave: { _ in },
        onCancel: { }
    )
}