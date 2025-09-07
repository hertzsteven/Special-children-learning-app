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

struct SaveRecordingView: View {
    @ObservedObject var model: VoiceMemoModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
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
                
                VStack(spacing: 16) {
                    // Playback progress bar - only show when playback duration is available
                    if model.playbackDuration > 0 && (model.isPlaying || model.playbackProgress > 0) {
                        VStack(spacing: 8) {
                            HStack {
                                Text("0:00")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                                
                                CustomProgressBar(
                                    progress: model.playbackProgress,
                                    color: .blue
                                )
                                .frame(height: 4)
                                
                                Text(formatTime(model.playbackDuration))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                    
                    // Play button - only show when not playing
                    if !model.isPlaying {
                        Button(action: {
                            print("LOG: Play button pressed")
                            model.startPlayback()
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Play Recording")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(25)
                        }
                    }
                }
                
                Spacer()
                
                // Save and Discard buttons
                HStack(spacing: 16) {
                    Button("Discard", role: .destructive) {
                        print("LOG: Discard button pressed in sheet")
                        model.discardRecording()
                    }
                    .font(.headline)
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.red, lineWidth: 2)
                    )
                    
                    Button("Save Recording") {
                        print("LOG: Save button pressed in sheet")
                        model.saveRecording()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(25)
                }
            }
            .padding()
            .navigationTitle("Review Recording")
            .navigationBarTitleDisplayMode(.inline)
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

// Simple share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
