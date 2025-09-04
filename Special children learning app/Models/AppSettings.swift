//
//  AppSettings.swift
//  Special children learning app
//
//  Created by Steven Hertz on 9/4/25.
//

import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    private let userDefaults = UserDefaults.standard
    private let videoRepeatCountKey = "videoRepeatCount"
    
    @Published var videoRepeatCount: Int {
        didSet {
            userDefaults.set(videoRepeatCount, forKey: videoRepeatCountKey)
        }
    }
    
    private init() {
        // Default to 1 repeat (so video plays once), can be changed by user
        self.videoRepeatCount = userDefaults.object(forKey: videoRepeatCountKey) as? Int ?? 1
    }
    
    // Convenience computed properties
    var repeatCountOptions: [Int] {
        return [1, 2, 3, 4, 5]
    }
    
    var repeatCountDescription: String {
        switch videoRepeatCount {
        case 1:
            return "Play once (no repeat)"
        default:
            return "Repeat \(videoRepeatCount) times"
        }
    }
}