import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Tur kayitlarini disari cikarma: CSV dosyasi ve siteye gotururen QR.
enum LapExport {
    static let siteURL = "https://f1dash-app.vercel.app"

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

    /// Paylasim sayfasina verilecek gecici dosya.
    static func csvFile(_ laps: [CompletedLap]) -> URL? {
        let name = "f1dash-laps-\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try csv(laps).write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    /// Sitenin okudugu kompakt bicim: tur:sure:s1:s2:s3, virgulle ayrilir.
    /// QR'a sigmasi icin son turlarla sinirlanir.
    static func webURL(_ laps: [CompletedLap], limit: Int = 30) -> URL? {
        let recent = laps.suffix(limit)
        guard !recent.isEmpty else { return URL(string: siteURL) }
        let payload = recent.map {
            "\($0.number):\($0.timeMS):\($0.sector1MS):\($0.sector2MS):\($0.sector3MS)"
        }.joined(separator: ",")
        return URL(string: "\(siteURL)/#l=\(payload)")
    }

    static func qrImage(for url: URL) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "L"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
