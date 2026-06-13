import CoolBoardCore
import SwiftUI

struct FanControlListView: View {
    @ObservedObject var store: ThermalStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Fans")
                Text("\(store.snapshot.detectedFanCount) detected")
                    .foregroundStyle(CoolBoardTheme.textMuted)
                Spacer(minLength: 0)
            }
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                fanTableHeader

                DividerLine(axis: .horizontal)

                if store.snapshot.fans.isEmpty {
                    EmptyFanTableState(message: store.snapshot.hardwareStatus.message)
                        .frame(minHeight: 420)
                } else {
                    ForEach(store.snapshot.fans) { fan in
                        FanControlRowView(store: store, fan: fan)
                    }
                }
            }
            .background(CoolBoardTheme.panel)
            .overlay(Rectangle().stroke(CoolBoardTheme.lineMuted, lineWidth: 1))
        }
    }

    private var fanTableHeader: some View {
        HStack(spacing: 0) {
            Text("Fan")
                .frame(width: 170, alignment: .center)

            DividerLine(axis: .vertical)
                .frame(height: 22)

            Text("Min/Current/Max RPM")
                .frame(width: 190, alignment: .center)

            DividerLine(axis: .vertical)
                .frame(height: 22)

            Text("Control")
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .foregroundStyle(CoolBoardTheme.textSoft)
        .frame(height: 38)
        .background(CoolBoardTheme.panelStrong)
    }
}

struct FanControlRowView: View {
    @ObservedObject var store: ThermalStore
    let fan: FanState

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                FanGlyph()
                Text(fan.name)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .lineLimit(1)
            }
            .frame(width: 170, alignment: .leading)
            .padding(.leading, 14)

            DividerLine(axis: .vertical)

            HStack(spacing: 10) {
                Text("\(fan.minRPM)")
                Text("-")
                    .foregroundStyle(CoolBoardTheme.textMuted)
                Text(currentRPMText)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                Text("-")
                    .foregroundStyle(CoolBoardTheme.textMuted)
                Text("\(fan.maxRPM)")
            }
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .frame(width: 190)

            DividerLine(axis: .vertical)

            HStack(spacing: 10) {
                if fan.isControllable {
                    Button {
                        Task { await store.applyAutoMode(fanID: fan.id) }
                    } label: {
                        Text("Auto")
                            .frame(width: 68)
                    }
                    .disabled(store.isApplyingFanMode)
                    .opacity(fan.mode == .systemAuto ? 1 : 0.62)

                    Menu {
                        ForEach(ThermalStore.presetPercents, id: \.self) { percent in
                            Button("\(percent)% - \(fan.rpm(forPowerPercent: percent)) RPM") {
                                store.requestPreset(percent, for: fan)
                            }
                        }
                        Divider()
                        Button("Set custom \(Int(store.targetRPM(for: fan).rounded())) RPM") {
                            store.requestManualMode(for: fan)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if fan.mode != .systemAuto {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 5, height: 5)
                            }
                            Text(manualControlLabel)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(width: 128)
                    }
                    .help(fan.mode.label)
                    .disabled(store.isApplyingFanMode)
                } else {
                    Text("Unavailable")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(CoolBoardTheme.textMuted)
                        .lineLimit(1)
                        .frame(width: 108)
                        .help(fan.controlMessage ?? "Fan control is unavailable.")
                }
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 14)
        }
        .frame(height: 58)
        .background(fan.id.isMultiple(of: 2) ? .white.opacity(0.035) : .white.opacity(0.015))
        .overlay(alignment: .bottom) {
            DividerLine(axis: .horizontal)
        }
    }

    private var currentRPMText: String {
        fan.currentRPM.map(String.init) ?? "--"
    }

    private var manualControlLabel: String {
        switch fan.mode {
        case .systemAuto:
            "Manual"
        case let .manual(targetRPM):
            "\(targetRPM)"
        }
    }
}

struct FanGlyph: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(CoolBoardTheme.panelStrong)
                .frame(width: 38, height: 38)
                .overlay(Rectangle().stroke(CoolBoardTheme.lineMuted, lineWidth: 1))
            Image(systemName: "fan")
                .font(.system(size: 19, weight: .medium))
        }
    }
}

struct EmptyFanTableState: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NO FANS DETECTED")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
            Text(message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(CoolBoardTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(18)
        .background(alternatingRows)
    }

    private var alternatingRows: some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { index in
                Rectangle()
                    .fill(index.isMultiple(of: 2) ? .white.opacity(0.025) : .clear)
                    .frame(height: 58)
            }
        }
    }
}

struct FanPresetStrip: View {
    @ObservedObject var store: ThermalStore
    let fan: FanState

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ThermalStore.presetPercents, id: \.self) { percent in
                Button {
                    store.requestPreset(percent, for: fan)
                } label: {
                    VStack(spacing: 3) {
                        Text("\(percent)%")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                        Text("\(fan.rpm(forPowerPercent: percent))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(CoolBoardTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(CoolBoardTheme.panelStrong)
                    .overlay(Rectangle().stroke(CoolBoardTheme.lineMuted, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("\(percent)% = \(fan.rpm(forPowerPercent: percent)) RPM")
                .disabled(store.isApplyingFanMode)
                .disabled(!fan.isControllable)
            }
        }
    }
}
