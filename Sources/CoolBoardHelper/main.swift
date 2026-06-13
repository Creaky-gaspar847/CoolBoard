import CoolBoardCore
import Darwin
import Foundation

@main
struct CoolBoardHelper {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst()).dropLeadingSeparator()

        if arguments.contains("--version") {
            print("CoolBoardHelper 0.1.0")
            return
        }

        if arguments.contains("--contract") {
            print("""
            machService: \(PrivilegedFanControlClient.machServiceName)
            actions:
              - listFans()
              - setFanMode(fanID, systemAuto)
              - setFanMode(fanID, manualRPM)
              - restoreAutomaticFanControl()
              - readTemperatures()
            status: write path performs AppleSMC writes when invoked; app falls back to direct AppleSMC when the helper is not installed
            """)
            return
        }

        if arguments.contains("--xpc-service") || ProcessInfo.processInfo.environment["COOLBOARD_RUN_XPC_SERVICE"] == "1" {
            let delegate = FanControlXPCDelegate()
            let listener = NSXPCListener(machServiceName: CoolBoardXPC.machServiceName)
            listener.delegate = delegate
            listener.resume()
            RunLoop.current.run()
            return
        }

        guard let smcClient = AppleSMCClient() else {
            print("AppleSMC unavailable")
            exit(1)
        }

        switch arguments.first {
        case "list":
            let fans = smcClient.fanSnapshots()
            if fans.isEmpty {
                print("No fans reported by AppleSMC")
            } else {
                for fan in fans {
                    print("fan \(fan.id): current=\(fan.currentRPM ?? -1) min=\(fan.minRPM) max=\(fan.maxRPM)")
                }
            }
        case "sensors":
            let readings = smcClient.temperatureReadings()
            if readings.isEmpty {
                print("No SMC temperature sensors reported")
            } else {
                for reading in readings {
                    print("\(reading.key): \(reading.displayName)=\(ThermalFormatters.sensorValue(reading)) \(reading.unit)")
                }
            }
        case "set":
            guard arguments.count == 3, let fanID = Int(arguments[1]), let rpm = Int(arguments[2]) else {
                print("usage: CoolBoardHelper set <fanID> <rpm>")
                exit(2)
            }
            do {
                try smcClient.setManualFanTargetUsingDefaultSlots(fanID: fanID, rpm: rpm)
                print("fan \(fanID) manual target requested at \(rpm) RPM")
            } catch {
                print(error.localizedDescription)
                exit(1)
            }
        case "auto":
            guard arguments.count == 2, let fanID = Int(arguments[1]) else {
                print("usage: CoolBoardHelper auto <fanID>")
                exit(2)
            }
            do {
                try smcClient.restoreAutomaticFanUsingDefaultSlots(fanID: fanID)
                print("fan \(fanID) returned to automatic mode")
            } catch {
                print(error.localizedDescription)
                exit(1)
            }
        default:
            print("usage: CoolBoardHelper [--version|--contract|list|sensors|set <fanID> <rpm>|auto <fanID>]")
        }
    }
}

final class FanControlXPCDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: CoolBoardFanControlXPC.self)
        newConnection.exportedObject = FanControlXPCService()
        newConnection.resume()
        return true
    }
}

final class FanControlXPCService: NSObject, CoolBoardFanControlXPC {
    private let smcClient = AppleSMCClient()

    func listFans(withReply reply: @escaping ([[String: NSNumber]], String?) -> Void) {
        guard let smcClient else {
            reply([], "AppleSMC unavailable")
            return
        }

        let fans = smcClient.fanSnapshots().map { fan in
            [
                "id": NSNumber(value: fan.id),
                "currentRPM": NSNumber(value: fan.currentRPM ?? -1),
                "minRPM": NSNumber(value: fan.minRPM),
                "maxRPM": NSNumber(value: fan.maxRPM)
            ]
        }
        reply(fans, nil)
    }

    func setManualFanTarget(_ fanID: NSNumber, rpm: NSNumber, withReply reply: @escaping (Bool, String?) -> Void) {
        guard let smcClient else {
            reply(false, "AppleSMC unavailable")
            return
        }

        do {
            try smcClient.setManualFanTargetUsingDefaultSlots(fanID: fanID.intValue, rpm: rpm.intValue)
            reply(true, nil)
        } catch {
            reply(false, error.localizedDescription)
        }
    }

    func restoreAutomaticFanControl(_ fanID: NSNumber, withReply reply: @escaping (Bool, String?) -> Void) {
        guard let smcClient else {
            reply(false, "AppleSMC unavailable")
            return
        }

        do {
            try smcClient.restoreAutomaticFanUsingDefaultSlots(fanID: fanID.intValue)
            reply(true, nil)
        } catch {
            reply(false, error.localizedDescription)
        }
    }
}

private extension Array where Element == String {
    func dropLeadingSeparator() -> [String] {
        first == "--" ? Array(dropFirst()) : self
    }
}

private extension AppleSMCClient {
    func setManualFanTargetUsingDefaultSlots(fanID: Int, rpm: Int) throws {
        do {
            try setManualFanTarget(fanID: fanID, rpm: rpm)
        } catch FanControlError.invalidFan where Self.defaultAppleSiliconFanIDs.contains(fanID) {
            try setManualFanTarget(
                fanID: fanID,
                rpm: rpm,
                minimumRPM: Self.defaultAppleSiliconMinimumRPM,
                maximumRPM: Self.defaultAppleSiliconMaximumRPM,
                validateFanExists: false
            )
        }
    }

    func restoreAutomaticFanUsingDefaultSlots(fanID: Int) throws {
        do {
            try restoreAutomaticFan(fanID: fanID)
        } catch FanControlError.invalidFan where Self.defaultAppleSiliconFanIDs.contains(fanID) {
            try restoreAutomaticFan(fanID: fanID, validateFanExists: false)
        }
    }

    private static var defaultAppleSiliconFanIDs: Set<Int> {
        [0, 1]
    }

    private static var defaultAppleSiliconMinimumRPM: Int {
        2317
    }

    private static var defaultAppleSiliconMaximumRPM: Int {
        6800
    }
}
