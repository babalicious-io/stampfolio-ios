//
//  CounterpartyAssetSlideshowView.swift
//  StampFolio
//
//  Full-screen immersive viewer for paging through Counterparty assets
//

import SwiftUI

/// Full-screen viewer for Counterparty assets. Counterparty holdings are image-only (unlike
/// Stamps, which also support HTML/audio/video/text content), so this is a much simpler
/// page-based viewer than `StampDetailView`, with the same slideshow auto-advance behavior.
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
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel(assets.indices.contains(currentIndex) ? "\(assets[currentIndex].displayName), \(currentIndex + 1) of \(assets.count)" : "")
        .accessibilityHint("Swipe left for next, right for previous")
    }

    // MARK: - Asset Page

    private func assetPage(_ asset: CounterpartyAsset) -> some View {
        VStack(spacing: 24) {
            Spacer()

            CounterpartyAssetImageView(asset: asset, size: CGSize(width: 320, height: 320))
                .frame(width: 320, height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 24))

            Text(asset.displayName)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
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
