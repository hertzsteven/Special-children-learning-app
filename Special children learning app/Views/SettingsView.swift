//
//  SettingsView.swift
//  Special children learning app
//
//  Created by Steven Hertz on 9/4/25.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Video Repeat Setting")
                            .font(.headline)
                        
                        Text("Choose how many times each video should play before moving to the next one. This helps with learning through repetition.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    Picker("Repeat Count", selection: $settings.videoRepeatCount) {
                        ForEach(settings.repeatCountOptions, id: \.self) { count in
                            if count == 1 {
                                Text("Play once (no repeat)")
                                    .tag(count)
                            } else {
                                Text("Repeat \(count) times")
                                    .tag(count)
                            }
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Currently set to: \(settings.repeatCountDescription)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Video Playback")
                } footer: {
                    Text("This setting applies to all video collections. Each video will repeat the selected number of times before automatically advancing to the next video.")
                }
                
                Section {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("For Special Needs Learning")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Repetition helps children with special needs learn and retain information better. Try 2-3 repeats for optimal learning.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Tips")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}