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
    /// The latest session on disk: the current one once it has a lap, or the
    /// previous one after a launch. Shown while the live session has no laps.
    @Published private(set) var savedSession: StoredSession?

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
    /// The game's address for games that `connectsToGame`: "192.168.1.20" or "192.168.1.20:9000".
    private(set) var gameAddress = ""
    /// The socket to a game that `connectsToGame`; its replies arrive on it too.
    private var outbound: NWConnection?
    private let store: LapStore?
    private var sessionID = LapStore.newID()
    private var savedLapCount = 0

    /// - Parameter store: where sessions are kept; `nil` keeps everything in memory.
    init(port: UInt16 = 20777, game: TelemetryGame? = nil, store: LapStore? = LapStore()) {
        self.port = NWEndpoint.Port(rawValue: port)!
        self.game = game ?? F1Game()
        self.store = store
        self.localIP = Self.currentWiFiAddress() ?? "-"
        self.savedSession = store?.latest()
    }

    // MARK: - What the laps screen and the analysis page show

    /// True when the live session has no laps yet and the saved one is shown instead.
    var showsSavedSession: Bool { dash.completedLaps.isEmpty && savedSession != nil }

    var shownLaps: [CompletedLap] {
        showsSavedSession ? savedSession?.laps ?? [] : dash.completedLaps
    }

    var shownTraces: [LapTrace] {
        showsSavedSession ? savedSession?.traces ?? [] : lapTraces
    }

    var shownSession: SessionInfo {
        showsSavedSession ? savedSession?.session ?? sessionInfo : sessionInfo
    }

    var shownBestSectorMS: [Int] {
        showsSavedSession ? savedSession?.bestSectorMS ?? [0, 0, 0] : dash.bestSectorMS
    }

    /// Switches to another game or game setting and starts from a clean state.
    func use(_ game: TelemetryGame) {
        stopDemo()
        self.game = game
        dash = DashboardModel()
        lapTraces = []
        sessionInfo = SessionInfo()
        formatWarning = nil
        startNewSession()
        connectToGame()
    }

    /// Sets where to reach a game that `connectsToGame`, and reconnects.
    func update(gameAddress newAddress: String) {
        let trimmed = newAddress.trimmingCharacters(in: .whitespaces)
        guard trimmed != gameAddress else { return }
        gameAddress = trimmed
        connectToGame()
    }

    /// Opens the socket to the game when the active game needs one, the
    /// address is set and the client is running.
    private func connectToGame() {
        outbound?.cancel()
        outbound = nil
        guard type(of: game).connectsToGame, listener != nil,
              let (host, port) = Self.endpoint(gameAddress, defaultPort: type(of: game).defaultPort)
        else { return }
        let connection = NWConnection(host: host, port: port, using: .udp)
        connection.start(queue: .global(qos: .userInitiated))
        receive(on: connection)
        outbound = connection
        // Lets the game register right away instead of on the next tick.
        game.tick(sink: self)
    }

    /// Splits "host" or "host:port" into an endpoint.
    static func endpoint(_ address: String, defaultPort: UInt16) -> (NWEndpoint.Host, NWEndpoint.Port)? {
        let parts = address.split(separator: ":", omittingEmptySubsequences: false)
        guard let hostPart = parts.first, !hostPart.isEmpty, parts.count <= 2 else { return nil }
        var port = defaultPort
        if parts.count == 2 {
            guard let value = UInt16(parts[1]), value > 0 else { return nil }
            port = value
        }
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else { return nil }
        return (NWEndpoint.Host(String(hostPart)), endpointPort)
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
            connectToGame()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func stop() {
        outbound?.cancel()
        outbound = nil
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
        startNewSession()
    }

    // MARK: - Saving laps

    /// The next completed lap goes to a new file; the last saved session stays on show until then.
    private func startNewSession() {
        sessionID = LapStore.newID()
        savedLapCount = 0
    }

    /// Saves the session each time a lap is completed.
    private func saveIfLapCompleted() {
        let laps = dash.completedLaps
        guard let store, laps.count > savedLapCount else { return }
        #if !DEBUG
        // Demo laps would push real sessions off the disk. Debug builds keep them for testing.
        if isDemoRunning { return }
        #endif
        savedLapCount = laps.count
        let session = StoredSession(id: sessionID, gameID: type(of: game).id, savedAt: Date(),
                                    session: sessionInfo, laps: laps, traces: lapTraces)
        savedSession = session
        store.save(session)
    }

    // MARK: - TelemetrySink

    func send(_ data: Data) {
        outbound?.send(content: data, completion: .contentProcessed { _ in })
    }

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
        saveIfLapCompleted()
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
