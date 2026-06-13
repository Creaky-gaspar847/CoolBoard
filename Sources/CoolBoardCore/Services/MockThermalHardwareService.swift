import Foundation

public actor MockThermalHardwareService: ThermalHardwareServicing {
    private var fan = FanState(
        id: 0,
        name: "System Fan 0",
        currentRPM: 2120,
        minRPM: 1200,
        maxRPM: 6200,
        mode: .systemAuto
    )

    public init() {}

    public func fetchSnapshot() async -> ThermalSnapshot {
        let now = Date()
        return ThermalSnapshot(
            sensors: [
                SensorReading(id: "cpu-die", key: "TC0P", displayName: "CPU Die", category: .cpu, value: 48.8, unit: "C", source: .smc, timestamp: now),
                SensorReading(id: "gpu-proximity", key: "TG0P", displayName: "GPU Proximity", category: .gpu, value: 44.3, unit: "C", source: .smc, timestamp: now),
                SensorReading(id: "airport", key: "TA0P", displayName: "AirPort", category: .airport, value: 39.0, unit: "C", source: .smc, timestamp: now),
                SensorReading(id: "power", key: "PMGR", displayName: "Power Manager", category: .power, value: 12.7, unit: "W", source: .system, timestamp: now)
            ],
            fans: [fan],
            thermalState: .nominal,
            lastUpdated: now
        )
    }

    public func setFanMode(fanID: Int, mode: CoolingMode) async throws -> FanState {
        guard fanID == fan.id else {
            throw FanControlError.invalidFan(fanID)
        }

        switch mode {
        case .systemAuto:
            fan.mode = .systemAuto
            fan.targetRPM = nil
            fan.currentRPM = 2120
        case let .manual(targetRPM):
            let clamped = fan.clampedRPM(targetRPM)
            fan.mode = .manual(targetRPM: clamped)
            fan.targetRPM = clamped
            fan.currentRPM = clamped
        }
        return fan
    }

    public func restoreAutomaticFanControl() async {
        fan.mode = .systemAuto
        fan.targetRPM = nil
    }
}
