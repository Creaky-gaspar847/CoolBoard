import CoolBoardCore
import XCTest

final class FanStateTests: XCTestCase {
    func testClampsManualRPMToSafeFanRange() {
        let fan = FanState(id: 0, name: "System Fan", currentRPM: 2000, minRPM: 1200, maxRPM: 6200, mode: .systemAuto)

        XCTAssertEqual(fan.clampedRPM(-1), 0)
        XCTAssertEqual(fan.clampedRPM(0), 0)
        XCTAssertEqual(fan.clampedRPM(200), 1200)
        XCTAssertEqual(fan.clampedRPM(3000), 3000)
        XCTAssertEqual(fan.clampedRPM(9000), 6200)
    }

    func testCoolingModeLabelsManualAndAuto() {
        XCTAssertEqual(CoolingMode.systemAuto.label, "Auto")
        XCTAssertEqual(CoolingMode.manual(targetRPM: 3400).label, "Manual 3400 RPM")
    }

    func testMapsPowerPercentToRPMRange() {
        let fan = FanState(id: 0, name: "System Fan", currentRPM: 2000, minRPM: 1200, maxRPM: 6200, mode: .systemAuto)

        XCTAssertEqual(fan.rpm(forPowerPercent: 0), 0)
        XCTAssertEqual(fan.rpm(forPowerPercent: 10), 1700)
        XCTAssertEqual(fan.rpm(forPowerPercent: 40), 3200)
        XCTAssertEqual(fan.rpm(forPowerPercent: 100), 6200)
    }

    func testMapsRPMToPowerPercent() {
        let fan = FanState(id: 0, name: "System Fan", currentRPM: 2000, minRPM: 1200, maxRPM: 6200, mode: .systemAuto)

        XCTAssertEqual(fan.powerPercent(forRPM: 0), 0)
        XCTAssertEqual(fan.powerPercent(forRPM: 1700), 10)
        XCTAssertEqual(fan.powerPercent(forRPM: 3200), 40)
        XCTAssertEqual(fan.powerPercent(forRPM: 6200), 100)
    }

    func testFanControlAvailabilityDefaultsToAvailable() {
        let fan = FanState(id: 0, name: "System Fan", currentRPM: 2000, minRPM: 1200, maxRPM: 6200, mode: .systemAuto)

        XCTAssertTrue(fan.isControllable)
        XCTAssertNil(fan.controlMessage)
    }

    func testFanControlAvailabilityCanDisableManualControl() {
        let fan = FanState(
            id: 0,
            name: "System Fan",
            currentRPM: nil,
            minRPM: 1200,
            maxRPM: 6200,
            mode: .systemAuto,
            controlAvailability: .unavailable("AppleSMC fan control is unavailable.")
        )

        XCTAssertFalse(fan.isControllable)
        XCTAssertEqual(fan.controlMessage, "AppleSMC fan control is unavailable.")
    }
}
