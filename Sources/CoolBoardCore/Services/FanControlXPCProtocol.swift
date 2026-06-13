import Foundation

public enum CoolBoardXPC {
    public static let machServiceName = "com.coolboard.Helper"
}

@objc(CoolBoardFanControlXPC)
public protocol CoolBoardFanControlXPC {
    func listFans(withReply reply: @escaping ([[String: NSNumber]], String?) -> Void)
    func setManualFanTarget(_ fanID: NSNumber, rpm: NSNumber, withReply reply: @escaping (Bool, String?) -> Void)
    func restoreAutomaticFanControl(_ fanID: NSNumber, withReply reply: @escaping (Bool, String?) -> Void)
}
