//
//  CounterpartyAssetFullscreenView.swift
//  StampFolio
//
//  Full-screen immersive viewer for paging through Counterparty assets
//

import SwiftUI

/// Full-screen viewer for Counterparty assets. Counterparty holdings are image-only (unlike
/// Stamps, which also support HTML/audio/video/text content), so this is a much simpler
/// single-page viewer than `StampAssetFullscreenView`, but mirrors the same pinch-to-zoom, pan,
/// swipe-to-navigate, and swipe-down-to-dismiss gestures for a consistent fullscreen experience.
struct CounterpartyAssetFullscreenView: View {

    // MARK: - Properties

    let assets: [CounterpartyAsset]
    let initialIndex: Int
    let isSlideshow: Bool

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var currentIndex: Int
    @AppStorage("slideshowInterval") private var slideshowInterval = 5
    @State private var gestureState = ZoomPanNavigationState()

    // MARK: - Computed Properties

    private var currentAsset: CounterpartyAsset {
        assets[currentIndex]
    }

    // MARK: - Initialization

    init(assets: [CounterpartyAsset], initialIndex: Int, isSlideshow: Bool = false) {
        self.assets = assets
        self.initialIndex = initialIndex
        self.isSlideshow = isSlideshow
        _currentIndex = State(initialValue: initialIndex)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Tap background to dismiss
                        dismiss()
                    }

                if !assets.isEmpty {
                    VStack(spacing: 24) {
                        Spacer(minLength: 0)

                        // Fills the available page (minus room for the name below), letterboxing
                        // rather than cropping so card-shaped artwork is shown in full.
                        CounterpartyAssetImageView(
                            asset: currentAsset,
                            size: CGSize(width: geometry.size.width, height: geometry.size.height * 0.75)
                        )
                        .id(currentIndex)
                        .frame(maxWidth: geometry.size.width - 32, maxHeight: geometry.size.height * 0.75)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .scaleEffect(gestureState.scale)
                        .offset(gestureState.offset)
                        .offset(y: gestureState.dragOffset.height)
                        .offset(x: gestureState.horizontalDragOffset.width)
                        .opacity(1.0 - Double(abs(gestureState.dragOffset.height)) / 500.0)

                        Text(currentAsset.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .opacity(1.0 - Double(abs(gestureState.dragOffset.height)) / 300.0)

                        Spacer(minLength: 0)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .contentShape(Rectangle())
                    .gesture(gestureState.magnificationGesture())
                    .gesture(unifiedDragGesture)
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.3)) {
                            gestureState.toggleZoom()
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .statusBarHidden(true)
        .task(id: isSlideshow ? currentIndex : -1) {
            guard isSlideshow, assets.count > 1 else { return }
            try? await Task.sleep(for: .seconds(slideshowInterval))
            guard !Task.isCancelled else { return }
            navigateToNextSlideshow()
        }
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel(assets.indices.contains(currentIndex) ? "\(assets[currentIndex].displayName), \(currentIndex + 1) of \(assets.count)" : "")
        .accessibilityHint("Swipe left for next, right for previous, down to close, double tap to zoom")
    }

    // MARK: - Gestures

    // Unified drag gesture - handles pan when zoomed, navigation and dismiss when not zoomed
    private var unifiedDragGesture: some Gesture {
        gestureState.dragGesture(
            onNavigateNext: navigateToNext,
            onNavigatePrevious: navigateToPrevious,
            onDismiss: { dismiss() }
        )
    }

    // MARK: - Navigation

    private func navigateToNext() {
        guard currentIndex < assets.count - 1 else {
            withAnimation(.spring(response: 0.3)) {
                gestureState.horizontalDragOffset = .zero
            }
            return
        }

        withAnimation(.spring(response: 0.3)) {
            currentIndex += 1
            gestureState.horizontalDragOffset = .zero
            gestureState.resetZoom()
        }
    }

    private func navigateToPrevious() {
        guard currentIndex > 0 else {
            withAnimation(.spring(response: 0.3)) {
                gestureState.horizontalDragOffset = .zero
            }
            return
        }

        withAnimation(.spring(response: 0.3)) {
            currentIndex -= 1
            gestureState.horizontalDragOffset = .zero
            gestureState.resetZoom()
        }
    }

    private func navigateToNextSlideshow() {
        withAnimation(.spring(response: 0.3)) {
            currentIndex = currentIndex < assets.count - 1 ? currentIndex + 1 : 0
            gestureState.horizontalDragOffset = .zero
            gestureState.resetZoom()
        }
    }
}

// MARK: - Preview

#Preview {
    CounterpartyAssetFullscreenView(assets: [.sample], initialIndex: 0)
}
