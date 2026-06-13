import Foundation

public enum ThermalFormatters {
    public static func sensorValue(_ reading: SensorReading) -> String {
        guard let value = reading.value else {
            return "--"
        }

        if reading.unit == "RPM" || reading.unit == "cores" {
            return "\(Int(value.rounded()))"
        }

        if reading.unit == "GB" {
            return String(format: "%.1f", value)
        }

        return String(format: "%.1f", value)
    }

    public static func ageDescription(snapshotDate: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(snapshotDate)))
        if seconds < 2 {
            return "just now"
        }
        return "\(seconds)s ago"
    }
}
