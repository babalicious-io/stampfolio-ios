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
    @Environment(\.appColorScheme) private var appColorScheme
    
    // MARK: - Properties
    
    let wallet: Wallet
    
    // MARK: - State
    
    @State private var walletName: String = ""
    @State private var selectedColor: WalletColor = .gray
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
                    HStack(spacing: 16) {
                        ForEach(WalletColor.allCases) { color in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedColor = color
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 40, height: 40)
                                    
                                    if selectedColor == color {
                                        Image(systemName: "checkmark")
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.white)
                                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(color.displayName) color")
                            .accessibilityHint(selectedColor == color ? "Selected" : "Select this color")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } header: {
                    Text("Wallet Color")
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
                            .foregroundStyle(appColorScheme.primary)
                    }
                } header: {
                    Text("Wallet Details")
                }
            }
            .navigationTitle("Edit Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Cancel")
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveWalletName()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(appColorScheme.primary)
                    .fontWeight(.semibold)
                    .accessibilityLabel("Save changes")
                }
            }
            .onAppear {
                walletName = wallet.label ?? ""
                selectedColor = wallet.walletColor
                isNameFocused = false
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveWalletName() {
        // Update wallet label (empty string becomes nil)
        wallet.label = walletName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : walletName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Update wallet color
        wallet.colorName = selectedColor.rawValue
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            // Handle error silently for now
            print("Failed to save wallet: \(error)")
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
