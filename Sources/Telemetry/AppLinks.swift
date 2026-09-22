import Foundation

/// Public addresses of the project.
enum AppLinks {
    static let repository = URL(string: "https://github.com/bekir1184/ApexDash")!
    static let site = URL(string: "https://www.apexdash.pro")!

    /// The App Store id of the published app; the "Rate" button in Settings
    /// stays hidden while it is nil.
    static let appStoreID: String? = "6813199957"

    static var writeReview: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") }
    }
}
