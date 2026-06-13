import Foundation

public enum SensorCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case cpu = "CPU"
    case gpu = "GPU"
    case airport = "AirPort"
    case power = "Power"
    case battery = "Battery"
    case system = "System"
    case unknown = "Unknown"

    public var id: String { rawValue }
}

public enum SensorSource: String, Codable, Sendable {
    case smc = "SMC"
    case hid = "HID"
    case processInfo = "ProcessInfo"
    case system = "System"
    case unavailable = "Unavailable"
}
