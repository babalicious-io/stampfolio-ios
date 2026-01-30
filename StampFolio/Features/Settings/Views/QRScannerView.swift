//
//  QRScannerView.swift
//  StampFolio
//
//  QR code scanner for Bitcoin wallet addresses
//

import SwiftUI
import AVFoundation
import VisionKit

/// QR code scanner view using DataScannerViewController
struct QRScannerView: View {
    
    // MARK: - Properties
    
    let onScan: (String) -> Void
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var isScanning = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    DataScannerRepresentable(onScan: handleScan)
                        .ignoresSafeArea()
                    
                    // Scanning overlay - only when scanner is available
                    scanningOverlay
                } else {
                    unsupportedView
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Scanner Error", isPresented: $showError) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Scanning Overlay
    
    private var scanningOverlay: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 48))
                    .foregroundStyle(.primary)
                
                Text("Point your camera at the wallet QR code")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16) 
            .glassEffect(in: .rect(cornerRadius: 24))
            Spacer()
                .frame(height: 100)
        }
    }
    
    // MARK: - Unsupported View
    
    private var unsupportedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera")
                .font(.system(size: 64))
                .fontWeight(.regular)
                .foregroundStyle(.primary)
            
            Text("Camera Not Available")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Text("QR code scanning requires camera access. Please enable camera permissions in Settings.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .glassEffect(in: .capsule)
            }
        }
    }
    
    // MARK: - Handle Scan
    
    private func handleScan(_ result: String) {
        // Validate it looks like a Bitcoin address
        let cleanedResult = cleanBitcoinAddress(result)
        
        if isValidBitcoinPrefix(cleanedResult) {
            onScan(cleanedResult)
        }
    }
    
    private func cleanBitcoinAddress(_ input: String) -> String {
        var result = input
        
        // Remove bitcoin: URI prefix
        if result.lowercased().hasPrefix("bitcoin:") {
            result = String(result.dropFirst(8))
        }
        
        // Remove query parameters
        if let queryIndex = result.firstIndex(of: "?") {
            result = String(result[..<queryIndex])
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func isValidBitcoinPrefix(_ address: String) -> Bool {
        let validPrefixes = ["1", "3", "bc1q", "bc1p", "BC1Q", "BC1P"]
        return validPrefixes.contains { address.hasPrefix($0) }
    }
}

// MARK: - DataScanner Representable

struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        try? uiViewController.startScanning()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var hasScanned = false
        
        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            processItem(item)
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasScanned, let item = addedItems.first else { return }
            processItem(item)
        }
        
        private func processItem(_ item: RecognizedItem) {
            guard !hasScanned else { return }
            
            switch item {
            case .barcode(let barcode):
                if let value = barcode.payloadStringValue {
                    hasScanned = true
                    onScan(value)
                }
            default:
                break
            }
        }
    }
}

// MARK: - Preview

#Preview {
    QRScannerView { result in
        print("Scanned: \(result)")
    }
}
