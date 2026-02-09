//
//  StampTextView.swift
//  StampFolio
//
//  Renders text-based stamp content
//

import SwiftUI

/// View for rendering text-based stamp content
struct StampTextView: View {
    
    // MARK: - Properties
    
    let url: URL?
    let onFailure: () -> Void
    
    // MARK: - State
    
    @State private var content: String = ""
    @State private var isLoading = true
    
    // MARK: - Environment
    
    @Environment(\.appColorScheme) private var appColorScheme
    @Environment(\.colorScheme) private var colorScheme
    
    private var gradientBackground: LinearGradient {
        let backgroundColor: Color = colorScheme == .dark ? .black : .white
        return LinearGradient.stampCardBackground(color: appColorScheme.primary, backgroundColor: backgroundColor)
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            gradientBackground
            
            if isLoading {
                ProgressView()
                    .tint(colorScheme == .dark ? .white : .black)
            } else {
                Text(content)
                    .font(.system(.caption2))
                    .fontWeight(.semibold)
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
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
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let text = String(data: data, encoding: .utf8) {
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
