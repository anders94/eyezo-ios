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
                guard let self = self else { return }

                let wasConnected = self.isConnected
                self.isConnected = connected

                // Coming back online (or starting up online): push any
                // offline watch progress to the servers it came from
                if connected && wasConnected != true {
                    await WatchProgressSyncService.shared.syncIfNeeded()
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }
}
