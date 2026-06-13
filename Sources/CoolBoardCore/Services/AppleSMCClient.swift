import Foundation
import IOKit

public struct SMCFanSnapshot: Sendable, Equatable {
    public var id: Int
    public var currentRPM: Int?
    public var minRPM: Int
    public var maxRPM: Int
    public var mode: CoolingMode?
    public var targetRPM: Int?
}

public struct SMCValue: Sendable, Equatable {
    public let key: String
    public let type: String
    public let bytes: [UInt8]

    public init(key: String, type: String, bytes: [UInt8]) {
        self.key = key
        self.type = type
        self.bytes = bytes
    }

    public static func fpe2Bytes(for value: Int) -> [UInt8] {
        let raw = UInt16(max(0, value) * 4)
        return [UInt8((raw >> 8) & 0xff), UInt8(raw & 0xff)]
    }

    public static func ui8Bytes(for value: UInt8) -> [UInt8] {
        [value]
    }

    public static func floatBytes(for value: Float) -> [UInt8] {
        withUnsafeBytes(of: value) { rawBuffer in
            Array(rawBuffer)
        }
    }

    public var numericValue: Double? {
        switch type {
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
            return Double(raw) / 256.0
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Double(raw) / 4.0
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            let value = bytes.withUnsafeBytes { rawBuffer in
                rawBuffer.loadUnaligned(as: Float.self)
            }
            return Double(value)
        case "ui8":
            return bytes.first.map(Double.init)
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "ui32":
            guard bytes.count >= 4 else { return nil }
            return Double(UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3]))
        default:
            return nil
        }
    }
}

public final class AppleSMCClient: @unchecked Sendable {
    private typealias SMCBytes = (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )

    private struct SMCVersion {
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: UInt8 = 0
        var release: UInt16 = 0
    }

    private struct SMCPLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    private struct SMCKeyInfoData {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    private struct SMCKeyData {
        var key: UInt32 = 0
        var vers = SMCVersion()
        var pLimitData = SMCPLimitData()
        var keyInfo = SMCKeyInfoData()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: SMCBytes = AppleSMCClient.emptyBytes
    }

    private static let emptyBytes: SMCBytes = (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )

    private let connection: io_connect_t
    private var cachedTemperatureKeys: [String]?

    public static var smcKeyDataStride: Int {
        MemoryLayout<SMCKeyData>.stride
    }

    public init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != IO_OBJECT_NULL else {
            return nil
        }
        defer { IOObjectRelease(service) }

        var connection = io_connect_t()
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard result == kIOReturnSuccess else {
            return nil
        }
        self.connection = connection
    }

    deinit {
        IOServiceClose(connection)
    }

    public func fanSnapshots() -> [SMCFanSnapshot] {
        let count = Int(readUInt("FNum") ?? 0)
        guard count > 0 else {
            return []
        }

        return (0..<count).map { id in
            SMCFanSnapshot(
                id: id,
                currentRPM: readRPM("F\(id)Ac"),
                minRPM: readRPM("F\(id)Mn") ?? 0,
                maxRPM: readRPM("F\(id)Mx") ?? 7000,
                mode: readFanMode(fanID: id),
                targetRPM: readRPM("F\(id)Tg")
            )
        }
    }

    public func temperatureReadings(timestamp: Date = Date()) -> [SensorReading] {
        let keys = temperatureKeys()
        return keys.compactMap { key in
            guard let value = readValue(key),
                  let numericValue = value.numericValue,
                  numericValue.isFinite,
                  numericValue > -50,
                  numericValue < 150
            else {
                return nil
            }

            let displayName = Self.displayName(forTemperatureKey: key)
            return SensorReading(
                id: "smc-\(key.lowercased())",
                key: key,
                displayName: displayName,
                category: SensorCatalog.category(for: key, displayName: displayName),
                value: numericValue,
                unit: "C",
                source: .smc,
                timestamp: timestamp
            )
        }
    }

    public func setManualFanTarget(fanID: Int, rpm: Int) throws {
        if let fan = fanSnapshots().first(where: { $0.id == fanID }) {
            try setManualFanTarget(
                fanID: fanID,
                rpm: rpm,
                minimumRPM: fan.minRPM,
                maximumRPM: fan.maxRPM,
                validateFanExists: false
            )
        } else {
            throw FanControlError.invalidFan(fanID)
        }
    }

    public func setManualFanTarget(
        fanID: Int,
        rpm: Int,
        minimumRPM: Int,
        maximumRPM: Int,
        validateFanExists: Bool = true
    ) throws {
        if validateFanExists {
            let snapshots = fanSnapshots()
            if let fan = snapshots.first(where: { $0.id == fanID }) {
                let lowerBound = max(fan.minRPM, minimumRPM)
                let upperBound = min(max(fan.maxRPM, lowerBound), max(maximumRPM, lowerBound))
                try setManualFanTarget(
                    fanID: fanID,
                    rpm: rpm,
                    minimumRPM: lowerBound,
                    maximumRPM: upperBound,
                    validateFanExists: false
                )
                return
            }
            throw FanControlError.invalidFan(fanID)
        }

        let safeMinimum = max(0, minimumRPM)
        let safeMaximum = max(safeMinimum, maximumRPM)
        let clampedRPM = min(max(rpm, safeMinimum), safeMaximum)
        try enableManualFanMode(fanID: fanID)
        let targetKey = "F\(fanID)Tg"
        try writeValue(key: targetKey, bytes: rpmBytes(for: clampedRPM, key: targetKey))
    }

    public func restoreAutomaticFan(fanID: Int) throws {
        try restoreAutomaticFan(fanID: fanID, validateFanExists: true)
    }

    public func restoreAutomaticFan(fanID: Int, validateFanExists: Bool) throws {
        if validateFanExists && !fanSnapshots().contains(where: { $0.id == fanID }) {
            throw FanControlError.invalidFan(fanID)
        }

        let modeKey = try fanModeKey(fanID: fanID)
        try writeValue(key: modeKey, bytes: SMCValue.ui8Bytes(for: 0))

        let targetKey = "F\(fanID)Tg"
        if getKeyInfo(targetKey) != nil {
            try writeValue(key: targetKey, bytes: rpmBytes(for: 0, key: targetKey))
        }

        if !hasManualFans(excluding: fanID), getKeyInfo("Ftst") != nil {
            try writeValue(key: "Ftst", bytes: SMCValue.ui8Bytes(for: 0))
        }
    }

    public func sensorReading(for definition: SMCSensorDefinition, timestamp: Date = Date()) -> SensorReading {
        let value = readValue(definition.key)?.numericValue
        return SensorReading(
            id: definition.key.lowercased(),
            key: definition.key,
            displayName: definition.displayName,
            category: definition.category,
            value: value,
            unit: definition.unit,
            source: value == nil ? .unavailable : definition.source,
            timestamp: timestamp
        )
    }

    public func readValue(_ key: String) -> SMCValue? {
        guard let value = readKey(key) else {
            return nil
        }
        return SMCValue(key: key, type: value.type, bytes: value.bytes)
    }

    public func allKeys() -> [String] {
        let keyCount = Int(readUInt("#KEY") ?? 0)
        guard keyCount > 0 else {
            return []
        }

        var keys: [String] = []
        keys.reserveCapacity(keyCount)

        for index in 0..<keyCount {
            var input = SMCKeyData()
            input.data8 = 8
            input.data32 = UInt32(index)
            guard let output = call(input: input), output.result == 0 else {
                continue
            }
            keys.append(Self.string(fromFourCharacterCode: output.key))
        }

        return keys
    }

    public func writeValue(key: String, type _: String, bytes: [UInt8]) throws {
        try writeValue(key: key, bytes: bytes)
    }

    public func writeValue(key: String, bytes: [UInt8]) throws {
        guard var keyInfo = getKeyInfo(key) else {
            throw FanControlError.writeRejected("SMC key \(key) is not available.")
        }

        let dataSize = max(0, min(Int(keyInfo.dataSize), 32))
        keyInfo.dataSize = UInt32(dataSize)

        var input = SMCKeyData()
        input.key = Self.fourCharacterCode(key)
        input.keyInfo = keyInfo
        input.data8 = 6
        input.bytes = Self.bytesTuple(Self.paddedBytes(bytes, count: dataSize))

        guard let output = call(input: input), output.result == 0 else {
            throw FanControlError.writeRejected("SMC rejected write to \(key).")
        }
    }

    private func readUInt(_ key: String) -> UInt64? {
        guard let value = readValue(key), let first = value.bytes.first else {
            return nil
        }

        if value.type == "ui8" {
            return UInt64(first)
        }

        return value.bytes.reduce(UInt64(0)) { partial, byte in
            (partial << 8) + UInt64(byte)
        }
    }

    private func readRPM(_ key: String) -> Int? {
        guard let value = readValue(key) else {
            return nil
        }

        if value.type == "fpe2", value.bytes.count >= 2 {
            let raw = UInt16(value.bytes[0]) << 8 | UInt16(value.bytes[1])
            return Int((Double(raw) / 4.0).rounded())
        }

        if value.type == "flt ", value.bytes.count >= 4 {
            let rpm = value.bytes.withUnsafeBytes { rawBuffer in
                rawBuffer.loadUnaligned(as: Float.self)
            }
            return Int(rpm.rounded())
        }

        return nil
    }

    private func readFanMode(fanID: Int) -> CoolingMode? {
        guard let modeKey = try? fanModeKey(fanID: fanID),
              let modeByte = readValue(modeKey)?.bytes.first
        else {
            return nil
        }

        guard modeByte == 1 else {
            return .systemAuto
        }

        let target = readRPM("F\(fanID)Tg") ?? readRPM("F\(fanID)Ac") ?? 0
        return .manual(targetRPM: target)
    }

    private func temperatureKeys() -> [String] {
        if let cachedTemperatureKeys {
            return cachedTemperatureKeys
        }

        let keys = allKeys().filter { key in
            guard key.first == "T" else {
                return false
            }
            return readValue(key)?.numericValue != nil
        }
        cachedTemperatureKeys = keys
        return keys
    }

    private func readKey(_ key: String) -> (type: String, bytes: [UInt8])? {
        guard let keyInfo = getKeyInfo(key) else {
            return nil
        }

        var input = SMCKeyData()
        input.key = Self.fourCharacterCode(key)
        input.keyInfo = keyInfo
        input.data8 = 5

        guard let output = call(input: input) else {
            return nil
        }

        let byteCount = min(Int(keyInfo.dataSize), 32)
        let bytes = Self.bytesArray(output.bytes).prefix(byteCount)
        return (Self.string(fromFourCharacterCode: keyInfo.dataType), Array(bytes))
    }

    private func enableManualFanMode(fanID: Int, maxRetries: Int = 100) throws {
        let modeKey = try fanModeKey(fanID: fanID)

        do {
            try writeValue(key: modeKey, bytes: SMCValue.ui8Bytes(for: 1))
            return
        } catch {
            guard getKeyInfo("Ftst") != nil else {
                throw error
            }
        }

        try writeValue(key: "Ftst", bytes: SMCValue.ui8Bytes(for: 1))
        Thread.sleep(forTimeInterval: 0.5)

        var lastError: Error?
        for _ in 0..<maxRetries {
            do {
                try writeValue(key: modeKey, bytes: SMCValue.ui8Bytes(for: 1))
                return
            } catch {
                lastError = error
                Thread.sleep(forTimeInterval: 0.1)
            }
        }

        throw lastError ?? FanControlError.writeRejected("Timed out enabling manual fan mode.")
    }

    private func fanModeKey(fanID: Int) throws -> String {
        for key in ["F\(fanID)md", "F\(fanID)Md"] where getKeyInfo(key) != nil {
            return key
        }
        throw FanControlError.writeRejected("SMC mode key for fan \(fanID) is not available.")
    }

    private func rpmBytes(for rpm: Int, key: String) throws -> [UInt8] {
        guard let keyInfo = getKeyInfo(key) else {
            throw FanControlError.writeRejected("SMC target key \(key) is not available.")
        }

        let type = Self.string(fromFourCharacterCode: keyInfo.dataType)
        if type == "flt " || keyInfo.dataSize == 4 {
            return SMCValue.floatBytes(for: Float(rpm))
        }

        return SMCValue.fpe2Bytes(for: rpm)
    }

    private func hasManualFans(excluding fanID: Int) -> Bool {
        let count = Int(readUInt("FNum") ?? 0)
        guard count > 0 else {
            return false
        }

        for id in 0..<count where id != fanID {
            guard let key = try? fanModeKey(fanID: id), let mode = readValue(key)?.bytes.first else {
                continue
            }
            if mode == 1 {
                return true
            }
        }
        return false
    }

    private func getKeyInfo(_ key: String) -> SMCKeyInfoData? {
        var input = SMCKeyData()
        input.key = Self.fourCharacterCode(key)
        input.data8 = 9
        guard let output = call(input: input), output.result == 0, output.keyInfo.dataSize > 0 else {
            return nil
        }
        return output.keyInfo
    }

    private func call(input: SMCKeyData) -> SMCKeyData? {
        var input = input
        var output = SMCKeyData()
        var outputSize = MemoryLayout<SMCKeyData>.stride

        let result = withUnsafePointer(to: &input) { inputPointer in
            inputPointer.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<SMCKeyData>.stride) { inputBytes in
                withUnsafeMutablePointer(to: &output) { outputPointer in
                    outputPointer.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<SMCKeyData>.stride) { outputBytes in
                        IOConnectCallStructMethod(
                            connection,
                            2,
                            inputBytes,
                            MemoryLayout<SMCKeyData>.stride,
                            outputBytes,
                            &outputSize
                        )
                    }
                }
            }
        }

        guard result == kIOReturnSuccess else {
            return nil
        }
        return output
    }

    private static func bytesArray(_ bytes: SMCBytes) -> [UInt8] {
        withUnsafeBytes(of: bytes) { rawBuffer in
            Array(rawBuffer)
        }
    }

    private static func bytesTuple(_ bytes: [UInt8]) -> SMCBytes {
        var padded = Array(bytes.prefix(32))
        if padded.count < 32 {
            padded.append(contentsOf: repeatElement(0, count: 32 - padded.count))
        }
        return (
            padded[0], padded[1], padded[2], padded[3], padded[4], padded[5], padded[6], padded[7],
            padded[8], padded[9], padded[10], padded[11], padded[12], padded[13], padded[14], padded[15],
            padded[16], padded[17], padded[18], padded[19], padded[20], padded[21], padded[22], padded[23],
            padded[24], padded[25], padded[26], padded[27], padded[28], padded[29], padded[30], padded[31]
        )
    }

    private static func paddedBytes(_ bytes: [UInt8], count: Int) -> [UInt8] {
        let safeCount = max(0, min(count, 32))
        var padded = Array(bytes.prefix(safeCount))
        if padded.count < safeCount {
            padded.append(contentsOf: repeatElement(0, count: safeCount - padded.count))
        }
        return padded
    }

    private static func displayName(forTemperatureKey key: String) -> String {
        if let definition = AppleSiliconSensorCatalog.expected.first(where: { $0.key == key }) {
            return definition.displayName
        }

        if key.hasPrefix("TC") {
            return "CPU \(key)"
        }
        if key.hasPrefix("TG") || key.hasPrefix("TSG") {
            return "GPU \(key)"
        }
        if key.hasPrefix("TA") {
            return "AirPort \(key)"
        }
        if key.hasPrefix("TB") {
            return "Battery \(key)"
        }
        if key.hasPrefix("TP") || key.hasPrefix("Tp") {
            return "Power \(key)"
        }
        if key.hasPrefix("TM") || key.hasPrefix("Tm") {
            return "Memory \(key)"
        }
        if key.hasPrefix("TN") {
            return "NAND \(key)"
        }
        return "SMC \(key)"
    }

    private static func fourCharacterCode(_ string: String) -> UInt32 {
        string.utf8.prefix(4).reduce(UInt32(0)) { partial, byte in
            (partial << 8) + UInt32(byte)
        }
    }

    private static func string(fromFourCharacterCode code: UInt32) -> String {
        let bytes = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "????"
    }
}
