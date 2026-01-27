//
//  NetworkMonitor.swift
//  StampFolio
//
//  Network connectivity monitoring using NWPathMonitor
//

import Foundation
import Network
import Observation

/// Monitors network connectivity state using NWPathMonitor
@Observable
final class NetworkMonitor {
    
    // MARK: - Properties
    
    /// Whether the device has network connectivity
    private(set) var isConnected: Bool = true
    
    /// Current connection type (if connected)
    private(set) var connectionType: ConnectionType = .unknown
    
    /// Whether the connection is expensive (cellular/hotspot)
    private(set) var isExpensive: Bool = false
    
    /// Whether the connection is constrained (Low Data Mode)
    private(set) var isConstrained: Bool = false
    
    // MARK: - Private Properties
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.stampfolio.networkmonitor")
    
    // MARK: - Types
    
    enum ConnectionType: String {
        case wifi = "Wi-Fi"
        case cellular = "Cellular"
        case ethernet = "Ethernet"
        case unknown = "Unknown"
    }
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// Start monitoring network connectivity
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateConnectionStatus(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    /// Stop monitoring network connectivity
    func stop() {
        monitor.cancel()
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func updateConnectionStatus(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        
        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
    }
}

// MARK: - Preview Support

extension NetworkMonitor {
    
    /// Create a network monitor with preset state for previews
    static func preview(isConnected: Bool = true) -> NetworkMonitor {
        let monitor = NetworkMonitor()
        // Note: In previews, the actual network state will be used
        // This is just for documentation
        return monitor
    }
}
