import CoolBoardCore
import Foundation

enum XPCProbe {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let command = arguments.first ?? "list"
        let usePrivileged = !arguments.contains("--plain")
        let options: NSXPCConnection.Options = usePrivileged ? .privileged : []

        let connection = NSXPCConnection(machServiceName: CoolBoardXPC.machServiceName, options: options)
        connection.remoteObjectInterface = NSXPCInterface(with: CoolBoardFanControlXPC.self)

        let semaphore = DispatchSemaphore(value: 0)
        var didFinish = false

        func finish() {
            if !didFinish {
                didFinish = true
                semaphore.signal()
            }
        }

        connection.interruptionHandler = {
            print("interrupted")
            finish()
        }
        connection.invalidationHandler = {
            print("invalidated")
            finish()
        }

        connection.resume()

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            print("proxy-error: \(error.localizedDescription)")
            finish()
        }) as? CoolBoardFanControlXPC else {
            print("proxy-unavailable")
            connection.invalidate()
            exit(1)
        }

        switch command {
        case "list":
            proxy.listFans { fans, message in
                if let message {
                    print("list-error: \(message)")
                } else {
                    for fan in fans {
                        print("fan \(fan["id"] ?? -1): current=\(fan["currentRPM"] ?? -1) min=\(fan["minRPM"] ?? -1) max=\(fan["maxRPM"] ?? -1)")
                    }
                }
                finish()
            }
        case "set":
            guard arguments.count >= 3, let fanID = Int(arguments[1]), let rpm = Int(arguments[2]) else {
                print("usage: CoolBoardXPCProbe set <fanID> <rpm> [--plain]")
                exit(2)
            }
            proxy.setManualFanTarget(NSNumber(value: fanID), rpm: NSNumber(value: rpm)) { success, message in
                print(success ? "set-ok" : "set-failed: \(message ?? "unknown error")")
                finish()
            }
        case "auto":
            guard arguments.count >= 2, let fanID = Int(arguments[1]) else {
                print("usage: CoolBoardXPCProbe auto <fanID> [--plain]")
                exit(2)
            }
            proxy.restoreAutomaticFanControl(NSNumber(value: fanID)) { success, message in
                print(success ? "auto-ok" : "auto-failed: \(message ?? "unknown error")")
                finish()
            }
        default:
            print("usage: CoolBoardXPCProbe [list|set <fanID> <rpm>|auto <fanID>] [--plain]")
            exit(2)
        }

        if semaphore.wait(timeout: .now() + 10) == .timedOut {
            print("timeout")
            connection.invalidate()
            exit(1)
        }

        connection.invalidate()
    }
}

XPCProbe.main()
