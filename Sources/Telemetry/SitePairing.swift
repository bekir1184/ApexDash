import Foundation

/// Pairs the phone with a browser that opened apexdash.pro.
///
/// The lap analysis runs on the phone itself (see `LocalAnalysisServer`). The
/// public site is only a meeting point: it shows a code and a QR, the phone
/// scans it and publishes its local address to an ntfy.sh topic named after
/// that code, and the page moves the browser to the phone. Laps never leave
/// the local network, and nothing is stored on a server.
@MainActor
final class SitePairing: ObservableObject {
    @Published private(set) var lastPairedDate: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isSending = false

    /// The phone's analysis address, for example `http://192.168.1.20:8777/`.
    var localAddress: () -> String? = { nil }

    private var inFlight: Task<Void, Never>?
    private var watcher: Task<Void, Never>?
    /// Code and address of the last successful announcement; unchanged pairs are not resent.
    private var lastPaired: String?

    /// Extracts the session code from the URL encoded in the site's QR.
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

    /// Re-announces the address when it changes, for example after moving to
    /// another Wi-Fi network. Nothing is sent while code and address stay the same.
    func startWatching(interval: TimeInterval = 20, sessionID: @escaping () -> String) {
        watcher?.cancel()
        watcher = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard let self else { return }
                let id = sessionID()
                guard !id.isEmpty else { continue }
                await self.announce(sessionID: id, force: false)
            }
        }
    }

    /// Announces the address for a freshly scanned code.
    func pair(sessionID: String) {
        guard !sessionID.isEmpty else { return }
        inFlight?.cancel()
        inFlight = Task { [weak self] in
            await self?.announce(sessionID: sessionID, force: true)
        }
    }

    private func announce(sessionID: String, force: Bool) async {
        guard let local = localAddress() else {
            lastError = "Wi-Fi"
            return
        }
        let key = "\(sessionID)|\(local)"
        guard force || key != lastPaired else { return }
        if await publish(local, sessionID: sessionID) { lastPaired = key }
    }

    /// Posts the address to the ntfy.sh topic the page listens on. ntfy.sh is a
    /// free relay that needs no account; the topic name is unique to the code.
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
            lastPairedDate = Date()
            lastError = nil
            return true
        } catch {
            if !Task.isCancelled { lastError = error.localizedDescription }
            return false
        }
    }
}
