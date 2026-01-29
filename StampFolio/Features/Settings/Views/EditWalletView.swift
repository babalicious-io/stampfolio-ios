//
//  EditWalletView.swift
//  StampFolio
//
//  Form for editing wallet name/label
//

import SwiftUI
import SwiftData

/// View for editing a wallet's name/label
struct EditWalletView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let wallet: Wallet
    
    // MARK: - State
    
    @State private var walletName: String = ""
    @FocusState private var isNameFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Wallet Name (Optional)", text: $walletName)
                        .textInputAutocapitalization(.words)
                        .focused($isNameFocused)
                        .accessibilityLabel("Wallet name")
                        .accessibilityHint("Enter a custom name for this wallet")
                } header: {
                    Text("Wallet Name")
                } 
                
                Section {
                    ColorPicker("Color", selection: $walletColor)
                        .textInputAutocapitalization(.words)
                        .focused($isColorFocused)
                        .accessibilityLabel("Wallet color")
                        .accessibilityHint("Select a color for this wallet")
                } header: {
                    Text("WalletColor")
                } 

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Address")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(wallet.address)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    HStack {
                        Text("Type")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(wallet.addressType.rawValue)
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                } header: {
                    Text("Wallet Details")
                }
            }
            .navigationTitle("Edit Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveWalletName()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                walletName = wallet.label ?? ""
                isNameFocused = true
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveWalletName() {
        // Update wallet label (empty string becomes nil)
        wallet.label = walletName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : walletName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            // Handle error silently for now
            print("Failed to save wallet name: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Wallet.self, configurations: config)
    let wallet = Wallet(address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh", label: "My Wallet")
    container.mainContext.insert(wallet)
    
    return EditWalletView(wallet: wallet)
        .modelContainer(container)
}
