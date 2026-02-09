//
//  StampLibraryView.swift
//  StampFolio
//
//  Renders library file stamp placeholders (JS, CSS, GZIP)
//

import SwiftUI

/// View for rendering library file stamp placeholders
struct StampLibraryView: View {
    
    // MARK: - Properties
    
    let label: String
    
    // MARK: - Environment
    
    @Environment(\.appColorScheme) private var appColorScheme
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            gradientBackground
            
            Text(label)
                .font(.system(size: 44))
                .fontWeight(.bold)
                .foregroundStyle(colorScheme == .dark ? .white : .black)
        }
    }
    
    // MARK: - Gradient Background
    
    private var gradientBackground: LinearGradient {
        let backgroundColor: Color = colorScheme == .dark ? .black : .white
        return LinearGradient.stampCardBackground(color: appColorScheme.primary, backgroundColor: backgroundColor)
    }
}
