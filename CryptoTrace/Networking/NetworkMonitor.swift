import Foundation
import Network
import Combine

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected: Bool = true
    @Published private(set) var isConstrainedOrExpensive: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "network.monitor.queue")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                // Treat constrained (Low Data Mode) or expensive (cellular/satellite) as "weak"
                self?.isConstrainedOrExpensive = path.isConstrained || path.isExpensive
            }
        }
        monitor.start(queue: queue)
    }
}

