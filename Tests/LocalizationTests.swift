import XCTest
@testable import ApexDash

/// Guards translations added through the String Catalog: every language must
/// translate every key, keep the same placeholders, and resolve through `Strings`.
final class LocalizationTests: XCTestCase {

    private func table(_ code: String) throws -> [String: String] {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "Localizable", ofType: "strings",
                                                  inDirectory: nil, forLocalization: code),
                                 "no Localizable.strings for \(code)")
        return try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
    }

    private func placeholders(_ text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "%[0-9]+\\$@|%@")
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .map { String(text[Range($0.range, in: text)!]) }
            .sorted()
    }

    func testEveryLanguageTranslatesEveryKey() throws {
        let english = try table("en")
        XCTAssertGreaterThan(english.count, 50)
        let languages = AppLanguage.available
        XCTAssertTrue(languages.contains(.english))
        for language in languages where language != .english {
            let other = try table(language.code)
            for (key, value) in english {
                let translated = try XCTUnwrap(other[key], "\(language.code) is missing \"\(key)\"")
                XCTAssertFalse(translated.isEmpty, "\(language.code) has an empty \"\(key)\"")
                XCTAssertEqual(placeholders(translated), placeholders(value),
                               "\(language.code) \"\(key)\" has different placeholders")
            }
        }
    }

    func testStringsFillPlaceholders() {
        let strings = Strings(language: .english)
        XCTAssertEqual(strings.addressChanged(from: "10.0.0.2", to: "10.0.0.3"),
                       "IP CHANGED: 10.0.0.2 → 10.0.0.3. Update the address in the game.")
        XCTAssertEqual(Strings(language: AppLanguage(code: "tr")).waitingForData, "VERİ BEKLENİYOR")
    }

    func testUnknownPreferenceFallsBackToPhoneLanguage() {
        XCTAssertEqual(AppLanguage.resolve("xx"), AppLanguage.systemDefault)
        XCTAssertEqual(AppLanguage.resolve("tr").code, "tr")
    }
}
