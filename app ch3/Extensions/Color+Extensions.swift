//
//  Color+Extensions.swift
//  app ch3
//
//  Estensioni per i colori personalizzati dell'app
//

import SwiftUI

extension Color {
    // Colori personalizzati dell'app
    static let appAccent = Color(hex: "BFF207")        // Giallo-verde per elementi importanti e non visitati
    static let appBackground = Color(hex: "1F092F")    // Viola scuro per background
    static let appVisited = Color(hex: "7F6EF1")       // Viola chiaro per luoghi visitati
    
    // Inizializzatore per colori hex
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
