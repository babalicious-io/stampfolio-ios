//
//  ZoomPanNavigationState.swift
//  StampFolio
//
//  Shared pinch-to-zoom, pan, and swipe-to-navigate/dismiss gesture state used by the
//  fullscreen viewers (Stamp, Counterparty). Owns only zoom/pan/drag state and the two
//  gestures; each view keeps its own `currentIndex` (since it indexes into a feature-specific
//  asset array) and calls back into it via the closures passed to `dragGesture`.
//

import SwiftUI
import Observation

@Observable
final class ZoomPanNavigationState {
    var scale: CGFloat = 1.0
    var lastScale: CGFloat = 1.0
    var offset: CGSize = .zero
    var lastOffset: CGSize = .zero
    var dragOffset: CGSize = .zero
    var horizontalDragOffset: CGSize = .zero

    let swipeThreshold: CGFloat = 100

    /// Reset zoom/pan back to the default (used when navigating to a new item)
    func resetZoom() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }

    /// Double-tap: zoom in to `zoomedScale` if currently at 1.0, otherwise reset
    func toggleZoom(zoomedScale: CGFloat = 2.5) {
        if scale > 1.0 {
            resetZoom()
        } else {
            scale = zoomedScale
            lastScale = zoomedScale
        }
    }

    // MARK: - Gestures

    func magnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { [weak self] value in
                guard let self else { return }
                let newScale = lastScale * value
                scale = min(max(newScale, 1.0), 5.0)
            }
            .onEnded { [weak self] _ in
                guard let self else { return }
                lastScale = scale

                // Reset if zoomed out too much
                if scale < 1.0 {
                    withAnimation(.spring(response: 0.3)) {
                        self.scale = 1.0
                        self.lastScale = 1.0
                    }
                }
            }
    }

    /// Unified drag gesture - handles pan when zoomed, navigation and dismiss when not zoomed
    func dragGesture(
        onNavigateNext: @escaping () -> Void,
        onNavigatePrevious: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> some Gesture {
        DragGesture()
            .onChanged { [weak self] value in
                guard let self else { return }
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
            .onEnded { [weak self] value in
                guard let self else { return }
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

                        if swipeDistance < -swipeThreshold || swipeVelocity < -500 {
                            onNavigateNext()
                        } else if swipeDistance > swipeThreshold || swipeVelocity > 500 {
                            onNavigatePrevious()
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.3)) {
                                self.horizontalDragOffset = .zero
                            }
                        }
                    } else {
                        // Vertical swipe - dismiss
                        if abs(value.translation.height) > 100 || abs(value.velocity.height) > 500 {
                            onDismiss()
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.3)) {
                                self.dragOffset = .zero
                            }
                        }
                    }
                }
            }
    }
}
