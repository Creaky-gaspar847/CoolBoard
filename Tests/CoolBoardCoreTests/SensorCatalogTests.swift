import CoolBoardCore
import XCTest

final class SensorCatalogTests: XCTestCase {
    func testCategorizesExpectedSensorFamilies() {
        XCTAssertEqual(SensorCatalog.category(for: "TC0P", displayName: "CPU Die"), .cpu)
        XCTAssertEqual(SensorCatalog.category(for: "TG0P", displayName: "GPU Proximity"), .gpu)
        XCTAssertEqual(SensorCatalog.category(for: "TSG1", displayName: "GPU TSG1"), .gpu)
        XCTAssertEqual(SensorCatalog.category(for: "TA0P", displayName: "AirPort"), .airport)
        XCTAssertEqual(SensorCatalog.category(for: "PMGR", displayName: "Power Manager"), .power)
        XCTAssertEqual(SensorCatalog.category(for: "BAT0", displayName: "Battery Pack"), .battery)
        XCTAssertEqual(SensorCatalog.category(for: "????", displayName: "Mystery"), .unknown)
    }

    func testAppleSiliconCatalogCoversPlanSensorFamilies() {
        let categories = Set(AppleSiliconSensorCatalog.expected.map(\.category))

        XCTAssertTrue(categories.contains(.cpu))
        XCTAssertTrue(categories.contains(.gpu))
        XCTAssertTrue(categories.contains(.airport))
        XCTAssertTrue(categories.contains(.power))
        XCTAssertTrue(categories.contains(.battery))
    }
}
