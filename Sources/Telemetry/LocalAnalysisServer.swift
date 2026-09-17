import Foundation
import Network

/// Everything the analysis page shows: completed laps, their 20 Hz traces and
/// the session (track, weather).
struct SessionSnapshot {
    var laps: [CompletedLap]
    var traces: [LapTrace]
    var session: SessionInfo

    static let empty = SessionSnapshot(laps: [], traces: [], session: SessionInfo())

    /// The lap list returned by `/api/session`.
    func index() -> [String: Any] {
        let laps = self.laps.suffix(200).map { lap -> [String: Any] in
            let trace = traces.first { $0.number == lap.number }
            var entry: [String: Any] = [
                "lap": lap.number, "time": lap.timeMS,
                "sectors": [lap.sector1MS, lap.sector2MS, lap.sector3MS],
                "trace": trace != nil
            ]
            if let top = trace?.samples.map(\.speedKPH).max() { entry["vmax"] = top }
            return entry
        }
        return [
            "best": self.laps.map(\.timeMS).min() ?? 0,
            "laps": laps,
            "track": ["id": session.trackID, "name": session.trackName as Any? ?? NSNull(), "length": session.trackLength,
                      "weather": session.weather, "trackTemp": session.trackTemperature,
                      "airTemp": session.airTemperature, "sessionType": session.sessionType]
        ]
    }
}

/// A small HTTP server that lets any browser on the same Wi-Fi open the lap
/// analysis straight from the phone. The page and its data never touch the
/// internet; apexdash.pro is only used to find the phone (see `SitePairing`).
///
/// Routes:
/// - `/`, `/logo.svg`, `/qrcode.js`, `/apple-touch-icon.png`: the bundled site
/// - `/api/session`: lap list and session info
/// - `/api/session?lap=N`: the 20 Hz trace of one lap
@MainActor
final class LocalAnalysisServer: ObservableObject {
    static let port: UInt16 = 8777

    @Published private(set) var isRunning = false
    /// Addresses of browsers that requested data in the last few seconds. The
    /// page polls every two seconds, so a short silence means it has gone.
    @Published private(set) var viewers: [String] = []
    private var lastSeen: [String: Date] = [:]
    private var pruning: Task<Void, Never>?

    /// The data to serve; wired up by the root view.
    var snapshot: () -> SessionSnapshot = { .empty }

    private var listener: NWListener?
    private var version = ""
    private var updatedAt = Date()

    /// The address to open in a browser.
    func address(ip: String) -> String? {
        guard isRunning, ip != "-", !ip.isEmpty else { return nil }
        return "http://\(ip):\(Self.port)/"
    }

    func start() {
        guard listener == nil, let port = NWEndpoint.Port(rawValue: Self.port) else { return }
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let listener = try NWListener(using: params, on: port)
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready: self?.isRunning = true
                    case .failed, .cancelled:
                        // Allow a restart when the app returns from the background.
                        self?.isRunning = false
                        self?.listener = nil
                    default: break
                    }
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.accept(connection) }
            }
            listener.start(queue: .main)
            self.listener = listener
            pruning?.cancel()
            pruning = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                    self?.pruneViewers()
                }
            }
        } catch {
            isRunning = false
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    // MARK: - Requests

    private func accept(_ connection: NWConnection) {
        connection.start(queue: .main)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, done, error in
            Task { @MainActor in
                guard let self else { return }
                var buffer = buffer
                if let data { buffer.append(data) }
                if let end = buffer.range(of: Data("\r\n\r\n".utf8)) {
                    self.respond(to: buffer.subdata(in: 0..<end.lowerBound), on: connection)
                } else if done || error != nil || buffer.count > 64_000 {
                    connection.cancel()
                } else {
                    self.receive(on: connection, buffer: buffer)
                }
            }
        }
    }

    private func respond(to head: Data, on connection: NWConnection) {
        let line = String(decoding: head, as: UTF8.self).split(separator: "\r\n").first ?? ""
        let parts = line.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" || parts[0] == "HEAD" else {
            return send(status: "405 Method Not Allowed", type: "text/plain", body: Data(), on: connection)
        }
        let components = URLComponents(string: String(parts[1]))
        let path = components?.path ?? "/"
        let query = components?.queryItems ?? []

        switch path {
        case "/", "/index.html":
            file("index", "html", type: "text/html; charset=utf-8", on: connection)
        case "/logo.svg":
            file("logo", "svg", type: "image/svg+xml", on: connection)
        case "/qrcode.js":
            file("qrcode", "js", type: "application/javascript", on: connection)
        case "/apple-touch-icon.png":
            file("apple-touch-icon", "png", type: "image/png", on: connection)
        case "/api/session":
            noteViewer(connection)
            if let lap = query.first(where: { $0.name == "lap" })?.value.flatMap(Int.init) {
                trace(lap, on: connection)
            } else {
                index(on: connection)
            }
        default:
            send(status: "404 Not Found", type: "text/plain", body: Data("not found".utf8), on: connection)
        }
    }

    private func noteViewer(_ connection: NWConnection) {
        guard case let .hostPort(host, _) = connection.endpoint else { return }
        var address = "\(host)"
        if let percent = address.firstIndex(of: "%") { address = String(address[..<percent]) }
        lastSeen[address] = Date()
        pruneViewers()
    }

    private func pruneViewers() {
        let now = Date()
        lastSeen = lastSeen.filter { now.timeIntervalSince($0.value) < 8 }
        let current = lastSeen.keys.sorted()
        if current != viewers { viewers = current }
    }

    private func index(on connection: NWConnection) {
        let payload = snapshot()
        // The page only redraws when the version changes; being live is
        // implied by the poll succeeding.
        let current = "\(payload.laps.count)-\(payload.traces.count)-\(payload.session.trackID)-\(payload.laps.last?.timeMS ?? 0)"
        if current != version { version = current; updatedAt = Date() }
        var body = payload.index()
        body["local"] = true
        body["version"] = version
        body["updatedAt"] = ISO8601DateFormatter().string(from: updatedAt)
        json(body, on: connection)
    }

    private func trace(_ lap: Int, on connection: NWConnection) {
        guard let trace = snapshot().traces.first(where: { $0.number == lap }) else {
            return json(["error": "no trace"], status: "404 Not Found", on: connection)
        }
        json(trace.payload(), on: connection)
    }

    private func file(_ name: String, _ ext: String, type: String, on connection: NWConnection) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let data = try? Data(contentsOf: url) else {
            return send(status: "404 Not Found", type: "text/plain", body: Data(), on: connection)
        }
        send(status: "200 OK", type: type, body: data, on: connection)
    }

    private func json(_ object: Any, status: String = "200 OK", on connection: NWConnection) {
        let data = (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
        send(status: status, type: "application/json", body: data, on: connection)
    }

    private func send(status: String, type: String, body: Data, on connection: NWConnection) {
        let header = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\n"
            + "Cache-Control: no-store\r\nConnection: close\r\n\r\n"
        var response = Data(header.utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }
}
