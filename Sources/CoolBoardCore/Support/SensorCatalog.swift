import Foundation

public enum SensorCatalog {
    public static func category(for key: String, displayName: String = "") -> SensorCategory {
        let normalized = "\(key) \(displayName)".lowercased()

        if normalized.contains("airport") || normalized.contains("wireless") || normalized.contains("wifi") {
            return .airport
        }
        if normalized.contains("gpu") || normalized.contains("graphics") || normalized.contains("tsg") {
            return .gpu
        }
        if normalized.contains("battery") || normalized.contains("batt") {
            return .battery
        }
        if normalized.contains("power") || normalized.contains("pmgr") || normalized.contains("voltage") || normalized.contains("current") {
            return .power
        }
        if normalized.contains("cpu") || normalized.contains("soc") || normalized.contains("die") || normalized.contains("core") {
            return .cpu
        }
        if normalized.contains("thermal") || normalized.contains("pressure") || normalized.contains("memory") {
            return .system
        }
        return .unknown
    }
}
