import Foundation

public struct SensorReading: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var key: String
    public var displayName: String
    public var category: SensorCategory
    public var value: Double?
    public var unit: String
    public var source: SensorSource
    public var timestamp: Date

    public init(
        id: String,
        key: String,
        displayName: String,
        category: SensorCategory,
        value: Double?,
        unit: String,
        source: SensorSource,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.key = key
        self.displayName = displayName
        self.category = category
        self.value = value
        self.unit = unit
        self.source = source
        self.timestamp = timestamp
    }
}
