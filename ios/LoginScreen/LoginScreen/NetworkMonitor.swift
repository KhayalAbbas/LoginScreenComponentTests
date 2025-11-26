import Foundation
import Network
import Combine

/// Protocol for monitoring network connectivity.
/// Provides reactive publisher of online/offline state.
protocol NetworkMonitorProtocol {
    /// Publisher that emits true when device is online, false when offline.
    /// Emits current state immediately upon subscription.
    var isOnline: AnyPublisher<Bool, Never> { get }
}

/// iOS implementation of NetworkMonitorProtocol.
/// Uses NWPathMonitor to monitor network state changes.
class NetworkMonitor: NetworkMonitorProtocol {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private let isOnlineSubject = CurrentValueSubject<Bool, Never>(true)
    
    /// Publisher that emits network connectivity state.
    /// Listens to network path updates and emits state changes reactively.
    var isOnline: AnyPublisher<Bool, Never> {
        isOnlineSubject.eraseToAnyPublisher()
    }
    
    /// Initializes the network monitor and starts observing network state.
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            self?.isOnlineSubject.send(isConnected)
        }
        monitor.start(queue: queue)
        
        // Check initial state
        let currentPath = monitor.currentPath
        isOnlineSubject.send(currentPath.status == .satisfied)
    }
    
    deinit {
        monitor.cancel()
    }
}

