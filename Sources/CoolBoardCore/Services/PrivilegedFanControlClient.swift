import Foundation

public actor PrivilegedFanControlClient {
    public static let machServiceName = CoolBoardXPC.machServiceName

    public init() {}

    public func setFanMode(fanID: Int, mode: CoolingMode, currentFan: FanState) async throws -> FanState {
        switch mode {
        case .systemAuto:
            try await restoreAutoViaXPC(fanID: fanID)
            var restored = currentFan
            restored.mode = .systemAuto
            restored.targetRPM = nil
            return restored
        case let .manual(targetRPM):
            let clampedRPM = currentFan.clampedRPM(targetRPM)
            try await setManualViaXPC(fanID: fanID, rpm: clampedRPM)
            var updated = currentFan
            updated.mode = .manual(targetRPM: clampedRPM)
            updated.targetRPM = clampedRPM
            updated.currentRPM = clampedRPM
            return updated
        }
    }

    public func restoreAutomaticFanControl(fans: [FanState]) async {
        for fan in fans {
            try? await restoreAutoViaXPC(fanID: fan.id)
        }
    }

    private func setManualViaXPC(fanID: Int, rpm: Int) async throws {
        try await withXPCProxy { proxy, finish in
            proxy.setManualFanTarget(NSNumber(value: fanID), rpm: NSNumber(value: rpm)) { success, message in
                finish(Self.result(success: success, message: message))
            }
        }
    }

    private func restoreAutoViaXPC(fanID: Int) async throws {
        try await withXPCProxy { proxy, finish in
            proxy.restoreAutomaticFanControl(NSNumber(value: fanID)) { success, message in
                finish(Self.result(success: success, message: message))
            }
        }
    }

    private func withXPCProxy(
        _ body: @escaping (CoolBoardFanControlXPC, @escaping (Result<Void, Error>) -> Void) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let box = ContinuationBox(continuation)
            let connection = NSXPCConnection(machServiceName: Self.machServiceName, options: .privileged)
            connection.remoteObjectInterface = NSXPCInterface(with: CoolBoardFanControlXPC.self)
            connection.interruptionHandler = {
                box.resume(.failure(FanControlError.helperUnavailable("CoolBoard privileged helper interrupted.")))
            }
            connection.invalidationHandler = {
                box.resume(.failure(FanControlError.helperUnavailable("CoolBoard privileged helper is not installed or not signed.")))
            }
            connection.resume()

            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                box.resume(.failure(FanControlError.helperUnavailable(error.localizedDescription)))
            }) as? CoolBoardFanControlXPC else {
                connection.invalidate()
                box.resume(.failure(FanControlError.helperUnavailable("CoolBoard privileged helper is not available.")))
                return
            }

            body(proxy) { result in
                connection.invalidate()
                box.resume(result)
            }
        }
    }

    private static func result(success: Bool, message: String?) -> Result<Void, Error> {
        if success {
            return .success(())
        }
        return .failure(FanControlError.writeRejected(message ?? "CoolBoard privileged helper rejected the fan-control request."))
    }
}

private final class ContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?

    init(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<Void, Error>) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()

        guard let continuation else {
            return
        }

        switch result {
        case .success:
            continuation.resume()
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }
}
