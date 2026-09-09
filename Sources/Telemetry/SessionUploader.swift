import Foundation

/// Turlari laptoptaki sayfaya tasiyan yukleyici. Sayfa bir oturum kimligi
/// uretip QR olarak gosterir; telefon o kimlikle gonderir, sayfa yoklar.
@MainActor
final class SessionUploader: ObservableObject {
    @Published private(set) var lastUploadDate: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isSending = false

    private var inFlight: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?
    /// Bu oturumda basariyla gonderilmis tur izleri (oturum kimligi + tur no).
    private var sentTraces: Set<String> = []

    /// Bir gonderimde tasinan her sey.
    struct Payload {
        var laps: [CompletedLap]
        var traces: [LapTrace]
        var session: SessionInfo
    }

    /// QR'daki adresten oturum kimligini cikarir.
    static func sessionID(from scanned: String) -> String? {
        if let url = URLComponents(string: scanned),
           let value = url.queryItems?.first(where: { $0.name == "s" })?.value {
            return normalise(value)
        }
        return normalise(scanned)
    }

    private static func normalise(_ value: String) -> String? {
        let clean = value.uppercased().filter { $0.isLetter || $0.isNumber }
        return (4...12).contains(clean.count) ? String(clean) : nil
    }

    /// Tur bitisleri arasinda da duzenli gonderim: sayfa "bagli" gorunur ve
    /// basarisiz bir gonderim kendiliginden telafi edilir.
    func startHeartbeat(interval: TimeInterval = 20, payload: @escaping () -> Payload,
                        sessionID: @escaping () -> String) {
        heartbeat?.cancel()
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard let self else { return }
                let id = sessionID()
                guard !id.isEmpty else { continue }
                await self.upload(payload(), sessionID: id)
            }
        }
    }

    func stopHeartbeat() {
        heartbeat?.cancel()
        heartbeat = nil
    }

    func send(_ payload: Payload, sessionID: String) {
        guard !sessionID.isEmpty, !payload.laps.isEmpty else { return }
        inFlight?.cancel()
        inFlight = Task { [weak self] in
            await self?.upload(payload, sessionID: sessionID)
        }
    }

    /// Once tur listesi (kucuk), sonra henuz gitmemis tur izleri teker teker.
    private func upload(_ payload: Payload, sessionID: String) async {
        guard !payload.laps.isEmpty else { return }
        let laps = payload.laps.suffix(200).map { lap -> [String: Any] in
            ["lap": lap.number, "time": lap.timeMS,
             "sectors": [lap.sector1MS, lap.sector2MS, lap.sector3MS],
             "trace": payload.traces.contains { $0.number == lap.number }]
        }
        let session = payload.session
        var index: [String: Any] = [
            "id": sessionID,
            "best": payload.laps.map(\.timeMS).min() ?? 0,
            "laps": laps,
            "track": ["id": session.trackID, "length": session.trackLength,
                      "weather": session.weather, "trackTemp": session.trackTemperature,
                      "airTemp": session.airTemperature, "sessionType": session.sessionType]
        ]
        guard await post(index, sessionID: sessionID) else { return }

        for trace in payload.traces where !sentTraces.contains("\(sessionID)/\(trace.number)") {
            index = ["id": sessionID, "trace": trace.payload()]
            guard await post(index, sessionID: sessionID) else { return }
            sentTraces.insert("\(sessionID)/\(trace.number)")
        }
    }

    private func post(_ payload: [String: Any], sessionID: String) async -> Bool {
        guard let url = URL(string: "\(LapExport.siteURL)/api/session"),
              let body = try? JSONSerialization.data(withJSONObject: payload)
        else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 20

        isSending = true
        defer { isSending = false }
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                lastError = "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                return false
            }
            lastUploadDate = Date()
            lastError = nil
            return true
        } catch {
            if !Task.isCancelled { lastError = error.localizedDescription }
            return false
        }
    }
}
