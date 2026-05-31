//
//  SettingsView.swift
//  StampFolio
//
//  Settings screen with theme toggle and wallet management
//

import SwiftUI
import SwiftData

/// Settings view with theme toggle and wallet management
struct SettingsView: View {
    
    // MARK: - Environment
    
    @Environment(SettingsViewModel.self) private var viewModel
    @Environment(CollectionViewModel.self) private var collectionViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WalletConfig.addedDate, order: .reverse) private var wallets: [WalletConfig]
    
    // MARK: - State
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("showWalletIcons") private var showWalletIcons = false
    @AppStorage("showOrdinals") private var showOrdinals = true
    @AppStorage("showCounterparty") private var showCounterparty = true
    @AppStorage("showStamps") private var showStamps = true
    @AppStorage("colorScheme") private var colorSchemeRawValue = AppColorScheme.satoshiOrange.rawValue
    @AppStorage("performancePreview") private var performancePreview = true
    @AppStorage("slideshowInterval") private var slideshowInterval = 5
    @State private var protocolOrder: [ProtocolType] = []
    @State private var editingWallet: WalletConfig?
    @State private var protocolEditMode: EditMode = .inactive
    @Environment(\.appColorScheme) private var appColorScheme
    
    // MARK: - Body
    
    var body: some View {
        @Bindable var viewModel = viewModel
        
        NavigationStack {
            List {
                // Theme Appearance Section
                Section {
                    themeDisplayToggle
                } header: {
                    Text("Theme Appearance")
                }
                
                // Color Scheme Section
                Section {
                    colorSchemePicker
                } header: {
                    Text("Color Scheme")
                }
                
                // Protocols Section
                Section {
                    ForEach(protocolOrder) { protocolType in
                        protocolRow(for: protocolType)
                    }
                    .onMove(perform: moveProtocol)
                } header: {
                    contentDisplayToggle
                }
                
                // Wallets Section
                Section {
                    if !wallets.isEmpty {
                        ForEach(wallets) { wallet in
                            WalletRow(wallet: wallet)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        Task {
                                            await collectionViewModel.fetchStampMetadata(for: wallet, allWallets: wallets, forceStampsRefresh: true)
                                        }
                                    } label: {
                                        Label("Refresh", systemImage: "arrow.clockwise")
                                    }
                                    .tint(appColorScheme.primary)
                                    
                                    Button {
                                        editingWallet = wallet
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.gray)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteWallet(wallet)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    
                    addWalletButton
                } header: {
                    Text("Wallets")
                }
                
                // Wallet Icons Section
                Section {
                    walletDisplayToggle
                }
                
                // Performance Section
                Section {
                    slideshowPicker
                    previewDisplayToggle
                } header: {
                    Text("Performance")
                } footer: {
                    Text("Display small static preview images instead of animated GIFs in grids and lists to save resources.")
                }
                
                // About Section
                Section {
                    aboutText
                } header: {
                    Text("About")
                }
            }
            .environment(\.editMode, $protocolEditMode)
            .listSectionSpacing(16)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadProtocolOrder()
            }
            .sheet(isPresented: $viewModel.showAddWallet) {
                AddWalletView()
            }
            .sheet(item: $editingWallet) { wallet in
                EditWalletView(wallet: wallet)
            }
            .alert("Notice", isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                if let message = viewModel.alertMessage {
                    Text(message)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
    
    // MARK: - Theme Appearance Toggle
    
    private var themeDisplayToggle: some View {
        Toggle(isOn: $isDarkMode) {
            HStack(spacing: isDarkMode ? 14 : 12) {
                Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                    .foregroundStyle(appColorScheme.primary)
                Text(isDarkMode ? "Dark Mode" : "Light Mode")
            }
        }
        .tint(appColorScheme.primary)
        .padding(.vertical, 4)
        .accessibilityLabel(isDarkMode ? "Dark mode toggle" : "Light mode toggle")
        .accessibilityValue(isDarkMode ? "On" : "Off")
        .accessibilityHint("Double tap to toggle theme")
    }
    
    // MARK: - Protocol Section Header
    
    private var contentDisplayToggle: some View {
        HStack(spacing: 14) {
            Text("Content")
            Spacer()
            Button {
                protocolEditMode = protocolEditMode.isEditing ? .inactive : .active
            } label: {
                Text(protocolEditMode.isEditing ? "Done" : "Reorder")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(protocolEditMode.isEditing ? appColorScheme.primary : appColorScheme.primary.opacity(0.8))
            }
        }
    }
    
    // MARK: - Protocol Row
    
    /// Single stable view structure for both normal and reorder modes.
    /// View identity must stay the same for .onMove drag handles to work.
    private func protocolRow(for protocolType: ProtocolType) -> some View {
        HStack(spacing: 14) {
            Image(systemName: protocolType.icon)
                .foregroundStyle(appColorScheme.primary)
            Text(protocolEditMode.isEditing
                 ? protocolType.rawValue
                 : (toggleState(for: protocolType) ? "Display \(protocolType.rawValue)" : "Hide \(protocolType.rawValue)"))
            Spacer()
            if !protocolEditMode.isEditing {
                Toggle("", isOn: toggleBinding(for: protocolType))
                    .labelsHidden()
                    .tint(appColorScheme.primary)
            }
        }
        .frame(minHeight: 28)
        .onChange(of: toggleState(for: protocolType)) { _, _ in
            enforceProtocolSelection()
        }
    }
    
    private func toggleBinding(for protocolType: ProtocolType) -> Binding<Bool> {
        switch protocolType {
        case .stamps: return $showStamps
        case .ordinals: return $showOrdinals
        case .counterparty: return $showCounterparty
        }
    }
    
    private func toggleState(for protocolType: ProtocolType) -> Bool {
        switch protocolType {
        case .stamps: return showStamps
        case .ordinals: return showOrdinals
        case .counterparty: return showCounterparty
        }
    }
    
    // MARK: - Add Wallet Button
    
    private var addWalletButton: some View {
        Button {
            viewModel.showAddWallet = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(appColorScheme.primary)
                Text("Add Wallet")
                    .foregroundStyle(appColorScheme.primary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityLabel("Add wallet")
        .accessibilityHint("Opens a form to add a new Bitcoin wallet")
    }
    
    // MARK: - Color Scheme Row
    
    private var colorSchemePicker: some View {
        let currentScheme = AppColorScheme(rawValue: colorSchemeRawValue) ?? .satoshiOrange
        
        return HStack(spacing: 14) {
            Image(systemName: "person.fill")
                .foregroundStyle(appColorScheme.primary)
            Text(currentScheme.displayName)
                .foregroundStyle(.primary)
            
            Spacer()
            
            HStack(spacing: 16) {
                ForEach(AppColorScheme.allCases) { scheme in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            colorSchemeRawValue = scheme.rawValue
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(scheme.primary)
                                .frame(width: 32, height: 32)
                            
                            if currentScheme == scheme {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(isDarkMode ? .black : .white)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(scheme.displayName) color scheme")
                    .accessibilityHint(currentScheme == scheme ? "Selected" : "Select this color scheme")
                }
            }
        }
    }
    
    // MARK: - Slideshow Interval Picker
    
    private static let slideshowIntervals = [3, 5, 7, 9, 10, 12, 15, 20, 25, 30, 45, 60, 90, 120]
    
    private var slideshowPicker: some View {
        HStack(spacing: 14) {
            Image(systemName: "play.square.stack.fill")
                .foregroundStyle(appColorScheme.primary)
            Picker("Slideshow", selection: $slideshowInterval) {
                ForEach(Self.slideshowIntervals, id: \.self) { secs in
                    Text("\(secs)s")
                        .tag(secs)
                }
            }
            .pickerStyle(.menu)
            .tint(appColorScheme.primary)
        }
        .padding(.vertical, 4)
        .accessibilityLabel("Slideshow interval")
        .accessibilityHint("Choose how long each stamp is displayed during a slideshow")
    }
    
    // MARK: - Animated Preview Toggle
    
    private var previewDisplayToggle: some View {
        Toggle(isOn: $performancePreview) {
            HStack(spacing: 14) {
                Image(systemName: performancePreview ? "play.square.fill" : "square.fill")
                    .foregroundStyle(appColorScheme.primary)
                Text(performancePreview ? "Animated GIF" : "Static Preview Image")
            }
        }
        .tint(appColorScheme.primary)
        .padding(.vertical, 4)
        .accessibilityLabel(performancePreview ? "Animated image" : "Static preview image")
        .accessibilityValue(performancePreview ? "On" : "Off")
        .accessibilityHint("Double tap to toggle between animated and static preview images")
    }
    
    // MARK: - Wallet Icon Toggle
    
    private var walletDisplayToggle: some View {
        Toggle(isOn: $showWalletIcons) {
            HStack(spacing: 12) {
                Image(systemName: "wallet.bifold.fill")
                    .foregroundStyle(appColorScheme.primary)
                Text(showWalletIcons ? "Show Wallet Icon" : "Hide Wallet Icon")    
            }
        }
        .tint(appColorScheme.primary)
        .padding(.vertical, 4)
        .accessibilityLabel(showWalletIcons ? "Display wallet icon toggle" : "Hide wallet icon toggle")
        .accessibilityValue(showWalletIcons ? "On" : "Off")
        .accessibilityHint(showWalletIcons ? "Double tap to toggle wallet icon display on stamp cards" : "Double tap to toggle wallet icon hide on stamp cards")
    }
    
    // MARK: - About Row
    
    private var aboutText: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                Text("StampFolio")
                    .font(.headline)
                Spacer()
                Text("v1.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text("A portfolio viewer for Bitcoin Stamps")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Link(destination: URL(string: "https://stampchain.io")!) {
                HStack(spacing: 14) {
                    Text("Powered by Stampchain.io")
                        .font(.caption)
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                }
                .foregroundStyle(appColorScheme.primary)
            }
            .accessibilityLabel("Visit Stampchain.io")
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Actions
    
    private func deleteWallet(_ wallet: WalletConfig) {
        viewModel.deleteWallet(wallet, context: modelContext, collectionViewModel: collectionViewModel)
    }
    
    private func enforceProtocolSelection() {
        if !showStamps && !showOrdinals && !showCounterparty {
            showStamps = true
        }
    }
    
    private func loadProtocolOrder() {
        if let data = UserDefaults.standard.data(forKey: "protocolOrder"),
           let decoded = try? JSONDecoder().decode([ProtocolType].self, from: data) {
            protocolOrder = decoded
        } else {
            protocolOrder = [.stamps, .ordinals, .counterparty]
        }
    }
    
    private func saveProtocolOrder() {
        if let encoded = try? JSONEncoder().encode(protocolOrder) {
            UserDefaults.standard.set(encoded, forKey: "protocolOrder")
            NotificationCenter.default.post(name: .protocolOrderDidChange, object: nil)
        }
    }
    
    private func moveProtocol(from source: IndexSet, to destination: Int) {
        protocolOrder.move(fromOffsets: source, toOffset: destination)
        saveProtocolOrder()
    }
}

// MARK: - Wallet Row

struct WalletRow: View {
    let wallet: WalletConfig
    
    @Environment(\.appColorScheme) private var appColorScheme
    
    private var displayName: String {
        let name = wallet.displayName
        if name.count > 24 {
            let prefix = name.prefix(8)
            let suffix = name.suffix(8)
            return "\(prefix)...\(suffix)"
        }
        return name
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Image(systemName: "wallet.bifold.fill")
                    .font(.body)
                    .foregroundStyle(wallet.walletColor.color)
                
                Text(displayName)
                    .font(.body)
                
                Spacer()
                
                Text(wallet.addressType.rawValue)
                    .font(.caption2)
                    .foregroundStyle(appColorScheme.secondary)
            }
            
            Text(wallet.address)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Wallet \(wallet.displayName)")
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(SettingsViewModel())
        .environment(CollectionViewModel())
        .modelContainer(for: WalletConfig.self, inMemory: true)
}
