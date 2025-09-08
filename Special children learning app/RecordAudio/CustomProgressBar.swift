//
//  CustomProgressBar.swift
//  Special children learning app
//
//  Created by Steven Hertz on 9/7/25.
//

import SwiftUI
import AVFoundation

struct CustomProgressBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background of the progress bar
                Capsule()
                    .fill(Color.gray.opacity(0.25))
                
                // Foreground (the actual progress)
                Capsule()
                    .fill(color)
                    // Animate the width change for a smooth progress update
                    .frame(width: geometry.size.width * progress)
                    .animation(.linear(duration: 0.1), value: progress)
            }
        }
    }
}

//
//  SaveRecordingView.swift
//  Special children learning app
//
//  Enhanced version for edit mode with better playback controls
//


struct SaveRecordingView: View {
    @ObservedObject var model: VoiceMemoModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingPlaybackControls = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    VStack(spacing: 8) {
                        Text("Recording Complete")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if let url = model.currentFileURL {
                            Text(url.lastPathComponent)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Text("Duration: \(formatTime(model.elapsed))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Playback section
                VStack(spacing: 16) {
                    // Playback controls
                    HStack(spacing: 20) {
                        Button(action: {
                            model.togglePlayback()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: model.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.title2)
                                Text(model.isPlaying ? "Pause" : "Play Recording")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(25)
                        }
                        
                        Spacer()
                        
                        if model.isPlaying {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Playing...")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text("\(formatTime(model.playbackProgress * model.playbackDuration))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Playback progress bar
                    if model.playbackDuration > 0 && (model.isPlaying || model.playbackProgress > 0) {
                        VStack(spacing: 8) {
                            ProgressView(value: model.playbackProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .scaleEffect(x: 1, y: 2, anchor: .center)
                            
                            HStack {
                                Text("0:00")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatTime(model.playbackDuration))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    Button("Save Recording") {
                        print("LOG: Save button pressed in sheet")
                        model.saveRecording()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .cornerRadius(25)
                    
                    Button("Discard & Re-record") {
                        print("LOG: Discard button pressed in sheet")
                        model.discardRecording()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.red, lineWidth: 2)
                    )
                }
            }
            .padding()
            .navigationTitle("Review Recording")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                model.discardRecording()
                dismiss()
            })
        }
        .onDisappear {
            // Stop playback when sheet is dismissed
            model.stopPlayback()
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

// MARK: - Custom Progress Bar for Recording

//struct CustomProgressBar: View {
//    let progress: Double
//    let color: Color
//
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack(alignment: .leading) {
//                // Background of the progress bar
//                Capsule()
//                    .fill(Color.gray.opacity(0.25))
//                
//                // Foreground (the actual progress)
//                Capsule()
//                    .fill(color)
//                    .frame(width: geometry.size.width * progress)
//                    .animation(.linear(duration: 0.1), value: progress)
//            }
//        }
//    }
//}

// MARK: - Recording Timer Display

struct RecordingTimerView: View {
    let elapsed: TimeInterval
    let maxDuration: TimeInterval
    let isRecording: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(formatTime(elapsed))
                .font(.title)
                .monospacedDigit()
                .foregroundColor(isRecording ? .red : .primary)
            
            Text("/ \(formatTime(maxDuration))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if isRecording {
                CustomProgressBar(
                    progress: elapsed / maxDuration,
                    color: .red
                )
                .frame(height: 4)
                .padding(.horizontal, 20)
            }
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

// MARK: - Audio Waveform Visualization (Optional Enhancement)

struct AudioWaveformView: View {
    let isRecording: Bool
    @State private var animationPhase: Double = 0
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(isRecording ? Color.red : Color.gray.opacity(0.3))
                    .frame(width: 3)
                    .frame(height: isRecording ? randomHeight() : 8)
                    .animation(
                        .easeInOut(duration: 0.3)
                        .repeatForever()
                        .delay(Double(index) * 0.05),
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            if isRecording {
                withAnimation {
                    animationPhase = 1.0
                }
            }
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                withAnimation {
                    animationPhase = 1.0
                }
            } else {
                animationPhase = 0.0
            }
        }
    }
    
    private func randomHeight() -> CGFloat {
        return CGFloat.random(in: 8...24)
    }
}

//struct SaveRecordingView: View {
//    @ObservedObject var model: VoiceMemoModel
//    @Environment(\.dismiss) private var dismiss
//
//    var body: some View {
//        NavigationView {
//            VStack(spacing: 24) {
//                VStack(spacing: 16) {
//                    Text("Recording Complete")
//                        .font(.title2)
//                        .fontWeight(.semibold)
//                    
//                    if let url = model.currentFileURL {
//                        Text(url.lastPathComponent)
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                            .lineLimit(1)
//                            .truncationMode(.middle)
//                    }
//                    
//                    Text("Duration: \(formatTime(model.elapsed))")
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                }
//                
//                VStack(spacing: 16) {
//                    // Playback progress bar - only show when playback duration is available
//                    if model.playbackDuration > 0 && (model.isPlaying || model.playbackProgress > 0) {
//                        VStack(spacing: 8) {
//                            HStack {
//                                Text("0:00")
//                                    .font(.caption)
//                                    .foregroundColor(.secondary)
//                                    .monospacedDigit()
//                                
//                                CustomProgressBar(
//                                    progress: model.playbackProgress,
//                                    color: .blue
//                                )
//                                .frame(height: 4)
//                                
//                                Text(formatTime(model.playbackDuration))
//                                    .font(.caption)
//                                    .foregroundColor(.secondary)
//                                    .monospacedDigit()
//                            }
//                        }
//                    }
//                    
//                    // Play button - only show when not playing
//                    if !model.isPlaying {
//                        Button(action: {
//                            print("LOG: Play button pressed")
//                            model.startPlayback()
//                        }) {
//                            HStack {
//                                Image(systemName: "play.fill")
//                                Text("Play Recording")
//                            }
//                            .font(.headline)
//                            .foregroundColor(.white)
//                            .padding(.horizontal, 24)
//                            .padding(.vertical, 12)
//                            .background(Color.blue)
//                            .cornerRadius(25)
//                        }
//                    }
//                }
//                
//                Spacer()
//                
//                // Save and Discard buttons
//                HStack(spacing: 16) {
//                    Button("Discard", role: .destructive) {
//                        print("LOG: Discard button pressed in sheet")
//                        model.discardRecording()
//                    }
//                    .font(.headline)
//                    .foregroundColor(.red)
//                    .padding(.horizontal, 24)
//                    .padding(.vertical, 12)
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 25)
//                            .stroke(Color.red, lineWidth: 2)
//                    )
//                    
//                    Button("Save Recording") {
//                        print("LOG: Save button pressed in sheet")
//                        model.saveRecording()
//                    }
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    .padding(.horizontal, 24)
//                    .padding(.vertical, 12)
//                    .background(Color.green)
//                    .cornerRadius(25)
//                }
//            }
//            .padding()
//            .navigationTitle("Review Recording")
//            .navigationBarTitleDisplayMode(.inline)
//        }
//        .onDisappear {
//            // Stop playback when sheet is dismissed
//            model.stopPlayback()
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

// Simple share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
