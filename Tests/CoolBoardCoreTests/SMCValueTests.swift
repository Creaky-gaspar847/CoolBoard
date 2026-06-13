import CoolBoardCore
import XCTest

final class SMCValueTests: XCTestCase {
    func testDecodesSP78Temperature() {
        let value = SMCValue(key: "TC0P", type: "sp78", bytes: [0x31, 0x80])
        XCTAssertEqual(try XCTUnwrap(value.numericValue), 49.5, accuracy: 0.001)
    }

    func testDecodesFPE2RPM() {
        let value = SMCValue(key: "F0Ac", type: "fpe2", bytes: [0x21, 0x20])
        XCTAssertEqual(try XCTUnwrap(value.numericValue), 2120, accuracy: 0.001)
    }

    func testDecodesNativeFloatRPM() {
        let value = SMCValue(key: "F0Ac", type: "flt ", bytes: SMCValue.floatBytes(for: 2317))
        XCTAssertEqual(try XCTUnwrap(value.numericValue), 2317, accuracy: 0.001)
    }

    func testReturnsNilForUnknownSMCType() {
        let value = SMCValue(key: "XXXX", type: "ch8*", bytes: [0x00])
        XCTAssertNil(value.numericValue)
    }

    func testEncodesFPE2RPM() {
        XCTAssertEqual(SMCValue.fpe2Bytes(for: 2120), [0x21, 0x20])
    }

    func testSMCKeyDataPayloadUsesExpectedAppleSMCStride() {
        XCTAssertEqual(AppleSMCClient.smcKeyDataStride, 80)
    }
}
