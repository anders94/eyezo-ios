import Foundation
import Network
import Combine

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    // nil until the first path update arrives, so launch logic can
    // distinguish "unknown" from "confirmed offline"
    @Published private(set) var isConnected: Bool?

    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isConnected = connected
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }
}
