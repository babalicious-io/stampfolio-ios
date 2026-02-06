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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Wallet.addedDate, order: .reverse) private var wallets: [Wallet]
    
    // MARK: - State
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("showWalletIcons") private var showWalletIcons = false
    @AppStorage("showOrdinals") private var showOrdinals = true
    @AppStorage("showCounterparty") private var showCounterparty = true
    @AppStorage("showStamps") private var showStamps = true
    @State private var protocolOrder: [ProtocolType] = []
    @State private var editingWallet: Wallet?
    @State private var protocolEditMode: EditMode = .inactive
    
    // MARK: - Body
    
    var body: some View {
        @Bindable var viewModel = viewModel
        
        NavigationStack {
            List {
                // Theme Section
                Section {
                    themeToggle
                } header: {
                    Text("Appearance")
                }
                
                // Protocols Section
                Section {
                    ForEach(protocolOrder) { protocolType in
                        protocolRow(for: protocolType)
                    }
                    .onMove(perform: moveProtocol)
                } header: {
                    protocolSectionHeader
                }
                
                // Wallets Section
                Section {
                    if !wallets.isEmpty {
                        ForEach(wallets) { wallet in
                            WalletRow(wallet: wallet)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        editingWallet = wallet
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.orange)
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
                    walletIconToggle
                }
                
                // About Section
                Section {
                    aboutRow
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
    
    // MARK: - Theme Toggle
    
    private var themeToggle: some View {
        Toggle(isOn: $isDarkMode) {
            HStack(spacing: isDarkMode ? 14 : 8) {
                Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                    .foregroundStyle(.orange)
                Text(isDarkMode ? "Dark Mode" : "Light Mode")
            }
        }
        .tint(.orange)
        .accessibilityLabel(isDarkMode ? "Dark mode toggle" : "Light mode toggle")
        .accessibilityValue(isDarkMode ? "On" : "Off")
        .accessibilityHint("Double tap to toggle theme")
    }
    
    // MARK: - Protocol Section Header
    
    private var protocolSectionHeader: some View {
        HStack {
            Text("Protocols")
            Spacer()
            Button {
                protocolEditMode = protocolEditMode.isEditing ? .inactive : .active
            } label: {
                Text(protocolEditMode.isEditing ? "Done" : "Reorder")
                    .font(.caption)
                    .textCase(.none)
                    .foregroundStyle(protocolEditMode.isEditing ? Color.orange : Color.orange.opacity(0.7))
            }
        }
    }
    
    // MARK: - Protocol Row
    
    /// Single stable view structure for both normal and reorder modes.
    /// View identity must stay the same for .onMove drag handles to work.
    private func protocolRow(for protocolType: ProtocolType) -> some View {
        HStack(spacing: 14) {
            Image(systemName: protocolType.icon)
                .foregroundStyle(.orange)
            Text(protocolEditMode.isEditing
                 ? protocolType.rawValue
                 : (toggleState(for: protocolType) ? "Display \(protocolType.rawValue)" : "Hide \(protocolType.rawValue)"))
            Spacer()
            if !protocolEditMode.isEditing {
                Toggle("", isOn: toggleBinding(for: protocolType))
                    .labelsHidden()
                    .tint(.orange)
            }
        }
        .frame(minHeight: 34)
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
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.orange)
                Text("Add Wallet")
                    .foregroundStyle(.orange)
            }
        }
        .accessibilityLabel("Add wallet")
        .accessibilityHint("Opens a form to add a new Bitcoin wallet")
    }
    
    // MARK: - Wallet Icon Toggle
    
    private var walletIconToggle: some View {
        Toggle(isOn: $showWalletIcons) {
            HStack(spacing: 14) {
                Image(systemName: "wallet.bifold.fill")
                    .foregroundStyle(.orange)
                Text(showWalletIcons ? "Display Wallet Icon" : "Hide Wallet Icon")    
            }
        }
        .tint(.orange)
        .accessibilityLabel(showWalletIcons ? "Display wallet icon toggle" : "Hide wallet icon toggle")
        .accessibilityValue(showWalletIcons ? "On" : "Off")
        .accessibilityHint(showWalletIcons ? "Double tap to toggle wallet icon display on stamp cards" : "Double tap to toggle wallet icon hide on stamp cards")
    }
    
    // MARK: - About Row
    
    private var aboutRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BitArt")
                    .font(.headline)
                Spacer()
                Text("v1.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text("A portfolio viewer for Bitcoin Art")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Link(destination: URL(string: "https://stampchain.io")!) {
                HStack {
                    Text("Powered by Stampchain.io")
                        .font(.caption)
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                }
                .foregroundStyle(.orange)
            }
            .accessibilityLabel("Visit Stampchain.io")
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Actions
    
    private func deleteWallet(_ wallet: Wallet) {
        viewModel.deleteWallet(wallet, context: modelContext)
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
    let wallet: Wallet
    
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
            HStack {
                Image(systemName: "wallet.bifold.fill")
                    .font(.body)
                    .foregroundStyle(wallet.walletColor.color)
                
                Text(displayName)
                    .font(.body)
                
                Spacer()
                
                Text(wallet.addressType.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.orange.secondary)
            }
            
            HStack {
                Text(wallet.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                if let count = wallet.cachedStampCount {
                    Text("\(count) stamps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Wallet \(wallet.displayName)")
        .accessibilityValue("\(wallet.cachedStampCount ?? 0) stamps")
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(SettingsViewModel())
        .modelContainer(for: Wallet.self, inMemory: true)
}
