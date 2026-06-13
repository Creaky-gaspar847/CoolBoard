import Foundation

public enum CoolingMode: Codable, Equatable, Sendable {
    case systemAuto
    case manual(targetRPM: Int)

    public var targetRPM: Int? {
        if case let .manual(targetRPM) = self {
            return targetRPM
        }
        return nil
    }

    public var label: String {
        switch self {
        case .systemAuto:
            "Auto"
        case let .manual(targetRPM):
            "Manual \(targetRPM) RPM"
        }
    }
}

public enum FanControlAvailability: Codable, Equatable, Sendable {
    case available
    case unavailable(String)

    public var isAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }

    public var message: String? {
        if case let .unavailable(message) = self {
            return message
        }
        return nil
    }
}

public struct FanState: Identifiable, Codable, Equatable, Sendable {
    public var id: Int
    public var name: String
    public var currentRPM: Int?
    public var minRPM: Int
    public var maxRPM: Int
    public var mode: CoolingMode
    public var targetRPM: Int?
    public var controlAvailability: FanControlAvailability

    public init(
        id: Int,
        name: String,
        currentRPM: Int?,
        minRPM: Int,
        maxRPM: Int,
        mode: CoolingMode,
        targetRPM: Int? = nil,
        controlAvailability: FanControlAvailability = .available
    ) {
        self.id = id
        self.name = name
        self.currentRPM = currentRPM
        self.minRPM = minRPM
        self.maxRPM = maxRPM
        self.mode = mode
        self.targetRPM = targetRPM
        self.controlAvailability = controlAvailability
    }

    public var isControllable: Bool {
        controlAvailability.isAvailable
    }

    public var controlMessage: String? {
        controlAvailability.message
    }

    public func clampedRPM(_ requestedRPM: Int) -> Int {
        min(max(requestedRPM, minRPM), maxRPM)
    }

    public func rpm(forPowerPercent percent: Int) -> Int {
        let clampedPercent = min(max(percent, 0), 100)
        let range = maxRPM - minRPM
        return clampedRPM(minRPM + Int((Double(range) * Double(clampedPercent) / 100.0).rounded()))
    }

    public func powerPercent(forRPM rpm: Int) -> Int {
        guard maxRPM > minRPM else {
            return 0
        }
        let clamped = clampedRPM(rpm)
        return Int((Double(clamped - minRPM) / Double(maxRPM - minRPM) * 100.0).rounded())
    }
}
