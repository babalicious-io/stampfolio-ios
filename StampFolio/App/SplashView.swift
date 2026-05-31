//
//  SplashView.swift
//  StampFolio
//
//  Full-screen launch splash shown briefly before the main UI appears.
//

import SwiftUI

struct SplashView: View {

    // MARK: - State

    @State private var opacity: Double = 0
    @State private var scale: Double = 0.7

    // MARK: - Body

    var body: some View {
        Color.black
            .ignoresSafeArea()
            .overlay {
                Image("StampFolio-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.2)) {
                    opacity = 1
                    scale = 1
                }
            }
    }
}

// MARK: - Preview

#Preview {
    SplashView()
}
