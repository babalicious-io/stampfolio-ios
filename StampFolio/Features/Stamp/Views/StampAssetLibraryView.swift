//
//  StampAssetLibraryView.swift
//  StampFolio
//
//  Renders library file stamp placeholders (JS, CSS, GZIP)
//

import SwiftUI

/// View for rendering library file stamp placeholders
struct StampAssetLibraryView: View {
    
    // MARK: - Properties
    
    let label: String
    
    // MARK: - Environment
    
    @Environment(\.appColorScheme) private var appColorScheme
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            gradientBackground
            
            Text(label)
                .font(.system(size: 44))
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
    }
    
    // MARK: - Gradient Background
    
    private var gradientBackground: LinearGradient {
        LinearGradient.cardBackground(color: appColorScheme.primary)
    }
}
