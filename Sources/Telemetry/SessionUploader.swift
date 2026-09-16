import Foundation

/// Sitedeki eslestirme. Analiz artik telefonda calisir (`LocalAnalysisServer`);
/// canli site yalnizca ilk baglanti icindir: sayfa bir kod ve QR gosterir,
/// telefon o koda kendi yerel adresini bir kez bildirir, sayfa tarayiciyi
/// telefona yonlendirir. Turlar ve izler buluta hic gitmez; adres ya da kod
/// degismedikce tekrar yazilmaz.
@MainActor
final class SessionUploader: ObservableObject {
    @Published private(set) var lastUploadDate: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isSending = false

    /// Telefonun yerel analiz adresi, ornegin `http://192.168.1.20:8777/`.
    var localAddress: () -> String? = { nil }

    private var inFlight: Task<Void, Never>?
    private var watcher: Task<Void, Never>?
    /// Son basariyla bildirilen kod + adres; ayniysa yeniden yazilmaz.
    private var lastPaired: String?

    /// Bir gonderimde tasinan her sey; yerel sunucu da ayni yapiyi kullanir.
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

    /// Tur listesi: yerel sunucunun `/api/session` cevabi.
    static func index(_ payload: Payload, id: String) -> [String: Any] {
        let laps = payload.laps.suffix(200).map { lap -> [String: Any] in
            let trace = payload.traces.first { $0.number == lap.number }
            var entry: [String: Any] = [
                "lap": lap.number, "time": lap.timeMS,
                "sectors": [lap.sector1MS, lap.sector2MS, lap.sector3MS],
                "trace": trace != nil
            ]
            if let top = trace?.samples.map(\.speedKPH).max() { entry["vmax"] = top }
            return entry
        }
        let session = payload.session
        return [
            "id": id,
            "best": payload.laps.map(\.timeMS).min() ?? 0,
            "laps": laps,
            "track": ["id": session.trackID, "length": session.trackLength,
                      "weather": session.weather, "trackTemp": session.trackTemperature,
                      "airTemp": session.airTemperature, "sessionType": session.sessionType]
        ]
    }

    /// Wi-Fi adresi degisirse (baska aga gecis) eslesme kendiliginden yenilenir.
    /// Ag istegi yalnizca kod ya da adres degistiginde yapilir.
    func startHeartbeat(interval: TimeInterval = 20, payload: @escaping () -> Payload,
                        sessionID: @escaping () -> String) {
        watcher?.cancel()
        watcher = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard let self else { return }
                let id = sessionID()
                guard !id.isEmpty else { continue }
                await self.pair(sessionID: id, force: false)
            }
        }
    }

    func stopHeartbeat() {
        watcher?.cancel()
        watcher = nil
    }

    /// Eslesmeyi bildirir. Kullanici eliyle istediginde (QR, "simdi gonder")
    /// ayni adres olsa da yeniden yazilir.
    func send(_ payload: Payload, sessionID: String) {
        guard !sessionID.isEmpty else { return }
        inFlight?.cancel()
        inFlight = Task { [weak self] in
            await self?.pair(sessionID: sessionID, force: true)
        }
    }

    private func pair(sessionID: String, force: Bool) async {
        guard let local = localAddress() else {
            lastError = "Wi-Fi"
            return
        }
        let key = "\(sessionID)|\(local)"
        guard force || key != lastPaired else { return }
        if await publish(local, sessionID: sessionID) { lastPaired = key }
    }

    /// Adres, sayfanin dinledigi ntfy.sh konusuna yazilir (hesapsiz, ucretsiz
    /// bildirim aktarici). Konu adi oturum koduna ozeldir.
    private func publish(_ address: String, sessionID: String) async -> Bool {
        guard let url = URL(string: "https://ntfy.sh/apexdash-\(sessionID)") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(address.utf8)
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
