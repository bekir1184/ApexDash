import XCTest
@testable import ApexDash

final class SpeedUnitTests: XCTestCase {
    func testKilometresAreShownUnchanged() {
        XCTAssertEqual(SpeedUnit.kph.value(fromKPH: 0), 0)
        XCTAssertEqual(SpeedUnit.kph.value(fromKPH: 317), 317)
    }

    func testMilesAreConvertedAndRounded() {
        XCTAssertEqual(SpeedUnit.mph.value(fromKPH: 0), 0)
        XCTAssertEqual(SpeedUnit.mph.value(fromKPH: 100), 62)      // 62.14
        XCTAssertEqual(SpeedUnit.mph.value(fromKPH: 200), 124)     // 124.27
        XCTAssertEqual(SpeedUnit.mph.value(fromKPH: 317), 197)     // 196.97, rounds up
    }

    func testStoredSettingResolves() {
        XCTAssertEqual(SpeedUnit.resolve("mph"), .mph)
        XCTAssertEqual(SpeedUnit.resolve("kph"), .kph)
        // Anything else, including the empty "follow my region" setting.
        XCTAssertEqual(SpeedUnit.resolve(""), SpeedUnit.regional)
        XCTAssertEqual(SpeedUnit.resolve("knots"), SpeedUnit.regional)
    }

    func testLabelsMatchTheUnit() {
        XCTAssertEqual(SpeedUnit.kph.label, "KM/H")
        XCTAssertEqual(SpeedUnit.kph.compactLabel, "KPH")
        XCTAssertEqual(SpeedUnit.kph.smallLabel, "km/h")
        XCTAssertEqual(SpeedUnit.mph.label, "MPH")
        XCTAssertEqual(SpeedUnit.mph.compactLabel, "MPH")
        XCTAssertEqual(SpeedUnit.mph.smallLabel, "mph")
    }
}
