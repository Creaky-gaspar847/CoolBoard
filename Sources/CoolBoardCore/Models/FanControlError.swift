import Foundation

public enum FanControlError: LocalizedError, Equatable, Sendable {
    case unsupportedArchitecture(String)
    case helperUnavailable(String)
    case permissionDenied(String)
    case writeRejected(String)
    case invalidFan(Int)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedArchitecture(message),
             let .helperUnavailable(message),
             let .permissionDenied(message),
             let .writeRejected(message):
            message
        case let .invalidFan(id):
            "Fan \(id) is not available on this Mac."
        }
    }
}
