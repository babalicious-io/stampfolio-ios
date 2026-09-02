//
//  StampAssetMediaView.swift
//  StampFolio
//
//  Renders audio/video stamp placeholders
//

import SwiftUI

/// View for rendering audio/video stamp placeholders
struct StampAssetMediaView: View {
    
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
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            gradientBackground
            
            Image(systemName: type.iconName)
                .font(.system(size: 44))
                .foregroundStyle(.white)
        }
    }
    
    // MARK: - Gradient Background
    
    private var gradientBackground: LinearGradient {
        LinearGradient.cardBackground(color: appColorScheme.primary)
    }
}
