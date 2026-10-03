import XCTest
@testable import ApexDash

final class TyreTempSourceTests: XCTestCase {
    private var dash: DashboardModel {
        var m = DashboardModel()
        m.tyreSurfaceTemps = [96, 98, 92, 94]
        m.tyreInnerTemps = [101, 103, 97, 99]
        return m
    }

    func testSurfaceIsTheBigNumberByDefault() {
        XCTAssertEqual(TyreTempSource.resolve(""), .surface)
        XCTAssertEqual(TyreTempSource.surface.primary(dash), [96, 98, 92, 94])
        XCTAssertEqual(TyreTempSource.surface.secondary(dash), [101, 103, 97, 99])
    }

    func testCoreSwapsTheTwo() {
        XCTAssertEqual(TyreTempSource.resolve("core"), .core)
        XCTAssertEqual(TyreTempSource.core.primary(dash), [101, 103, 97, 99])
        XCTAssertEqual(TyreTempSource.core.secondary(dash), [96, 98, 92, 94])
    }

    func testUnknownSettingsFallBackToSurface() {
        XCTAssertEqual(TyreTempSource.resolve("carcass"), .surface)
    }
}
