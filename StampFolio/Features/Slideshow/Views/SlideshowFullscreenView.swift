//
//  SlideshowFullscreenView.swift
//  StampFolio
//
//  Mixed-protocol autoplay slideshow
//

import SwiftUI

/// Full-screen autoplay viewer that pages through mixed protocol assets
struct SlideshowFullscreenView: View {

    // MARK: - Properties

    let items: [SlideshowItem]

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var currentIndex: Int = 0
    @AppStorage("slideshowInterval") private var slideshowInterval = 5
    @State private var gestureState = ZoomPanNavigationState()

    // MARK: - Computed Properties

    private var currentItem: SlideshowItem? {
        items.indices.contains(currentIndex) ? items[currentIndex] : nil
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

                if let currentItem {
                    slidePage(for: currentItem, geometry: geometry)
                }
            }
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .statusBarHidden(true)
        .task(id: currentIndex) {
            guard items.count > 1 else { return }
            try? await Task.sleep(for: .seconds(slideshowInterval))
            guard !Task.isCancelled else { return }
            navigateToNextSlideshow()
        }
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel(currentItem.map { "\($0.accessibilityName), \(currentIndex + 1) of \(items.count)" } ?? "")
        .accessibilityHint("Swipe left for next, right for previous, down to close, double tap to zoom")
    }

    // MARK: - Slide Page

    @ViewBuilder
    private func slidePage(for item: SlideshowItem, geometry: GeometryProxy) -> some View {
        switch item {
        case .stamp(let asset):
            ZStack {
                StampAssetFullscreenContent(asset: asset)
                    .scaleEffect(gestureState.scale)
                    .offset(gestureState.offset)
                    .offset(y: gestureState.dragOffset.height)
                    .offset(x: gestureState.horizontalDragOffset.width)
                    .opacity(1.0 - Double(abs(gestureState.dragOffset.height)) / 500.0)

                Color.clear
                    .contentShape(Rectangle())
            }
            .gesture(gestureState.magnificationGesture())
            .gesture(unifiedDragGesture)
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3)) {
                    gestureState.toggleZoom()
                }
            }

        case .counterparty(let asset):
            VStack(spacing: 24) {
                Spacer(minLength: 0)

                CounterpartyAssetImageView(
                    asset: asset,
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

                Text(asset.displayName)
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
        guard currentIndex < items.count - 1 else {
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
            currentIndex = currentIndex < items.count - 1 ? currentIndex + 1 : 0
            gestureState.horizontalDragOffset = .zero
            gestureState.resetZoom()
        }
    }
}

// MARK: - Preview

#Preview {
    SlideshowFullscreenView(items: [
        .stamp(.sample),
        .counterparty(.sample)
    ])
}
