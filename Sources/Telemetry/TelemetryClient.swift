import Foundation
import Network

/// UDP 20777'yi dinler, gelen paketleri cozer ve ekrandaki modeli gunceller.
///
/// Not: iOS 14+ broadcast/multicast trafigini almak icin Apple'dan onayli
/// `com.apple.developer.networking.multicast` yetkisi ister. Bu yuzden oyunda
/// "UDP Broadcast Mode = Off" birakip "UDP IP Address" alanina iPhone'un IP
/// adresini yazmak gerekiyor (unicast). Uygulama kendi IP'sini ekranda gosterir.
@MainActor
final class TelemetryClient: ObservableObject {
    @Published private(set) var dash = DashboardModel()
    @Published private(set) var status: ConnectionStatus = .idle
    @Published private(set) var localIP: String = "-"
    @Published private(set) var packetsPerSecond: Int = 0

    enum ConnectionStatus: Equatable {
        case idle
        case listening
        case receiving
        case failed(String)
    }

    let port: NWEndpoint.Port

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var lastPacketDate: Date?
    private var packetCounter = 0
    private var tickTimer: Timer?

    init(port: UInt16 = 20777) {
        self.port = NWEndpoint.Port(rawValue: port)!
        self.localIP = Self.currentWiFiAddress() ?? "-"
    }

    func start() {
        guard listener == nil else { return }
        do {
            let params = NWParameters.udp
            params.allowLocalEndpointReuse = true
            let listener = try NWListener(using: params, on: port)
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready: self?.status = .listening
                    case .failed(let error): self?.status = .failed(error.localizedDescription)
                    case .cancelled: self?.status = .idle
                    default: break
                    }
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                connection.start(queue: .global(qos: .userInitiated))
                Task { @MainActor in self?.connections.append(connection) }
                self?.receive(on: connection)
            }
            listener.start(queue: .global(qos: .userInitiated))
            self.listener = listener
            self.localIP = Self.currentWiFiAddress() ?? "-"
            startTicker()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func stop() {
        tickTimer?.invalidate()
        tickTimer = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        listener?.cancel()
        listener = nil
        status = .idle
    }

    nonisolated private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            if let data, !data.isEmpty {
                Task { @MainActor in self?.handle(data) }
            }
            if error == nil {
                self?.receive(on: connection)
            }
        }
    }

    private func handle(_ data: Data) {
        guard let header = PacketHeader(data), header.packetFormat == 2026 else { return }
        packetCounter += 1
        lastPacketDate = Date()
        status = .receiving

        let idx = header.playerCarIndex
        switch header.packetID {
        case .carTelemetry:
            guard let t = CarTelemetry(data: data, carIndex: idx) else { return }
            dash.apply(t)
        case .carTelemetry2:
            guard let t = CarTelemetry2(data: data, carIndex: idx) else { return }
            dash.apply(t)
        case .carStatus:
            guard let s = CarStatus(data: data, carIndex: idx) else { return }
            dash.apply(s)
        default:
            break
        }
    }

    private func startTicker() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.packetsPerSecond = self.packetCounter
                self.packetCounter = 0
                if let last = self.lastPacketDate, Date().timeIntervalSince(last) > 2, self.status == .receiving {
                    self.status = .listening
                    self.dash = DashboardModel()
                }
            }
        }
    }

    /// Oyunun "UDP IP Address" alanina yazilacak adres.
    static func currentWiFiAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: interface.ifa_name)
            guard name == "en0" else { continue }
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
            address = String(cString: hostname)
        }
        return address
    }
}
