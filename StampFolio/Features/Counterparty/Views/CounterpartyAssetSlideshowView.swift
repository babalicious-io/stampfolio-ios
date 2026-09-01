//
//  CounterpartyAssetSlideshowView.swift
//  StampFolio
//
//  Full-screen immersive viewer for paging through Counterparty assets
//

import SwiftUI

/// Full-screen viewer for Counterparty assets. Counterparty holdings are image-only (unlike
/// Stamps, which also support HTML/audio/video/text content), so this is a much simpler
/// page-based viewer than `StampDetailView`, but supports the same pinch-to-zoom, pan, and
/// swipe-down-to-dismiss gestures for a consistent fullscreen experience.
struct CounterpartyAssetSlideshowView: View {

    // MARK: - Properties

    let assets: [CounterpartyAsset]
    let initialIndex: Int
    let isSlideshow: Bool

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var currentIndex: Int
    @AppStorage("slideshowInterval") private var slideshowInterval = 5

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero

    // MARK: - Initialization

    init(assets: [CounterpartyAsset], initialIndex: Int, isSlideshow: Bool = false) {
        self.assets = assets
        self.initialIndex = initialIndex
        self.isSlideshow = isSlideshow
        _currentIndex = State(initialValue: initialIndex)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if assets.isEmpty {
                emptyView
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(assets.indices, id: \.self) { index in
                        assetPage(assets[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()

                overlayControls
            }
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .statusBarHidden(true)
        .task(id: isSlideshow ? currentIndex : -1) {
            guard isSlideshow, assets.count > 1 else { return }
            try? await Task.sleep(for: .seconds(slideshowInterval))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3)) {
                currentIndex = currentIndex < assets.count - 1 ? currentIndex + 1 : 0
            }
        }
        .onChange(of: currentIndex) { _, _ in
            resetZoom()
        }
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel(assets.indices.contains(currentIndex) ? "\(assets[currentIndex].displayName), \(currentIndex + 1) of \(assets.count)" : "")
        .accessibilityHint("Swipe left for next, right for previous, pinch to zoom, drag down to close")
    }

    // MARK: - Asset Page

    private func assetPage(_ asset: CounterpartyAsset) -> some View {
        GeometryReader { geometry in
            VStack(spacing: 24) {
                Spacer(minLength: 0)

                // Fills the available page (minus room for the name below), letterboxing
                // rather than cropping so card-shaped artwork is shown in full.
                CounterpartyAssetImageView(
                    asset: asset,
                    size: CGSize(width: geometry.size.width, height: geometry.size.height * 0.75)
                )
                .frame(maxWidth: geometry.size.width - 32, maxHeight: geometry.size.height * 0.75)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .scaleEffect(scale)
                .offset(offset)
                .offset(y: dragOffset.height)
                .opacity(1.0 - Double(abs(dragOffset.height)) / 500.0)

                Text(asset.displayName)
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
            .gesture(dragGesture)
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
        }
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

    /// Pans the image when zoomed in; dismisses on a clear vertical swipe when not zoomed.
    /// Horizontal paging between assets is left to `TabView`'s own gesture, so this only acts
    /// once the vertical component clearly dominates.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if scale > 1.0 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                } else if abs(value.translation.height) > abs(value.translation.width) {
                    dragOffset = CGSize(width: 0, height: value.translation.height)
                }
            }
            .onEnded { value in
                if scale > 1.0 {
                    lastOffset = offset
                } else if abs(value.translation.height) > abs(value.translation.width) {
                    if abs(value.translation.height) > 100 || abs(value.velocity.height) > 500 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3)) {
                            dragOffset = .zero
                        }
                    }
                }
            }
    }

    private func resetZoom() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
        dragOffset = .zero
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

// MARK: - Preview

#Preview {
    CounterpartyAssetSlideshowView(assets: [.sample], initialIndex: 0)
}
