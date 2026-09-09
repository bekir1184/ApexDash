import Foundation

/// Turlari laptoptaki sayfaya tasiyan yukleyici. Sayfa bir oturum kimligi
/// uretip QR olarak gosterir; telefon o kimlikle gonderir, sayfa yoklar.
@MainActor
final class SessionUploader: ObservableObject {
    @Published private(set) var lastUploadDate: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isSending = false

    private var inFlight: Task<Void, Never>?

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

    func send(laps: [CompletedLap], sessionID: String) {
        guard !sessionID.isEmpty, !laps.isEmpty else { return }
        inFlight?.cancel()
        inFlight = Task { [weak self] in
            await self?.upload(laps: laps, sessionID: sessionID)
        }
    }

    private func upload(laps: [CompletedLap], sessionID: String) async {
        guard let url = URL(string: "\(LapExport.siteURL)/api/session") else { return }
        let payload: [String: Any] = [
            "id": sessionID,
            "best": laps.map(\.timeMS).min() ?? 0,
            "laps": laps.suffix(200).map { lap in
                ["lap": lap.number,
                 "time": lap.timeMS,
                 "sectors": [lap.sector1MS, lap.sector2MS, lap.sector3MS]]
            }
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 10

        isSending = true
        defer { isSending = false }
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                lastError = "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                return
            }
            lastUploadDate = Date()
            lastError = nil
        } catch {
            if !Task.isCancelled { lastError = error.localizedDescription }
        }
    }
}
