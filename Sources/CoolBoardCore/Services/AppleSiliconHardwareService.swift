import Foundation

public actor AppleSiliconHardwareService: ThermalHardwareServicing {
    private let fanControlClient: PrivilegedFanControlClient
    private let smcClient: AppleSMCClient?
    private let ioRegistryThermalReader: IORegistryThermalReader
    private var lastFans: [FanState] = []

    public init(
        fanControlClient: PrivilegedFanControlClient = PrivilegedFanControlClient(),
        smcClient: AppleSMCClient? = AppleSMCClient(),
        ioRegistryThermalReader: IORegistryThermalReader = IORegistryThermalReader()
    ) {
        self.fanControlClient = fanControlClient
        self.smcClient = smcClient
        self.ioRegistryThermalReader = ioRegistryThermalReader
    }

    public func fetchSnapshot() async -> ThermalSnapshot {
        let now = Date()
        guard Self.isAppleSilicon else {
            return ThermalSnapshot(
                sensors: systemReadings(now: now),
                fans: [],
                thermalState: ThermalState(processInfoState: ProcessInfo.processInfo.thermalState),
                lastUpdated: now,
                hardwareStatus: .unsupportedArchitecture("CoolBoard v1 is Apple Silicon only.")
            )
        }

        let fanSnapshots = smcClient?.fanSnapshots() ?? []
        let fans = readFans(from: fanSnapshots)
        let sensors = readSensors(now: now)
        lastFans = fans

        let smcValues = sensors.filter { $0.source == .smc && $0.value != nil }.count
        let status: HardwareStatus
        if smcValues == 0 && fanSnapshots.isEmpty {
            status = .monitoringUnavailable("Battery/system telemetry active. AppleSMC CPU/GPU/fan telemetry is not exposed on this Mac; manual fan control is disabled.")
        } else if fanSnapshots.isEmpty {
            status = .fanControlUnavailable("No physical fans are reported by AppleSMC (FNum=0). This Mac appears fanless or does not expose fan telemetry; fan controls are disabled.")
        } else {
            status = .ready
        }

        return ThermalSnapshot(
            sensors: sensors,
            fans: fans,
            thermalState: ThermalState(processInfoState: ProcessInfo.processInfo.thermalState),
            lastUpdated: now,
            hardwareStatus: status
        )
    }

    public func setFanMode(fanID: Int, mode: CoolingMode) async throws -> FanState {
        guard Self.isAppleSilicon else {
            throw FanControlError.unsupportedArchitecture("CoolBoard v1 can only control Apple Silicon Macs.")
        }

        guard let fan = lastFans.first(where: { $0.id == fanID }) else {
            throw FanControlError.invalidFan(fanID)
        }

        guard fan.isControllable else {
            throw FanControlError.writeRejected(
                fan.controlMessage ?? "Fan control is not exposed by AppleSMC on this Mac."
            )
        }

        let safeMode: CoolingMode
        switch mode {
        case .systemAuto:
            safeMode = .systemAuto
        case let .manual(targetRPM):
            safeMode = .manual(targetRPM: fan.clampedRPM(targetRPM))
        }

        let updatedFan: FanState
        do {
            updatedFan = try await fanControlClient.setFanMode(fanID: fanID, mode: safeMode, currentFan: fan)
        } catch let helperError {
            do {
                updatedFan = try applyDirectSMCFanMode(fan: fan, mode: safeMode, helperError: helperError)
            } catch let directError {
                throw FanControlError.writeRejected(
                    "Fan write failed. Install the privileged helper with script/install_helper.sh. Helper: \(helperError.localizedDescription). Direct AppleSMC: \(directError.localizedDescription)"
                )
            }
        }

        remember(updatedFan)
        return updatedFan
    }

    public func restoreAutomaticFanControl() async {
        for fan in lastFans where fan.isControllable {
            do {
                _ = try await fanControlClient.setFanMode(fanID: fan.id, mode: .systemAuto, currentFan: fan)
            } catch {
                _ = try? applyDirectSMCFanMode(fan: fan, mode: .systemAuto, helperError: error)
            }
        }
    }

    private func applyDirectSMCFanMode(fan: FanState, mode: CoolingMode, helperError: Error) throws -> FanState {
        guard let smcClient else {
            throw FanControlError.helperUnavailable(
                "CoolBoard privileged helper failed and AppleSMC is unavailable in the app process: \(helperError.localizedDescription)"
            )
        }

        switch mode {
        case .systemAuto:
            try smcClient.restoreAutomaticFan(fanID: fan.id, validateFanExists: false)
            var restored = fan
            restored.mode = .systemAuto
            restored.targetRPM = nil
            return restored
        case let .manual(targetRPM):
            let clampedRPM = fan.clampedRPM(targetRPM)
            try smcClient.setManualFanTarget(
                fanID: fan.id,
                rpm: clampedRPM,
                minimumRPM: fan.minRPM,
                maximumRPM: fan.maxRPM,
                validateFanExists: false
            )
            var updated = fan
            updated.mode = .manual(targetRPM: clampedRPM)
            updated.targetRPM = clampedRPM
            updated.currentRPM = clampedRPM
            return updated
        }
    }

    private func readFans(from snapshots: [SMCFanSnapshot]) -> [FanState] {
        if snapshots.isEmpty {
            return []
        }

        return snapshots.map { snapshot in
            mergedFanState(
                id: snapshot.id,
                name: fanDisplayName(id: snapshot.id, totalCount: snapshots.count),
                currentRPM: snapshot.currentRPM,
                minRPM: max(snapshot.minRPM, 0),
                maxRPM: max(snapshot.maxRPM, snapshot.minRPM),
                observedMode: snapshot.mode,
                observedTargetRPM: snapshot.targetRPM,
                controlAvailability: .available
            )
        }
    }

    private func fanDisplayName(id: Int, totalCount: Int) -> String {
        if totalCount == 1 {
            return "System Fan"
        }
        if totalCount == 2 {
            return id == 0 ? "Left side" : "Right side"
        }
        return "System Fan \(id + 1)"
    }

    private func mergedFanState(
        id: Int,
        name: String,
        currentRPM: Int?,
        minRPM: Int,
        maxRPM: Int,
        observedMode: CoolingMode? = nil,
        observedTargetRPM: Int? = nil,
        controlAvailability: FanControlAvailability
    ) -> FanState {
        guard let previous = lastFans.first(where: { $0.id == id }) else {
            let mode = normalizedMode(observedMode, observedTargetRPM: observedTargetRPM, minRPM: minRPM, maxRPM: maxRPM)
            return FanState(
                id: id,
                name: name,
                currentRPM: currentRPM,
                minRPM: minRPM,
                maxRPM: maxRPM,
                mode: mode,
                targetRPM: mode.targetRPM,
                controlAvailability: controlAvailability
            )
        }

        let mode = normalizedMode(
            observedMode ?? previous.mode,
            observedTargetRPM: observedTargetRPM ?? previous.targetRPM,
            minRPM: minRPM,
            maxRPM: maxRPM
        )

        var fan = FanState(
            id: id,
            name: name,
            currentRPM: currentRPM ?? previous.currentRPM,
            minRPM: minRPM,
            maxRPM: maxRPM,
            mode: mode,
            targetRPM: mode.targetRPM,
            controlAvailability: controlAvailability
        )

        if !controlAvailability.isAvailable {
            fan.mode = .systemAuto
            fan.targetRPM = nil
            return fan
        }

        return fan
    }

    private func normalizedMode(
        _ mode: CoolingMode?,
        observedTargetRPM: Int?,
        minRPM: Int,
        maxRPM: Int
    ) -> CoolingMode {
        switch mode {
        case .systemAuto, nil:
            return .systemAuto
        case let .manual(targetRPM):
            let target = observedTargetRPM ?? targetRPM
            if target <= 0 {
                return .manual(targetRPM: 0)
            }
            return .manual(targetRPM: min(max(target, minRPM), maxRPM))
        }
    }

    private func remember(_ fan: FanState) {
        if let index = lastFans.firstIndex(where: { $0.id == fan.id }) {
            lastFans[index] = fan
        } else {
            lastFans.append(fan)
        }
    }

    private func readSensors(now: Date) -> [SensorReading] {
        let smcReadings = AppleSiliconSensorCatalog.expected.map { definition in
            smcClient?.sensorReading(for: definition, timestamp: now) ?? SensorReading(
                id: definition.key.lowercased(),
                key: definition.key,
                displayName: definition.displayName,
                category: definition.category,
                value: nil,
                unit: definition.unit,
                source: .unavailable,
                timestamp: now
            )
        }

        let visibleSMCReadings = smcReadings.filter { $0.value != nil }
        let dynamicSMCReadings = smcClient?.temperatureReadings(timestamp: now) ?? []
        return mergedSensorReadings(visibleSMCReadings + dynamicSMCReadings + ioRegistryThermalReader.readings(now: now) + systemReadings(now: now))
    }

    private func mergedSensorReadings(_ readings: [SensorReading]) -> [SensorReading] {
        var merged: [SensorReading] = []
        var seenKeys: Set<String> = []

        for reading in readings {
            let mergeKey = "\(reading.category.rawValue.lowercased())::\(reading.displayName.lowercased())"
            guard !seenKeys.contains(mergeKey) else {
                continue
            }
            seenKeys.insert(mergeKey)
            merged.append(reading)
        }

        return merged
    }

    private func systemReadings(now: Date) -> [SensorReading] {
        let processInfo = ProcessInfo.processInfo
        return [
            SensorReading(
                id: "thermal-state",
                key: "THERM",
                displayName: "Thermal State",
                category: .system,
                value: Double(Self.numericThermalState(processInfo.thermalState)),
                unit: "level",
                source: .processInfo,
                timestamp: now
            ),
            SensorReading(
                id: "cpu-cores",
                key: "HW-NCPU",
                displayName: "CPU Cores",
                category: .cpu,
                value: Double(processInfo.processorCount),
                unit: "cores",
                source: .system,
                timestamp: now
            ),
            SensorReading(
                id: "physical-memory",
                key: "HW-MEM",
                displayName: "Unified Memory",
                category: .system,
                value: Double(processInfo.physicalMemory) / 1_073_741_824.0,
                unit: "GB",
                source: .system,
                timestamp: now
            )
        ]
    }

    private static func numericThermalState(_ state: ProcessInfo.ThermalState) -> Int {
        switch state {
        case .nominal:
            0
        case .fair:
            1
        case .serious:
            2
        case .critical:
            3
        @unknown default:
            -1
        }
    }

    private static var isAppleSilicon: Bool {
        #if arch(arm64)
        true
        #else
        false
        #endif
    }
}
