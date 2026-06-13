import Combine
import CoolBoardCore
import Foundation

struct ManualFanTarget: Identifiable {
    var id: Int { fan.id }
    let fan: FanState
    let targetRPM: Int
}

@MainActor
final class ThermalStore: ObservableObject {
    @Published var snapshot: ThermalSnapshot = .empty
    @Published var selectedCategory: SensorCategory = .cpu
    @Published var selectedFanID: Int?
    @Published var targetRPM: Double = 2400
    @Published var targetRPMByFanID: [Int: Double] = [:]
    @Published var isApplyingFanMode = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var activePresetLabel = "Custom*"

    static let presetPercents = [10, 20, 40, 60, 80, 100]

    private let service: any ThermalHardwareServicing
    private var pollTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private var confirmedManualTargetsByFanID: [Int: Int] = [:]
    private var suspendedManualTargetsByFanID: [Int: Int] = [:]
    private var didRestoreAutoOnStart = false

    init(service: any ThermalHardwareServicing = AppleSiliconHardwareService()) {
        self.service = service

        NotificationCenter.default.publisher(for: .coolBoardRefreshRequested)
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .coolBoardSystemWillSleep)
            .sink { [weak self] _ in
                Task { await self?.handleSystemWillSleep() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .coolBoardSystemDidWake)
            .sink { [weak self] _ in
                Task { await self?.handleSystemDidWake() }
            }
            .store(in: &cancellables)
    }

    var selectedFan: FanState? {
        guard let selectedFanID else {
            return snapshot.fans.first
        }
        return snapshot.fans.first(where: { $0.id == selectedFanID }) ?? snapshot.fans.first
    }

    var filteredSensors: [SensorReading] {
        snapshot.sensors.filter { $0.category == selectedCategory }
    }

    var presetDisplayLabel: String {
        return activePresetLabel
    }

    var sensorsByCategory: [(category: SensorCategory, sensors: [SensorReading])] {
        SensorCategory.allCases.compactMap { category in
            let sensors = snapshot.sensors.filter { $0.category == category }
            return sensors.isEmpty ? nil : (category, sensors)
        }
    }

    func start() {
        guard pollTask == nil else {
            return
        }

        pollTask = Task { [weak self] in
            await self?.restoreAutoOnStartIfNeeded()
            while !Task.isCancelled {
                await self?.refresh()
                await self?.reassertManualTargetsIfNeeded()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopAndRestore() {
        pollTask?.cancel()
        pollTask = nil
        confirmedManualTargetsByFanID.removeAll()
        suspendedManualTargetsByFanID.removeAll()
        Task {
            await service.restoreAutomaticFanControl()
        }
    }

    func handleSystemWillSleep() async {
        suspendedManualTargetsByFanID = confirmedManualTargetsByFanID
        confirmedManualTargetsByFanID.removeAll()

        await service.restoreAutomaticFanControl()
        activePresetLabel = "Custom*"
        statusMessage = suspendedManualTargetsByFanID.isEmpty
            ? "Sleep detected; fan control is in Auto"
            : "Sleep detected; manual fan control paused"
        await refresh()
    }

    func handleSystemDidWake() async {
        await refresh()

        guard !suspendedManualTargetsByFanID.isEmpty else {
            statusMessage = "Wake detected; monitoring resumed"
            return
        }

        let targets = suspendedManualTargetsByFanID.compactMap { fanID, targetRPM in
            snapshot.fans.first(where: { $0.id == fanID && $0.isControllable }).map { fan in
                ManualFanTarget(fan: fan, targetRPM: fan.clampedRPM(targetRPM))
            }
        }
        suspendedManualTargetsByFanID.removeAll()

        guard !targets.isEmpty else {
            statusMessage = "Wake detected; manual targets could not be resumed"
            return
        }

        let applyingMessage = "Wake detected; resuming fan targets"
        await applyFanModes(targets, applyingMessage: applyingMessage)
    }

    func refresh() async {
        var nextSnapshot = await service.fetchSnapshot()
        applyConfirmedManualTargets(to: &nextSnapshot)
        snapshot = nextSnapshot

        if selectedFanID == nil {
            selectedFanID = nextSnapshot.fans.first?.id
        }

        if let fan = selectedFan {
            let defaultRPM = Double(fan.targetRPM ?? fan.currentRPM ?? max(fan.minRPM, 1800))
            targetRPM = targetRPMByFanID[fan.id] ?? defaultRPM
        }

        for fan in nextSnapshot.fans where targetRPMByFanID[fan.id] == nil {
            targetRPMByFanID[fan.id] = Double(fan.targetRPM ?? fan.currentRPM ?? max(fan.minRPM, 1800))
        }
    }

    func targetRPM(for fan: FanState) -> Double {
        targetRPMByFanID[fan.id] ?? Double(fan.targetRPM ?? fan.currentRPM ?? max(fan.minRPM, 1800))
    }

    func setTargetRPM(_ rpm: Double, for fan: FanState) {
        let clamped = fan.clampedRPM(Int(rpm.rounded()))
        targetRPMByFanID[fan.id] = Double(clamped)
        if fan.id == selectedFanID {
            targetRPM = Double(clamped)
        }
    }

    func requestManualMode(for fan: FanState, targetRPM requestedRPM: Int? = nil, sourceLabel: String = "Manual") {
        guard fan.isControllable else {
            errorMessage = fan.controlMessage ?? "Fan control is unavailable on this Mac."
            statusMessage = nil
            return
        }

        let rpm = fan.clampedRPM(requestedRPM ?? Int(targetRPM(for: fan).rounded()))
        targetRPMByFanID[fan.id] = Double(rpm)
        let applyingMessage = "Applying \(sourceLabel): \(fan.name) \(rpm) RPM"
        statusMessage = applyingMessage

        Task {
            await applyFanModes([ManualFanTarget(fan: fan, targetRPM: rpm)], applyingMessage: applyingMessage)
        }
    }

    func requestPreset(_ percent: Int, for fan: FanState) {
        let rpm = fan.rpm(forPowerPercent: percent)
        requestManualMode(for: fan, targetRPM: rpm, sourceLabel: "\(percent)%")
    }

    func selectGlobalPreset(_ percent: Int) {
        let controllableFans = snapshot.fans.filter(\.isControllable)
        guard !controllableFans.isEmpty else {
            errorMessage = "No controllable fans are available."
            statusMessage = nil
            return
        }

        let targets = controllableFans.map { fan in
            let rpm = fan.rpm(forPowerPercent: percent)
            targetRPMByFanID[fan.id] = Double(rpm)
            return ManualFanTarget(fan: fan, targetRPM: rpm)
        }

        let applyingMessage = "Applying \(percent)%: \(targets.map { "\($0.fan.name) \($0.targetRPM) RPM" }.joined(separator: ", "))"
        statusMessage = applyingMessage

        Task {
            await applyFanModes(targets, applyingMessage: applyingMessage)
        }
    }

    func markCustomPreset() {
        activePresetLabel = "Custom*"
    }

    func applyAutoMode(fanID: Int) async {
        await applyFanMode(fanID: fanID, mode: .systemAuto)
    }

    func resetFanTargetsToZero() async {
        isApplyingFanMode = true
        errorMessage = nil
        statusMessage = "Resetting fan targets to 0 RPM"
        defer { isApplyingFanMode = false }

        confirmedManualTargetsByFanID.removeAll()
        suspendedManualTargetsByFanID.removeAll()
        await service.restoreAutomaticFanControl()
        activePresetLabel = "Custom*"
        statusMessage = "Fan targets reset to 0 RPM"
        await refresh()
    }

    private func applyFanMode(fanID: Int, mode: CoolingMode) async {
        isApplyingFanMode = true
        errorMessage = nil
        statusMessage = nil
        defer { isApplyingFanMode = false }

        do {
            _ = try await service.setFanMode(fanID: fanID, mode: mode)
            switch mode {
            case .systemAuto:
                confirmedManualTargetsByFanID.removeValue(forKey: fanID)
            case let .manual(targetRPM):
                confirmedManualTargetsByFanID[fanID] = targetRPM
            }
            applyModeLocally(fanID: fanID, mode: mode)
            statusMessage = successMessage(fanID: fanID, mode: mode)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
            await refresh()
        }
    }

    private func applyFanModes(_ targets: [ManualFanTarget], applyingMessage: String? = nil) async {
        isApplyingFanMode = true
        errorMessage = nil
        statusMessage = applyingMessage
        defer { isApplyingFanMode = false }

        var appliedTargets: [ManualFanTarget] = []
        for target in targets {
            do {
                let clampedTarget = target.fan.clampedRPM(target.targetRPM)
                _ = try await service.setFanMode(
                    fanID: target.fan.id,
                    mode: .manual(targetRPM: clampedTarget)
                )
                confirmedManualTargetsByFanID[target.fan.id] = clampedTarget
                applyModeLocally(fanID: target.fan.id, mode: .manual(targetRPM: clampedTarget))
                appliedTargets.append(ManualFanTarget(fan: target.fan, targetRPM: clampedTarget))
            } catch {
                errorMessage = "\(target.fan.name): \(error.localizedDescription)"
                statusMessage = nil
                break
            }
        }

        if errorMessage == nil, !appliedTargets.isEmpty {
            activePresetLabel = requestLabel(for: appliedTargets)
            statusMessage = "Manual target sent: \(appliedTargets.map { "\($0.fan.name) \($0.targetRPM) RPM" }.joined(separator: ", "))"
        }

        await refresh()
    }

    private func successMessage(fanID: Int, mode: CoolingMode) -> String {
        let fanName = snapshot.fans.first(where: { $0.id == fanID })?.name ?? "Fan \(fanID)"
        switch mode {
        case .systemAuto:
            return "\(fanName) returned to Auto"
        case let .manual(targetRPM):
            return "Manual target sent: \(fanName) \(targetRPM) RPM"
        }
    }

    private func requestLabel(for targets: [ManualFanTarget]) -> String {
        guard !targets.isEmpty else {
            return "Custom*"
        }

        let controllableFanCount = snapshot.fans.filter(\.isControllable).count
        guard targets.count == controllableFanCount else {
            return "Custom*"
        }

        let percents = targets.map { $0.fan.powerPercent(forRPM: $0.targetRPM) }
        if let first = percents.first, percents.allSatisfy({ $0 == first }) {
            return "\(first)%"
        }
        return "Custom*"
    }

    private func applyConfirmedManualTargets(to snapshot: inout ThermalSnapshot) {
        guard !confirmedManualTargetsByFanID.isEmpty else {
            return
        }

        snapshot.fans = snapshot.fans.map { fan in
            guard let targetRPM = confirmedManualTargetsByFanID[fan.id] else {
                return fan
            }

            var fan = fan
            let clampedTarget = fan.clampedRPM(targetRPM)
            fan.mode = .manual(targetRPM: clampedTarget)
            fan.targetRPM = clampedTarget
            return fan
        }
    }

    private func applyModeLocally(fanID: Int, mode: CoolingMode) {
        snapshot.fans = snapshot.fans.map { fan in
            guard fan.id == fanID else {
                return fan
            }

            var fan = fan
            fan.mode = mode
            switch mode {
            case .systemAuto:
                fan.targetRPM = nil
            case let .manual(targetRPM):
                let clampedTarget = fan.clampedRPM(targetRPM)
                fan.mode = .manual(targetRPM: clampedTarget)
                fan.targetRPM = clampedTarget
            }
            return fan
        }
    }

    private func reassertManualTargetsIfNeeded() async {
        guard !confirmedManualTargetsByFanID.isEmpty, !isApplyingFanMode else {
            return
        }

        let fans = snapshot.fans
        for (fanID, targetRPM) in Array(confirmedManualTargetsByFanID) {
            guard let fan = fans.first(where: { $0.id == fanID }), fan.isControllable else {
                continue
            }

            do {
                _ = try await service.setFanMode(
                    fanID: fanID,
                    mode: .manual(targetRPM: fan.clampedRPM(targetRPM))
                )
            } catch {
                errorMessage = "\(fan.name): \(error.localizedDescription)"
                statusMessage = nil
                confirmedManualTargetsByFanID.removeValue(forKey: fanID)
            }
        }
    }

    private func restoreAutoOnStartIfNeeded() async {
        guard !didRestoreAutoOnStart else {
            return
        }
        didRestoreAutoOnStart = true

        await refresh()
        guard snapshot.fans.contains(where: \.isControllable) else {
            return
        }

        confirmedManualTargetsByFanID.removeAll()
        await service.restoreAutomaticFanControl()
        activePresetLabel = "Custom*"
        statusMessage = "Fan control restored to Auto"
        await refresh()
    }
}
