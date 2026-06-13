import AppKit
import CoolBoardCore
import SwiftUI

@main
struct CoolBoardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = ThermalStore()

    var body: some Scene {
        WindowGroup("CoolBoard", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 1080, minHeight: 720)
        }
        .defaultSize(width: 1100, height: 740)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Sensors") {
                    NotificationCenter.default.post(name: .coolBoardRefreshRequested, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        MenuBarExtra("CoolBoard", systemImage: "fan") {
            MenuBarQuickControlView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func systemWillSleep() {
        NotificationCenter.default.post(name: .coolBoardSystemWillSleep, object: nil)
    }

    @objc private func systemDidWake() {
        NotificationCenter.default.post(name: .coolBoardSystemDidWake, object: nil)
    }
}

extension Notification.Name {
    static let coolBoardRefreshRequested = Notification.Name("CoolBoardRefreshRequested")
    static let coolBoardSystemWillSleep = Notification.Name("CoolBoardSystemWillSleep")
    static let coolBoardSystemDidWake = Notification.Name("CoolBoardSystemDidWake")
}
