import CoolBoardCore
import XCTest

final class IORegistryThermalReaderTests: XCTestCase {
    func testConvertsAppleSmartBatteryTemperatureToCelsius() {
        XCTAssertEqual(IORegistryThermalReader.celsius(fromAppleSmartBatteryRawValue: 3072), 30.72, accuracy: 0.001)
        XCTAssertEqual(IORegistryThermalReader.celsius(fromAppleSmartBatteryRawValue: 3400), 34.0, accuracy: 0.001)
    }
}
