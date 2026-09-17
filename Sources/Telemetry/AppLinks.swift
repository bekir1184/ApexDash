import Foundation

/// Public addresses of the project.
enum AppLinks {
    static let repository = URL(string: "https://github.com/bekir1184/ApexDash")!
    static let site = URL(string: "https://www.apexdash.pro")!

    /// The App Store id, known once the app is created in App Store Connect.
    /// While it is nil, the "Rate" button stays hidden.
    static let appStoreID: String? = nil

    static var writeReview: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") }
    }
}
