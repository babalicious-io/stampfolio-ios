//
//  Gradients.swift
//  StampFolio
//
//  Reusable gradient definitions for consistent styling
//

import SwiftUI

extension ShapeStyle where Self == LinearGradient {
    /// Standard stamp gradient - purple to orange with black center
    static var stampCardBackgroundGradient: LinearGradient {
        LinearGradient(
            stops: [
                Gradient.Stop(color: .purple, location: 0),
                Gradient.Stop(color: .black, location: 0.2),
                Gradient.Stop(color: .black, location: 0.9),
                Gradient.Stop(color: .orange, location: 1)
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }
}
