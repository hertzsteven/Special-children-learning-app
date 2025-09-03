//
//  ActivityItem.swift
//  Special children learning app
//
//  Created by Steven Hertz on 9/3/25.
//

import Foundation
import SwiftUI

struct ActivityItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let imageName: String
    let videoFileName: String
    let audioDescription: String
    let backgroundColor: String
    
    static let sampleActivities: [ActivityItem] = [
        ActivityItem(
            title: "Eat Breakfast",
            imageName: "fork.knife",
            videoFileName: "breakfast_video",
            audioDescription: "A child is eating a healthy breakfast with cereal, toast, and juice",
            backgroundColor: "sage"
        ),
        ActivityItem(
            title: "Brush Teeth",
            imageName: "mouth",
            videoFileName: "brushteeth_video", 
            audioDescription: "A child is brushing their teeth to keep them clean and healthy",
            backgroundColor: "softBlue"
        ),
        ActivityItem(
            title: "Play with Blocks",
            imageName: "cube.box",
            videoFileName: "blocks_video",
            audioDescription: "A child is playing and building with colorful blocks",
            backgroundColor: "warmBeige"
        ),
        ActivityItem(
            title: "Read a Book",
            imageName: "book",
            videoFileName: "reading_video",
            audioDescription: "A child is reading a book and learning new words",
            backgroundColor: "softBlue"
        ),
        ActivityItem(
            title: "Say Hello",
            imageName: "hand.wave",
            videoFileName: "hello_video",
            audioDescription: "A child is waving hello to say hi to friends",
            backgroundColor: "sage"
        ),
        ActivityItem(
            title: "Get Dressed",
            imageName: "tshirt",
            videoFileName: "dressed_video",
            audioDescription: "A child is getting dressed and putting on clothes",
            backgroundColor: "softBlue"
        )
    ]
}