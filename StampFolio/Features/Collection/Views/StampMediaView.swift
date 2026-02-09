//
//  StampMediaView.swift
//  StampFolio
//
//  Renders audio/video stamp placeholders
//

import SwiftUI

/// View for rendering audio/video stamp placeholders
struct StampMediaView: View {
    
    // MARK: - Media Type
    
    enum MediaType {
        case audio
        case video
        
        var iconName: String {
            switch self {
            case .audio: return "waveform"
            case .video: return "play.fill"
            }
        }
    }
    
    // MARK: - Properties
    
    let type: MediaType
    
    // MARK: - Environment
    
    @Environment(\.appColorScheme) private var appColorScheme
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            gradientBackground
            
            Image(systemName: type.iconName)
                .font(.system(size: 44))
                .foregroundStyle(colorScheme == .dark ? .white : .black)
        }
    }
    
    // MARK: - Gradient Background
    
    private var gradientBackground: LinearGradient {
        let backgroundColor: Color = colorScheme == .dark ? .black : .white
        return LinearGradient.stampCardBackground(color: appColorScheme.primary, backgroundColor: backgroundColor)
    }
}
