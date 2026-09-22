import Foundation
import Network

/// Listens for UDP telemetry, passes each datagram to the active game and
/// publishes the result to the dashboards.
///
/// iOS only delivers broadcast and multicast traffic to apps with Apple's
/// `com.apple.developer.networking.multicast` entitlement. Games therefore send
/// straight to the phone's address (unicast), which the app shows on screen.
@MainActor
final class TelemetryClient: ObservableObject, TelemetrySink {
    @Published var dash = DashboardModel()
    @Published private(set) var status: ConnectionStatus = .idle
    @Published private(set) var localIP: String = "-"
    /// Set when the Wi-Fi address changed, so the address in the game needs updating.
    @Published private(set) var previousIP: String?
    @Published private(set) var packetsPerSecond: Int = 0
    /// Completed lap traces for the analysis page.
    @Published private(set) var lapTraces: [LapTrace] = []
    @Published private(set) var sessionInfo = SessionInfo()
    /// Set when the game sends a format the player did not select, for example "F1 25".
    @Published private(set) var formatWarning: String?
    /// True while the built-in demo drive feeds the dashboards.
    @Published private(set) var isDemoRunning = false

    enum ConnectionStatus: Equatable {
        case idle
        case listening
        case receiving
        case failed(String)
    }

    private(set) var port: NWEndpoint.Port
    /// The game whose telemetry is decoded.
    private(set) var game: TelemetryGame

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var lastPacketDate: Date?
    private let pathMonitor = NWPathMonitor()
    private var monitoring = false
    private var packetCounter = 0
    private var tickTimer: Timer?
    private var demo: TelemetryDemo?
    private var demoTimer: Timer?

    init(port: UInt16 = 20777, game: TelemetryGame? = nil) {
        self.port = NWEndpoint.Port(rawValue: port)!
        self.game = game ?? F1Game()
        self.localIP = Self.currentWiFiAddress() ?? "-"
    }

    /// Switches to another game or game setting and starts from a clean state.
    func use(_ game: TelemetryGame) {
        stopDemo()
        self.game = game
        dash = DashboardModel()
        lapTraces = []
        sessionInfo = SessionInfo()
        formatWarning = nil
    }

    /// Rebuilds the listener when the port changes.
    func update(port newPort: UInt16) {
        guard newPort != port.rawValue, let endpoint = NWEndpoint.Port(rawValue: newPort) else { return }
        let wasRunning = listener != nil
        stop()
        port = endpoint
        if wasRunning { start() }
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
            startPathMonitor()
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

    // MARK: - Demo drive

    /// Starts a simulated session of the current game. Real telemetry arriving
    /// from the network stops it.
    func startDemo() {
        guard !isDemoRunning, let demo = game.makeDemo() else { return }
        clearSession()
        self.demo = demo
        isDemoRunning = true
        if tickTimer == nil { startTicker() }
        demoTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let demo = self.demo else { return }
                demo.nextDatagrams().forEach { self.handle($0) }
            }
        }
    }

    func stopDemo() {
        guard isDemoRunning else { return }
        demoTimer?.invalidate()
        demoTimer = nil
        demo = nil
        isDemoRunning = false
        clearSession()
        status = listener == nil ? .idle : .listening
    }

    private func clearSession() {
        game.reset()
        dash = DashboardModel()
        lapTraces = []
        sessionInfo = SessionInfo()
        lastPacketDate = nil
    }

    // MARK: - TelemetrySink

    func publish(lapTraces: [LapTrace]) {
        self.lapTraces = lapTraces
    }

    func publish(session: SessionInfo) {
        var session = session
        if isDemoRunning { session.trackName = "Demo" }
        if session != sessionInfo { sessionInfo = session }
    }

    func reportUnexpectedFormat(_ description: String?) {
        if formatWarning != description { formatWarning = description }
    }

    // MARK: - Network

    /// Rebuilds the listener when Wi-Fi changes, and remembers the old address.
    private func startPathMonitor() {
        guard !monitoring else { return }
        monitoring = true
        pathMonitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor in self?.handlePathChange() }
        }
        pathMonitor.start(queue: .global(qos: .utility))
    }

    private func handlePathChange() {
        let address = Self.currentWiFiAddress() ?? "-"
        if localIP != "-" && localIP != address { previousIP = localIP }
        localIP = address

        // A socket bound to the old address receives nothing; start over.
        guard listener != nil else { return }
        connections.forEach { $0.cancel() }
        connections.removeAll()
        listener?.cancel()
        listener = nil
        start()
    }

    func acknowledgeAddressChange() { previousIP = nil }

    nonisolated private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            if let data, !data.isEmpty {
                Task { @MainActor in
                    // The real game takes over from the demo.
                    if self?.isDemoRunning == true { self?.stopDemo() }
                    self?.handle(data)
                }
            }
            if error == nil {
                self?.receive(on: connection)
            }
        }
    }

    private func handle(_ data: Data) {
        guard game.consume(data, sink: self) else { return }
        packetCounter += 1
        lastPacketDate = Date()
        if status != .receiving { status = .receiving }
    }

    private func startTicker() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.packetsPerSecond = self.packetCounter
                self.packetCounter = 0
                self.game.tick(sink: self)
                if let last = self.lastPacketDate, Date().timeIntervalSince(last) > 2, self.status == .receiving {
                    self.status = .listening
                    self.dash = DashboardModel()
                }
            }
        }
    }

    /// The address to enter as "UDP IP Address" in the game.
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
