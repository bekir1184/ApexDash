import Foundation

/// Exporting laps: a CSV file and the site address.
enum LapExport {
    static let siteURL = "https://www.apexdash.pro"
    /// The bare address shown in guides and screens.
    static var siteHost: String {
        siteURL.replacingOccurrences(of: "https://", with: "")
    }

    static func csv(_ laps: [CompletedLap]) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = ["lap,time_ms,sector1_ms,sector2_ms,sector3_ms,invalid,recorded_at"]
        for lap in laps {
            lines.append([
                "\(lap.number)", "\(lap.timeMS)",
                "\(lap.sector1MS)", "\(lap.sector2MS)", "\(lap.sector3MS)",
                lap.invalid ? "1" : "0",
                formatter.string(from: lap.date)
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    /// A temporary file handed to the share sheet.
    static func csvFile(_ laps: [CompletedLap]) -> URL? {
        let name = "apexdash-laps-\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try csv(laps).write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

}
