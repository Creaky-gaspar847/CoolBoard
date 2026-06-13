import CoolBoardCore
import SwiftUI

struct ThermalBoardView: View {
    @ObservedObject var store: ThermalStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            presetBar

            HStack(alignment: .top, spacing: 16) {
                FanControlListView(store: store)
                    .frame(minWidth: 600, maxWidth: .infinity, alignment: .topLeading)

                TemperatureSensorTableView(sensors: store.snapshot.temperatureSensors)
                    .frame(width: 360, alignment: .topLeading)
            }

            footerStatus
        }
        .padding(.horizontal, 42)
        .padding(.top, 44)
        .padding(.bottom, 38)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 14) {
                PixelMark()
                    .frame(width: 38, height: 38)
                    .help("CoolBoard")

                VStack(alignment: .leading, spacing: 2) {
                    Text("COOLBOARD")
                        .font(.system(size: 32, weight: .medium, design: .monospaced))
                        .tracking(2)
                    Text("APPLE SILICON COOLING CONTROL")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(CoolBoardTheme.textMuted)
                }

                Spacer()
            }

            DividerLine(axis: .horizontal)
        }
    }

    private var presetBar: some View {
        HStack(spacing: 12) {
            Text("Active preset:")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(CoolBoardTheme.textSoft)

            Menu {
                Button("Custom*") {
                    store.markCustomPreset()
                }
                Divider()
                ForEach(ThermalStore.presetPercents, id: \.self) { percent in
                    Button("\(percent)%") {
                        store.selectGlobalPreset(percent)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(store.presetDisplayLabel)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(CoolBoardTheme.panelStrong)
                .overlay(Rectangle().stroke(CoolBoardTheme.lineMuted, lineWidth: 1))
            }
            .menuStyle(.button)

            Button {
                Task { await store.resetFanTargetsToZero() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 34, height: 32)
            }
            .buttonStyle(.plain)
            .background(CoolBoardTheme.panelStrong)
            .overlay(Rectangle().stroke(CoolBoardTheme.lineMuted, lineWidth: 1))
            .help("Reset fan targets to 0 RPM")
            .disabled(store.isApplyingFanMode)

            Spacer()

            Text(boardStatusLabel)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(CoolBoardTheme.textMuted)
        }
        .padding(.vertical, 6)
    }

    private var boardStatusLabel: String {
        if store.snapshot.fans.contains(where: { $0.mode != .systemAuto }) {
            return "MANUAL"
        }
        return store.snapshot.thermalState.rawValue.uppercased()
    }

    private var footerStatus: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(footerMessage)
                .layoutPriority(1)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 12)

            Text("Updated \(ThermalFormatters.ageDescription(snapshotDate: store.snapshot.lastUpdated))")
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(CoolBoardTheme.textMuted)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoolBoardTheme.panel)
        .overlay(Rectangle().stroke(CoolBoardTheme.lineMuted, lineWidth: 1))
    }

    private var footerMessage: String {
        if let errorMessage = store.errorMessage {
            return errorMessage
        }

        if let statusMessage = store.statusMessage {
            return statusMessage
        }

        return switch store.snapshot.hardwareStatus {
        case let .monitoringUnavailable(message):
            message
        default:
            store.snapshot.hardwareStatus.message
        }
    }
}

struct TemperatureSensorTableView: View {
    let sensors: [SensorReading]

    private var rows: [SensorReading] {
        sensors.sorted { lhs, rhs in
            if lhs.category.rawValue == rhs.category.rawValue {
                return lhs.displayName < rhs.displayName
            }
            return lhs.category.rawValue < rhs.category.rawValue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Temperature sensors:")
                Text("\(rows.count) detected")
                    .foregroundStyle(CoolBoardTheme.textMuted)
                Spacer(minLength: 0)
            }
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                HStack {
                    Text("Sensor")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    DividerLine(axis: .vertical)
                        .frame(height: 20)
                    Text("Value C")
                        .frame(width: 72, alignment: .trailing)
                }
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(CoolBoardTheme.textSoft)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(CoolBoardTheme.panelStrong)

                DividerLine(axis: .horizontal)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        if rows.isEmpty {
                            EmptyTemperatureState()
                                .frame(height: 96)
                        } else {
                            ForEach(rows) { sensor in
                                TemperatureSensorRow(reading: sensor)
                            }
                        }
                    }
                }
                .scrollIndicators(.visible)
                .frame(height: rowListHeight)
            }
            .background(CoolBoardTheme.panel)
            .overlay(Rectangle().stroke(CoolBoardTheme.lineMuted, lineWidth: 1))
        }
    }

    private var rowListHeight: CGFloat {
        min(max(CGFloat(max(rows.count, 3)) * 30, 96), 330)
    }
}

struct EmptyTemperatureState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NO TEMPERATURE SENSORS")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
            Text("CoolBoard did not receive any Celsius sensor values from AppleSMC or IORegistry.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CoolBoardTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(.white.opacity(0.025))
    }
}

struct TemperatureSensorRow: View {
    let reading: SensorReading

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 18)
                .foregroundStyle(CoolBoardTheme.textSoft)

            Text(reading.displayName)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(valueText)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(reading.id.hashValue.isMultiple(of: 2) ? .white.opacity(0.035) : .clear)
    }

    private var valueText: String {
        guard reading.value != nil else {
            return "--"
        }
        return ThermalFormatters.sensorValue(reading)
    }

    private var iconName: String {
        switch reading.category {
        case .cpu:
            "cpu"
        case .gpu:
            "display"
        case .airport:
            "wifi"
        case .power:
            "bolt"
        case .battery:
            "battery.75percent"
        case .system:
            "waveform.path.ecg"
        case .unknown:
            "sensor"
        }
    }
}

struct SensorRow: View {
    let reading: SensorReading

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(reading.displayName.uppercased())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(CoolBoardTheme.textSoft)
                Text("\(reading.key) / \(reading.source.rawValue)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CoolBoardTheme.textMuted)
            }
            Spacer()
            Text("\(ThermalFormatters.sensorValue(reading)) \(reading.unit)")
                .font(.system(size: 18, weight: .medium, design: .monospaced))
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            DividerLine(axis: .horizontal)
        }
    }
}

struct SensorTile: View {
    let reading: SensorReading

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(reading.category.rawValue.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(CoolBoardTheme.textMuted)
                Spacer()
                Text(reading.key)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CoolBoardTheme.textMuted)
            }

            Spacer(minLength: 10)

            Text(reading.displayName.uppercased())
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(ThermalFormatters.sensorValue(reading))
                    .font(.system(size: 30, weight: .medium, design: .monospaced))
                Text(reading.unit)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(CoolBoardTheme.textMuted)
            }
        }
        .frame(height: 132)
        .padding(16)
        .background(CoolBoardTheme.panel)
        .overlay(Rectangle().stroke(CoolBoardTheme.lineMuted, lineWidth: 1))
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
            Text(message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(CoolBoardTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
}
