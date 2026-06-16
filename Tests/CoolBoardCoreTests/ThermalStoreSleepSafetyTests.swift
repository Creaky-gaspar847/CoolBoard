@testable import CoolBoard
import CoolBoardCore
import XCTest

@MainActor
final class ThermalStoreSleepSafetyTests: XCTestCase {
    func testWakeDoesNotResumeManualFanTargets() async throws {
        let service = SleepSafetySpyService()
        let store = ThermalStore(service: service)

        await store.refresh()
        let fan = try XCTUnwrap(store.snapshot.fans.first)

        store.requestManualMode(for: fan, targetRPM: fan.maxRPM)
        await service.waitForSetFanModeCallCount(1)
        await store.refresh()

        XCTAssertEqual(store.snapshot.fans.first?.mode, .manual(targetRPM: fan.maxRPM))

        await store.handleSystemWillSleep()
        XCTAssertEqual(store.snapshot.fans.first?.mode, .systemAuto)

        await store.handleSystemDidWake()

        let setFanModeCalls = await service.setFanModeCalls
        let manualWrites = setFanModeCalls.filter { call in
            if case .manual = call.mode {
                return true
            }
            return false
        }

        let restoreAutomaticFanControlCallCount = await service.restoreCallCount()

        XCTAssertEqual(manualWrites.count, 1)
        XCTAssertEqual(restoreAutomaticFanControlCallCount, 2)
        XCTAssertEqual(store.snapshot.fans.first?.mode, .systemAuto)
        XCTAssertEqual(store.statusMessage, "Wake detected; fan control remains Auto")
    }
}

private struct FanModeCall: Sendable {
    let fanID: Int
    let mode: CoolingMode
}

private actor SleepSafetySpyService: ThermalHardwareServicing {
    private var fan = FanState(
        id: 0,
        name: "System Fan",
        currentRPM: 2200,
        minRPM: 1200,
        maxRPM: 6200,
        mode: .systemAuto
    )
    private(set) var setFanModeCalls: [FanModeCall] = []
    private(set) var restoreAutomaticFanControlCallCount = 0

    func fetchSnapshot() async -> ThermalSnapshot {
        ThermalSnapshot(
            sensors: [],
            fans: [fan],
            thermalState: .nominal,
            lastUpdated: Date()
        )
    }

    func setFanMode(fanID: Int, mode: CoolingMode) async throws -> FanState {
        guard fanID == fan.id else {
            throw FanControlError.invalidFan(fanID)
        }

        setFanModeCalls.append(FanModeCall(fanID: fanID, mode: mode))
        switch mode {
        case .systemAuto:
            fan.mode = .systemAuto
            fan.targetRPM = nil
            fan.currentRPM = 2200
        case let .manual(targetRPM):
            let clamped = fan.clampedRPM(targetRPM)
            fan.mode = .manual(targetRPM: clamped)
            fan.targetRPM = clamped
            fan.currentRPM = clamped
        }
        return fan
    }

    func restoreAutomaticFanControl() async {
        restoreAutomaticFanControlCallCount += 1
        fan.mode = .systemAuto
        fan.targetRPM = nil
        fan.currentRPM = 2200
    }

    func waitForSetFanModeCallCount(_ expectedCount: Int) async {
        for _ in 0..<100 where setFanModeCalls.count < expectedCount {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func restoreCallCount() -> Int {
        restoreAutomaticFanControlCallCount
    }
}
