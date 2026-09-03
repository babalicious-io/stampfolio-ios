//
//  CounterpartyAssetFullscreenView.swift
//  StampFolio
//
//  Full-screen immersive viewer for paging through Counterparty assets
//

import SwiftUI

/// Full-screen viewer for Counterparty assets. Mirrors `StampAssetFullscreenView`:
/// full-bleed artwork on black, pinch-to-zoom, pan, swipe-to-navigate, swipe-down-to-dismiss.
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
                        dismiss()
                    }

                ZStack {
                    if !assets.isEmpty {
                        CounterpartyAssetFullscreenContent(asset: currentAsset)
                            .id(currentAsset.id)
                            .scaleEffect(gestureState.scale)
                            .offset(gestureState.offset)
                            .offset(y: gestureState.dragOffset.height)
                            .offset(x: gestureState.horizontalDragOffset.width)
                            .opacity(1.0 - Double(abs(gestureState.dragOffset.height)) / 500.0)
                    }

                    Color.clear
                        .contentShape(Rectangle())
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .gesture(gestureState.magnificationGesture())
                .gesture(unifiedDragGesture)
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3)) {
                        gestureState.toggleZoom()
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
