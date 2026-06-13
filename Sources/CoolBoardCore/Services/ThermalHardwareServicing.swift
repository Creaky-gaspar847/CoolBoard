import Foundation

public protocol ThermalHardwareServicing: Sendable {
    func fetchSnapshot() async -> ThermalSnapshot
    func setFanMode(fanID: Int, mode: CoolingMode) async throws -> FanState
    func restoreAutomaticFanControl() async
}
