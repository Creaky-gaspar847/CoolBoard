import Foundation

public struct SMCSensorDefinition: Identifiable, Equatable, Sendable {
    public var id: String { key }
    public let key: String
    public let displayName: String
    public let category: SensorCategory
    public let unit: String
    public let source: SensorSource

    public init(
        key: String,
        displayName: String,
        category: SensorCategory,
        unit: String = "C",
        source: SensorSource = .smc
    ) {
        self.key = key
        self.displayName = displayName
        self.category = category
        self.unit = unit
        self.source = source
    }
}

public enum AppleSiliconSensorCatalog {
    public static let expected: [SMCSensorDefinition] = [
        SMCSensorDefinition(key: "TC0P", displayName: "CPU Proximity", category: .cpu),
        SMCSensorDefinition(key: "TC0E", displayName: "CPU Efficiency Cluster", category: .cpu),
        SMCSensorDefinition(key: "TC0F", displayName: "CPU Performance Cluster", category: .cpu),
        SMCSensorDefinition(key: "TG0P", displayName: "GPU Proximity", category: .gpu),
        SMCSensorDefinition(key: "TA0P", displayName: "AirPort Proximity", category: .airport),
        SMCSensorDefinition(key: "TB0T", displayName: "Battery Pack", category: .battery),
        SMCSensorDefinition(key: "TP0P", displayName: "Power Manager", category: .power),
        SMCSensorDefinition(key: "PMGR", displayName: "Power Manager Rail", category: .power, unit: "raw")
    ]
}
