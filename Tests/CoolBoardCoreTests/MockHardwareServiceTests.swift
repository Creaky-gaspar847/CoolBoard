import CoolBoardCore
import XCTest

final class MockHardwareServiceTests: XCTestCase {
    func testMockServiceRestoresAutoMode() async throws {
        let service = MockThermalHardwareService()
        let initial = await service.fetchSnapshot()
        let fan = try XCTUnwrap(initial.fans.first)

        let manual = try await service.setFanMode(fanID: fan.id, mode: .manual(targetRPM: fan.maxRPM + 2000))
        XCTAssertEqual(manual.mode, .manual(targetRPM: fan.maxRPM))
        XCTAssertEqual(manual.currentRPM, fan.maxRPM)

        await service.restoreAutomaticFanControl()
        let restored = await service.fetchSnapshot()
        XCTAssertEqual(restored.fans.first?.mode, .systemAuto)
        XCTAssertNil(restored.fans.first?.targetRPM)
    }

    func testMockServiceRejectsInvalidFan() async {
        let service = MockThermalHardwareService()

        do {
            _ = try await service.setFanMode(fanID: 99, mode: .systemAuto)
            XCTFail("Expected invalid fan error")
        } catch let error as FanControlError {
            XCTAssertEqual(error, .invalidFan(99))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
