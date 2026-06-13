import Foundation
import IOKit

public struct IORegistryThermalReader: Sendable {
    public init() {}

    public func readings(now: Date = Date()) -> [SensorReading] {
        batteryReadings(now: now)
    }

    public static func celsius(fromAppleSmartBatteryRawValue rawValue: Int) -> Double {
        Double(rawValue) / 100.0
    }

    private func batteryReadings(now: Date) -> [SensorReading] {
        var readings: [SensorReading] = []

        if let rawTemperature = integerProperty(serviceClass: "AppleSmartBattery", key: "Temperature") {
            readings.append(
                SensorReading(
                    id: "apple-smart-battery-temperature",
                    key: "AppleSmartBattery.Temperature",
                    displayName: "Battery Pack",
                    category: .battery,
                    value: Self.celsius(fromAppleSmartBatteryRawValue: rawTemperature),
                    unit: "C",
                    source: .system,
                    timestamp: now
                )
            )
        }

        if let rawTemperature = integerProperty(serviceClass: "AppleSmartBattery", key: "VirtualTemperature") {
            readings.append(
                SensorReading(
                    id: "apple-smart-battery-virtual-temperature",
                    key: "AppleSmartBattery.VirtualTemperature",
                    displayName: "Battery Virtual",
                    category: .battery,
                    value: Self.celsius(fromAppleSmartBatteryRawValue: rawTemperature),
                    unit: "C",
                    source: .system,
                    timestamp: now
                )
            )
        }

        return readings
    }

    private func integerProperty(serviceClass: String, key: String) -> Int? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(serviceClass))
        guard service != IO_OBJECT_NULL else {
            return nil
        }
        defer { IOObjectRelease(service) }

        guard let property = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }

        return (property.takeRetainedValue() as? NSNumber)?.intValue
    }
}
