//
//  StampCardView.swift
//  StampFolio
//
//  Individual stamp card for the collection grid
//

import SwiftUI
import Kingfisher

/// Card view displaying a stamp in the collection grid
struct StampCardView: View {
    
    // MARK: - Properties
    
    let stamp: Stamp
    let onTap: () -> Void
    let onInfoTap: () -> Void
    
    // MARK: - Environment
    
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - State
    
    @State private var isPressed = false
    
    // MARK: - Layout
    
    @ScaledMetric(relativeTo: .body) private var infoButtonSize: CGFloat = 24
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Stamp Image
            stampImage
            
            // Footer with stamp number and info button
            footer
        }
        .glassCard(cornerRadius: 16, shadowRadius: 8)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityElement(children: .combine)
        .accessibilityLabel(stamp.formattedNumber)
        .accessibilityHint("Double tap to view full screen")
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Stamp Image
    
    private var stampImage: some View {
        GeometryReader { geometry in
            KFImage(stamp.imageURL)
                .placeholder {
                    placeholderView
                }
                .retry(maxCount: 3, interval: .seconds(2))
                .onFailure { _ in
                    // Log error if needed
                }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.width)
                .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    // MARK: - Placeholder View
    
    private var placeholderView: some View {
        ZStack {
            Color.stampchainBackground
            
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundStyle(Color.stampchainGrey)
                
                ProgressView()
                    .tint(Color.stampchainPurple)
            }
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            // Stamp number
            Text(stamp.formattedNumber)
                .font(.cardTitle)
                .foregroundStyle(Color.primaryText(for: colorScheme))
                .lineLimit(1)
            
            Spacer()
            
            // Info button
            Button {
                onInfoTap()
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: infoButtonSize * 0.75))
                    .foregroundStyle(Color.stampchainPurple)
                    .frame(width: infoButtonSize, height: infoButtonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show stamp details")
            .accessibilityHint("Opens stamp metadata popup")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.stampchainBackground.opacity(0.5))
    }
}

// MARK: - Preview

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        StampCardView(
            stamp: .sample,
            onTap: {},
            onInfoTap: {}
        )
        
        StampCardView(
            stamp: .samples[1],
            onTap: {},
            onInfoTap: {}
        )
    }
    .padding()
    .stampchainBackground()
}
