//
//  Color+Theme.swift
//  Special children learning app
//
//  Created by Steven Hertz on 9/3/25.
//

import SwiftUI

extension Color {
    // Calm, accessible colors for special needs children
    static let sage = Color(red: 0.85, green: 0.89, blue: 0.82)
    static let softBlue = Color(red: 0.82, green: 0.87, blue: 0.93)
    static let warmBeige = Color(red: 0.93, green: 0.90, blue: 0.85)
    static let lavender = Color(red: 0.88, green: 0.85, blue: 0.93)
    static let creamBackground = Color(red: 0.98, green: 0.97, blue: 0.95)
    
    // Dynamic color that adapts to the string identifier
    init(_ colorName: String) {
        switch colorName {
        case "sage":
            self = .sage
        case "softBlue":
            self = .softBlue
        case "warmBeige":
            self = .warmBeige
        case "lavender":
            self = .lavender
        default:
            self = .sage
        }
    }
}