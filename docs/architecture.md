# CoolBoard Architecture

CoolBoard separates the UI, read-only hardware telemetry, and privileged writes.

## Layers

`CoolBoard` is the SwiftUI app. It owns the desktop UI, polling loop, automatic preset application, and safe user feedback.

The app uses one shared `ThermalStore` across the main window and `MenuBarExtra`, so quick controls and the full one-page dashboard read and write the same fan target state.

The main window intentionally prioritizes fan-level control over telemetry: a table-style fan panel is the primary surface, with sensors kept in a secondary table. The fan table is driven by AppleSMC `FNum` and detected `F*` fan snapshots. If AppleSMC returns `FNum=0`, the hardware service returns an empty fan list, the UI shows `0 detected`, and manual fan controls stay disabled instead of inventing placeholder fan rows.

`CoolBoardCore` contains stable domain models, formatting helpers, and the hardware service protocol. Tests depend on this module instead of the app target.

`AppleSiliconHardwareService` is the production service. It reads public system thermal state, IORegistry battery temperatures, dynamic AppleSMC `T*` temperature keys, and AppleSMC fan RPM keys. It does not invent temperature data when macOS does not expose it.

`PrivilegedFanControlClient` is the app-side boundary for privileged helper fan writes. `AppleSiliconHardwareService` tries that path first and falls back to direct AppleSMC writes in developer builds when the helper is unavailable. On most Apple Silicon Macs, restricted SMC writes require a root helper.

`CoolBoardHelper` is a buildable helper scaffold. It exposes the intended mach service name and command contract for contributors, and it contains the private SMC write sequence for manual target RPM and Auto restore.

The local run script embeds the helper in `CoolBoard.app/Contents/Library/LaunchServices/CoolBoardHelper`. That path is intentionally staged for signing and `SMAppService` work; embedding alone does not install or bless the helper. For development, `script/install_helper.sh` installs the helper as a root LaunchDaemon with the `com.coolboard.Helper` Mach service.

## Apple Silicon Constraints

Apple Silicon temperature and fan controls are not public macOS APIs. Any SMC write path must be defensive, scoped, and reversible. CoolBoard applies explicit user preset clicks immediately, clamps every target, and restores Auto during startup, quit, sleep, wake, or failed writes. Sleep and wake invalidate manual targets instead of resuming them automatically.

For production distribution, raw fan writes should live behind a signed helper installed with `SMAppService`. The developer build includes `script/install_helper.sh` for local root-helper installation, `script/package_release.sh` for a shareable unsigned PKG installer, and a direct AppleSMC fallback for diagnostics. The helper should:

- be installed with `SMAppService`;
- expose a minimal XPC API;
- validate fan identifiers;
- clamp RPM to SMC-reported min/max;
- return Auto mode on crash, shutdown, sleep, wake, or failed writes;
- log rejected writes without retry loops.

## Sensor Discovery

CoolBoard probes a small named catalog first:

- `TC0P`, `TC0E`, `TC0F`: CPU proximity and cluster temperatures.
- `TG0P`: GPU proximity.
- `TA0P`: AirPort proximity.
- `TB0T`: battery pack.
- `TP0P`, `PMGR`: power manager family.

These keys are private and model-dependent. A missing key is a normal runtime state, not a crash condition.

After that curated pass, CoolBoard enumerates AppleSMC keys through `#KEY`/read-index, filters temperature-like `T*` keys, reads plausible numeric values, and labels broad families by prefix (`TC` CPU, `TG`/`TSG` GPU, `TA` AirPort, `TB` battery, `TP` power, `TM` memory, `TN` NAND). The UI's temperature table is fed only by available Celsius readings, so the right-side count reflects the sensors actually exposed on the current Mac. This keeps model-specific sensors visible without vendoring GPL sensor catalogs.

## Helper Contract

The helper target can be inspected with:

```bash
swift run CoolBoardHelper -- --contract
```

For local service-loop inspection:

```bash
COOLBOARD_RUN_XPC_SERVICE=1 swift run CoolBoardHelper
```

The app-side client uses `NSXPCConnection(machServiceName:options: .privileged)` and expects a signed helper registered under the same mach service name.

The intended service name is `com.coolboard.Helper`. The only allowed actions are:

- `listFans()`;
- `setFanMode(fanID, systemAuto)`;
- `setFanMode(fanID, manualRPM)`;
- `restoreAutomaticFanControl()`.

The helper must validate every fan id, clamp every RPM request, and return a typed error for unavailable hardware, missing permissions, and rejected writes.

Manual fan writes use the Apple Silicon research sequence: detect the mode key casing (`F{id}md` or `F{id}Md`), try direct manual mode, fall back to `Ftst=1` with retries, then write `F{id}Tg` using the target key's actual data format. Apple Silicon RPM target keys can be native-endian `flt` rather than Intel-style `fpe2`. Auto restore writes the detected mode key back to `0`, clears the target, and resets `Ftst` only when no other fan remains manual.

## Failure Modes

If monitoring is unavailable, the UI remains usable and shows a clear hardware status message.

If the helper is missing, manual mode falls back to direct AppleSMC writes in the developer build. If AppleSMC is unavailable or macOS rejects the write, the UI shows both the helper error and the direct-SMC error.

If a write fails, CoolBoard refreshes telemetry and attempts to restore Auto through the helper or direct AppleSMC fallback.

## Licensing

CoolBoard is MIT. GPL projects such as iSMC can be used for research only. Do not copy GPL source into this repository.
