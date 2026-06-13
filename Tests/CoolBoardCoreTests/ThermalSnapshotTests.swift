import CoolBoardCore
import XCTest

final class ThermalSnapshotTests: XCTestCase {
    func testCountsDetectedFansFromSnapshot() {
        let snapshot = ThermalSnapshot(
            sensors: [],
            fans: [
                FanState(id: 0, name: "System Fan", currentRPM: 2400, minRPM: 1200, maxRPM: 6200, mode: .systemAuto)
            ],
            thermalState: .nominal
        )

        XCTAssertEqual(snapshot.detectedFanCount, 1)
    }

    func testTemperatureSensorsOnlyIncludeAvailableCelsiusReadings() {
        let now = Date()
        let snapshot = ThermalSnapshot(
            sensors: [
                SensorReading(id: "cpu", key: "TC0P", displayName: "CPU", category: .cpu, value: 55.4, unit: "C", source: .smc, timestamp: now),
                SensorReading(id: "missing", key: "TG0P", displayName: "GPU", category: .gpu, value: nil, unit: "C", source: .smc, timestamp: now),
                SensorReading(id: "cores", key: "HW-NCPU", displayName: "CPU Cores", category: .cpu, value: 10, unit: "cores", source: .system, timestamp: now),
                SensorReading(id: "memory", key: "HW-MEM", displayName: "Unified Memory", category: .system, value: 18, unit: "GB", source: .system, timestamp: now)
            ],
            fans: [],
            thermalState: .nominal
        )

        XCTAssertEqual(snapshot.detectedTemperatureSensorCount, 1)
        XCTAssertEqual(snapshot.temperatureSensors.map(\.id), ["cpu"])
    }
}
