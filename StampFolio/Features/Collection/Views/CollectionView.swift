//
//  CollectionView.swift
//  StampFolio
//
//  Main collection view displaying stamps in a grid
//

import SwiftUI
import SwiftData

/// Main collection view showing stamps from all wallets
struct CollectionView: View {
    
    // MARK: - Environment
    
    @Environment(CollectionViewModel.self) private var viewModel
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Wallet.addedDate, order: .reverse) private var wallets: [Wallet]
    
    // MARK: - State
    
    @State private var showOfflineBanner = false
    @State private var showSettings = false
    
    // MARK: - Layout
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    // MARK: - Body
    
    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ZStack {
                // Background
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                content
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.purple)
                        }
                        
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundStyle(.purple)
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityHint("Opens the settings screen")
                    }
                }
            }
            .task {
                await viewModel.fetchStamps(for: wallets)
            }
            .refreshable {
                await viewModel.refreshStamps(for: wallets)
            }
            .onChange(of: wallets.count) { _, _ in
                Task {
                    await viewModel.fetchStamps(for: wallets)
                }
            }
            .onChange(of: networkMonitor.isConnected) { _, isConnected in
                showOfflineBanner = !isConnected
            }
            .fullScreenCover(item: $viewModel.selectedStamp) { displayStamp in
                StampDetailView(stamp: displayStamp.stamp)
            }
            .sheet(item: $viewModel.metadataStamp) { displayStamp in
                StampMetadataPopup(stamp: displayStamp.stamp)
                    .presentationDetents([.medium])
                    .presentationBackground(.ultraThinMaterial)
            }
            .fullScreenCover(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .stampchainBackground()
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        if wallets.isEmpty {
            emptyWalletsView
        } else if viewModel.isLoading && viewModel.stamps.isEmpty {
            loadingView
        } else if viewModel.showError {
            errorView
        } else if viewModel.stamps.isEmpty {
            noStampsView
        } else {
            stampsGrid
        }
    }
    
    // MARK: - Empty Wallets View
    
    private var emptyWalletsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 64))
                .foregroundStyle(.purple)
            
            Text("No Wallets Added")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Text("Add a Bitcoin wallet to view your stamp collection")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showSettings = true
            } label: {
                Text("Add Wallet")
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .glassButton()
            }
            .accessibilityLabel("Add a Bitcoin wallet")
            .accessibilityHint("Opens the settings screen to add a wallet")
        }
        .padding()
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.purple)
            
            Text("Loading stamps...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundStyle(.red)
            
            Text("Unable to Load Stamps")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button {
                Task {
                    await viewModel.refreshStamps(for: wallets)
                }
            } label: {
                Text("Try Again")
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .glassButton()
            }
            .accessibilityLabel("Retry loading stamps")
        }
        .padding()
    }
    
    // MARK: - No Stamps View
    
    private var noStampsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.purple)
            
            Text("No Stamps Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Text("Your wallets don't contain any Bitcoin Stamps yet")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
    
    // MARK: - Stamps Grid
    
    private var stampsGrid: some View {
        ScrollView {
            // Offline banner
            if showOfflineBanner {
                offlineBanner
            }
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.stamps) { displayStamp in
                    StampCardView(
                        displayStamp: displayStamp,
                        onTap: {
                            viewModel.selectedStamp = displayStamp
                        },
                        onInfoTap: {
                            viewModel.metadataStamp = displayStamp
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - Offline Banner
    
    private var offlineBanner: some View {
        HStack {
            Image(systemName: "wifi.slash")
            Text("You're offline. Showing cached content.")
        }
        .font(.caption)
        .foregroundStyle(.primary)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color.orange.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding()
    }
}

// MARK: - Bindable Extension for Optional Binding

extension Bindable where Value: AnyObject {
    subscript<T>(dynamicMember keyPath: ReferenceWritableKeyPath<Value, T?>) -> Binding<T?> {
        Binding(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { self.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
}

// MARK: - Preview

#Preview {
    CollectionView()
        .environment(CollectionViewModel())
        .environment(NetworkMonitor())
        .modelContainer(for: Wallet.self, inMemory: true)
}
