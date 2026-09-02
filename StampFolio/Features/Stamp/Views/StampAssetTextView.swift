//
//  StampAssetTextView.swift
//  StampFolio
//
//  Renders text-based stamp content
//

import SwiftUI

/// View for rendering text-based stamp content
struct StampAssetTextView: View {
    
    // MARK: - Properties
    
    let url: URL?
    let onFailure: () -> Void
    
    // MARK: - State
    
    @State private var content: String = ""
    @State private var isLoading = true
    
    // MARK: - Environment
    
    @Environment(\.appColorScheme) private var appColorScheme
    
    private var gradientBackground: LinearGradient {
        LinearGradient.cardBackground(color: appColorScheme.primary)
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            gradientBackground
            
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Text(content)
                    .font(.system(.caption2))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(8)
                    .padding(8)
            }
        }
        .task {
            await fetchContent()
        }
    }
    
    // MARK: - Content Fetching
    
    private func fetchContent() async {
        guard let url = url else {
            onFailure()
            isLoading = false
            return
        }
        
        // Check disk cache first
        if let cachedText = await StampContentCache.shared.read(for: url) {
            content = cachedText
            isLoading = false
            return
        }
        
        // Cache miss - fetch from network, cache, then display
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let text = String(data: data, encoding: .utf8) {
                await StampContentCache.shared.write(text, for: url)
                content = text
            } else {
                onFailure()
            }
        } catch {
            print("Text content load failed: \(error.localizedDescription)")
            onFailure()
        }
        
        isLoading = false
    }
}
