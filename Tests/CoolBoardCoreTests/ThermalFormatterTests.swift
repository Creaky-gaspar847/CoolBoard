import CoolBoardCore
import XCTest

final class ThermalFormatterTests: XCTestCase {
    func testFormatsUnavailableSensorValues() {
        let reading = SensorReading(
            id: "missing",
            key: "N/A",
            displayName: "Missing",
            category: .unknown,
            value: nil,
            unit: "C",
            source: .unavailable
        )

        XCTAssertEqual(ThermalFormatters.sensorValue(reading), "--")
    }

    func testFormatsStaleAge() {
        let now = Date()
        let old = now.addingTimeInterval(-8)
        XCTAssertEqual(ThermalFormatters.ageDescription(snapshotDate: old, now: now), "8s ago")
    }
}
