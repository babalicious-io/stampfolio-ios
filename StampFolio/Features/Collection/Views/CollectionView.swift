//
//  CollectionView.swift
//  StampFolio
//
//  Main collection view displaying stamps in a grid
//

import SwiftUI
import SwiftData

/// View mode for displaying stamps
enum ViewMode: String, Codable {
    case normalGrid = "normal_grid"
    case denseGrid = "dense_grid"
    case list = "list"
}

/// Main collection view showing stamps from all wallets
struct CollectionView: View {
    
    // MARK: - Environment
    
    @Environment(CollectionViewModel.self) private var viewModel
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Query(sort: \Wallet.addedDate, order: .reverse) private var wallets: [Wallet]
    
    // MARK: - State
    
    @State private var showOfflineBanner = false
    @State private var showSettings = false
    @State private var viewSize: CGSize = .zero
    @AppStorage("showWalletIcons") private var showWalletIcons = false
    @AppStorage("viewMode") private var viewMode: ViewMode = .normalGrid
    
    // MARK: - Layout
    
    /// Dynamic grid columns using native adaptive sizing with device awareness
    /// iPhone: 2 columns (normal) / 3 columns (dense)
    /// iPad: 3-4 columns (normal) / 4-5 columns (dense)
    private var columns: [GridItem] {
        // List mode uses single flexible column
        if viewMode == .list {
            return [GridItem(.flexible(), spacing: 16)]
        }
        
        // Simple device detection for optimal column counts
        let isIPad = horizontalSizeClass == .regular
        
        // Set minimums that achieve desired column counts while remaining adaptive
        let minSize: CGFloat
        if isIPad {
            minSize = viewMode == .denseGrid ? 110 : 150  // iPad: 4-5 columns dense, 3-4 normal
        } else {
            minSize = viewMode == .denseGrid ? 100 : 165  // iPhone: 3 columns dense, 2 normal
        }
        
        return [GridItem(.adaptive(minimum: minSize, maximum: 300), spacing: 16)]
    }
    
    // MARK: - Computed Properties
    
    /// Dynamic icon for Stamp # sort based on current sort option
    private var stampSortIcon: String {
        switch viewModel.currentSortOption {
        case .stampAscending: return "arrow.up"
        case .stampDescending: return "arrow.down"
        default: return "arrow.down"
        }
    }
    
    /// Dynamic icon for Artist sort based on current sort option
    private var artistSortIcon: String {
        switch viewModel.currentSortOption {
        case .artistAZ: return "AZ"
        case .artistZA: return "ZA"
        default: return "AZ"
        }
    }
    
    /// Dynamic icon for Balance sort based on current sort option
    private var balanceSortIcon: String {
        switch viewModel.currentSortOption {
        case .balanceAscending: return "arrow.up"
        case .balanceDescending: return "arrow.down"
        default: return "arrow.down"
        }
    }
    
    /// Dynamic icon for Wallet sort based on current sort option
    private var walletSortIcon: String {
        switch viewModel.currentSortOption {
        case .walletAZ: return "AZ"
        case .walletZA: return "ZA"
        default: return "AZ"
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Background
                    Color(uiColor: .systemBackground)
                        .ignoresSafeArea()
                    
                    content
                }
                .onAppear {
                    viewSize = geometry.size
                }
                .onChange(of: geometry.size) { _, newSize in
                    viewSize = newSize
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("View Mode", selection: $viewMode) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.title3)
                            .tag(ViewMode.normalGrid)
                            .accessibilityLabel("Normal grid")
                        
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.title3)
                            .tag(ViewMode.denseGrid)
                            .accessibilityLabel("Dense grid")
                        
                        Image(systemName: "rectangle.grid.1x3.fill")
                            .font(.title3)
                            .tag(ViewMode.list)
                            .accessibilityLabel("List view")
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .accessibilityLabel("View mode control")
                    .accessibilityValue(viewMode == .list ? "List view" : viewMode == .denseGrid ? "Dense grid layout" : "Normal grid layout")
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    // Sort menu
                    Menu {
                        // Stamp # toggle
                        Button {
                            viewModel.toggleSort(for: .stamp, wallets: wallets)
                        } label: {
                            Label("Stamp #", systemImage: stampSortIcon)
                        }
                        
                        // Artist toggle
                        Button {
                            viewModel.toggleSort(for: .artist, wallets: wallets)
                        } label: {
                            Label {
                                Text("Artist")
                            } icon: {
                                Text(artistSortIcon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.blue)
                            }
                        }
                        
                        // Balance toggle
                        Button {
                            viewModel.toggleSort(for: .balance, wallets: wallets)
                        } label: {
                            Label("Balance", systemImage: balanceSortIcon)
                        }
                        
                        // Wallet toggle (conditional)
                        if showWalletIcons {
                            Button {
                                viewModel.toggleSort(for: .wallet, wallets: wallets)
                            } label: {
                                Label {
                                    Text("Wallet")
                                } icon: {
                                    Text(walletSortIcon)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.title3)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Sort stamps")
                    .accessibilityHint("Choose how to sort your stamp collection")
                }
                
                ToolbarSpacer(.fixed)
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title3)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Opens the settings screen")
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
            .fullScreenCover(item: Bindable(viewModel).selectedStamp) { displayStamp in
                if let index = viewModel.stamps.firstIndex(where: { $0.id == displayStamp.id }) {
                    StampDetailView(
                        stamps: viewModel.stamps.map(\.stamp),
                        initialIndex: index
                    )
                }
            }
            .sheet(item: Bindable(viewModel).metadataStamp) { displayStamp in
                StampMetadataPopup(stamp: displayStamp.stamp)
                    .presentationDetents([.medium])
                    .presentationBackground(.ultraThinMaterial)
            }
            .fullScreenCover(isPresented: $showSettings) {
                SettingsView()
            }
        }
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
        ContentUnavailableView {
            Label("No Wallets Added", systemImage: "wallet.bifold")
        } description: {
            Text("Add a Bitcoin wallet to view your stamp collection")
        } actions: {
            Button("Add Wallet") {
                showSettings = true
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Add a Bitcoin wallet")
            .accessibilityHint("Opens the settings screen to add a wallet")
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1)
                .tint(.purple)
        }
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        ContentUnavailableView {
            Label("Unable to Load Stamps", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        } description: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        } actions: {
            Button("Try Again") {
                Task {
                    await viewModel.refreshStamps(for: wallets)
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Retry loading stamps")
        }
    }
    
    // MARK: - No Stamps View
    
    private var noStampsView: some View {
        ContentUnavailableView(
            "No Stamps Found",
            systemImage: "photo.on.rectangle.angled",
            description: Text("Your wallets don't contain any Stamps")
        )
    }
    
    // MARK: - Stamps Grid
    
    private var stampsGrid: some View {
        ScrollView {
            // Offline banner
            if showOfflineBanner {
                offlineBanner
            }
            
            if viewMode == .list {
                // List view mode
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.stamps) { displayStamp in
                        StampRowView(
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
            } else {
                // Grid view modes
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
        .glassEffect(.regular.tint(.orange).interactive(), in: .rect(cornerRadius: 8))
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
