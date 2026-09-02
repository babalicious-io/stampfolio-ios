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
    @Environment(\.appColorScheme) private var appColorScheme

    // MARK: - State

    @State private var currentIndex: Int
    @AppStorage("slideshowInterval") private var slideshowInterval = 5

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var horizontalDragOffset: CGSize = .zero

    // MARK: - Computed Properties

    private var currentAsset: CounterpartyAsset {
        assets[currentIndex]
    }

    private let swipeThreshold: CGFloat = 100

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

                if assets.isEmpty {
                    emptyView
                } else {
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
                        .scaleEffect(scale)
                        .offset(offset)
                        .offset(y: dragOffset.height)
                        .offset(x: horizontalDragOffset.width)
                        .opacity(1.0 - Double(abs(dragOffset.height)) / 500.0)

                        Text(currentAsset.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .opacity(1.0 - Double(abs(dragOffset.height)) / 300.0)

                        Spacer(minLength: 0)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .contentShape(Rectangle())
                    .gesture(magnificationGesture)
                    .gesture(unifiedDragGesture)
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.3)) {
                            if scale > 1.0 {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.5
                                lastScale = 2.5
                            }
                        }
                    }

                    overlayControls
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

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, 1.0), 5.0)
            }
            .onEnded { _ in
                lastScale = scale

                if scale < 1.0 {
                    withAnimation(.spring(response: 0.3)) {
                        scale = 1.0
                        lastScale = 1.0
                    }
                }
            }
    }

    // Unified drag gesture - handles pan when zoomed, navigation and dismiss when not zoomed
    private var unifiedDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.0 {
                    // Pan when zoomed in
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                } else {
                    // Determine drag direction when not zoomed
                    let horizontalAmount = abs(value.translation.width)
                    let verticalAmount = abs(value.translation.height)

                    if horizontalAmount > verticalAmount {
                        // Horizontal drag - navigation
                        horizontalDragOffset = CGSize(width: value.translation.width, height: 0)
                        dragOffset = .zero
                    } else {
                        // Vertical drag - dismiss
                        dragOffset = CGSize(width: 0, height: value.translation.height)
                        horizontalDragOffset = .zero
                    }
                }
            }
            .onEnded { value in
                if scale > 1.0 {
                    // Save pan offset when zoomed
                    lastOffset = offset
                } else {
                    // Determine drag direction when not zoomed
                    let horizontalAmount = abs(value.translation.width)
                    let verticalAmount = abs(value.translation.height)

                    if horizontalAmount > verticalAmount {
                        // Horizontal swipe - navigation
                        let swipeDistance = value.translation.width
                        let swipeVelocity = value.velocity.width

                        // Swipe left (next asset)
                        if swipeDistance < -swipeThreshold || swipeVelocity < -500 {
                            navigateToNext()
                        }
                        // Swipe right (previous asset)
                        else if swipeDistance > swipeThreshold || swipeVelocity > 500 {
                            navigateToPrevious()
                        }
                        else {
                            // Snap back
                            withAnimation(.spring(response: 0.3)) {
                                horizontalDragOffset = .zero
                            }
                        }
                    } else {
                        // Vertical swipe - dismiss
                        if abs(value.translation.height) > 100 || abs(value.velocity.height) > 500 {
                            dismiss()
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.3)) {
                                dragOffset = .zero
                            }
                        }
                    }
                }
            }
    }

    // MARK: - Navigation

    private func navigateToNext() {
        guard currentIndex < assets.count - 1 else {
            withAnimation(.spring(response: 0.3)) {
                horizontalDragOffset = .zero
            }
            return
        }

        withAnimation(.spring(response: 0.3)) {
            currentIndex += 1
            horizontalDragOffset = .zero
            resetZoom()
        }
    }

    private func navigateToPrevious() {
        guard currentIndex > 0 else {
            withAnimation(.spring(response: 0.3)) {
                horizontalDragOffset = .zero
            }
            return
        }

        withAnimation(.spring(response: 0.3)) {
            currentIndex -= 1
            horizontalDragOffset = .zero
            resetZoom()
        }
    }

    private func navigateToNextSlideshow() {
        withAnimation(.spring(response: 0.3)) {
            currentIndex = currentIndex < assets.count - 1 ? currentIndex + 1 : 0
            horizontalDragOffset = .zero
            resetZoom()
        }
    }

    private func resetZoom() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }

    // MARK: - Overlay Controls

    private var overlayControls: some View {
        VStack {
            HStack {
                Spacer()
                closeButton
            }

            Spacer()

            if assets.count > 1 {
                Text("\(currentIndex + 1) of \(assets.count)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 8)
            }
        }
        .padding()
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.85))
        }
        .accessibilityLabel("Close")
        .accessibilityHint("Dismisses the slideshow")
    }

    // MARK: - Empty View

    private var emptyView: some View {
        ZStack {
            LinearGradient.fullscreenBackground(color: appColorScheme.primary)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "xmark.triangle.circle.square.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.6))

                Text("No assets to display")
                    .foregroundStyle(.white.opacity(0.8))

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CounterpartyAssetFullscreenView(assets: [.sample], initialIndex: 0)
}
