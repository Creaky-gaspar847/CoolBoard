import AppKit
import CoolBoardCore
import SwiftUI

struct MenuBarQuickControlView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var store: ThermalStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                PixelMark()
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text("COOLBOARD")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                    Text(store.snapshot.thermalState.rawValue.uppercased())
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(CoolBoardTheme.textMuted)
                }

                Spacer()

                Button {
                    Task { await store.resetFanTargetsToZero() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(store.isApplyingFanMode || store.snapshot.fans.filter(\.isControllable).isEmpty)
                .help("Set all fans to 0%")
            }

            DividerLine(axis: .horizontal)

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            } label: {
                Label("Open Full View", systemImage: "rectangle.inset.filled")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if store.snapshot.fans.isEmpty {
                EmptyStateView(
                    title: "NO FANS DETECTED",
                    message: store.snapshot.hardwareStatus.message
                )
            } else {
                GlobalFanPresetBlock(store: store, fans: store.snapshot.fans)

                ForEach(store.snapshot.fans) { fan in
                    quickFanBlock(fan)
                }
            }

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CoolBoardTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 360)
        .background(CoolBoardTheme.background)
        .foregroundStyle(.white)
        .font(.system(.body, design: .monospaced))
        .task { store.start() }
    }

    private func quickFanBlock(_ fan: FanState) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(fan.name.uppercased())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))

                Text(fanStatusText(fan))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(CoolBoardTheme.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            Button {
                Task { await store.applyAutoMode(fanID: fan.id) }
            } label: {
                Text("Auto")
                    .frame(width: 70)
            }
            .disabled(store.isApplyingFanMode || !fan.isControllable)
            .help(fan.isControllable ? "Return \(fan.name) to Auto" : fan.controlMessage ?? "Fan control is unavailable.")
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(CoolBoardTheme.panel)
        .overlay(Rectangle().stroke(CoolBoardTheme.lineMuted, lineWidth: 1))
    }

    private func fanStatusText(_ fan: FanState) -> String {
        let rpm = fan.currentRPM.map { "\($0) RPM" } ?? "-- RPM"
        switch fan.mode {
        case .systemAuto:
            return "\(rpm) / AUTO"
        case let .manual(targetRPM):
            return "\(rpm) / TARGET \(targetRPM)"
        }
    }
}

struct GlobalFanPresetBlock: View {
    @ObservedObject var store: ThermalStore
    let fans: [FanState]

    private var controllableFans: [FanState] {
        fans.filter(\.isControllable)
    }

    private var referenceFan: FanState? {
        controllableFans.first
    }

    private var averageRPMText: String {
        let values = fans.compactMap(\.currentRPM)
        guard !values.isEmpty else {
            return "-- RPM"
        }
        let average = values.reduce(0, +) / values.count
        return "\(average) RPM"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(fans.count == 1 ? "SYSTEM FAN" : "ALL DETECTED FANS")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                    Text("GLOBAL PERCENT")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(CoolBoardTheme.textMuted)
                }

                Spacer()

                Text(averageRPMText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }

            if let referenceFan {
                HStack(spacing: 8) {
                    ForEach(ThermalStore.presetPercents, id: \.self) { percent in
                        Button {
                            store.selectGlobalPreset(percent)
                        } label: {
                            VStack(spacing: 3) {
                                Text("\(percent)%")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                Text("\(referenceFan.rpm(forPowerPercent: percent))")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(CoolBoardTheme.textMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(CoolBoardTheme.panelStrong)
                            .overlay(Rectangle().stroke(CoolBoardTheme.lineMuted, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .help(percent == 0 ? "Set all fans to 0 RPM" : "Set all fans to \(percent)%")
                        .disabled(store.isApplyingFanMode || controllableFans.isEmpty)
                    }
                }
            } else {
                Text("Global fan control is unavailable.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CoolBoardTheme.textMuted)
            }
        }
        .padding(12)
        .background(CoolBoardTheme.panel)
        .overlay(Rectangle().stroke(CoolBoardTheme.lineMuted, lineWidth: 1))
    }
}
