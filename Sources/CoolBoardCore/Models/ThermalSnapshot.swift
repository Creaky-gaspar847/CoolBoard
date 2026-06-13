import Foundation

public enum ThermalState: String, Codable, Sendable {
    case nominal = "Nominal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"
    case unknown = "Unknown"

    public init(processInfoState: ProcessInfo.ThermalState) {
        switch processInfoState {
        case .nominal:
            self = .nominal
        case .fair:
            self = .fair
        case .serious:
            self = .serious
        case .critical:
            self = .critical
        @unknown default:
            self = .unknown
        }
    }
}

public struct ThermalSnapshot: Codable, Equatable, Sendable {
    public var sensors: [SensorReading]
    public var fans: [FanState]
    public var thermalState: ThermalState
    public var lastUpdated: Date
    public var hardwareStatus: HardwareStatus

    public init(
        sensors: [SensorReading],
        fans: [FanState],
        thermalState: ThermalState,
        lastUpdated: Date = Date(),
        hardwareStatus: HardwareStatus = .ready
    ) {
        self.sensors = sensors
        self.fans = fans
        self.thermalState = thermalState
        self.lastUpdated = lastUpdated
        self.hardwareStatus = hardwareStatus
    }

    public static var empty: ThermalSnapshot {
        ThermalSnapshot(
            sensors: [],
            fans: [],
            thermalState: .unknown,
            hardwareStatus: .monitoringUnavailable("No thermal data has been loaded yet.")
        )
    }

    public var detectedFanCount: Int {
        fans.count
    }

    public var temperatureSensors: [SensorReading] {
        sensors.filter { reading in
            reading.unit == "C" && reading.value != nil
        }
    }

    public var detectedTemperatureSensorCount: Int {
        temperatureSensors.count
    }
}

public enum HardwareStatus: Codable, Equatable, Sendable {
    case ready
    case unsupportedArchitecture(String)
    case monitoringUnavailable(String)
    case fanControlUnavailable(String)
    case helperUnavailable(String)

    public var message: String {
        switch self {
        case .ready:
            "Monitoring active"
        case let .unsupportedArchitecture(message),
             let .monitoringUnavailable(message),
             let .fanControlUnavailable(message),
             let .helperUnavailable(message):
            message
        }
    }
}
