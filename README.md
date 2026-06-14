# CoolBoard

CoolBoard is a minimal macOS cooling dashboard for Apple Silicon Macs. It uses a monochrome technical UI inspired by instrument panels: live thermal status, best-effort fan telemetry, and guarded manual fan control.

![CoolBoard dashboard](docs/assets/coolboard-dashboard.png)

Website: https://rafinelio.github.io/CoolBoard/

## Install

Download the latest `CoolBoard-macOS-Apple-Silicon.pkg` from [GitHub Releases](https://github.com/Rafinelio/CoolBoard/releases/latest), open it, and follow the installer prompts. The package installs `CoolBoard.app` into `/Applications` and installs the privileged helper needed for manual fan writes.

This first public build is ad-hoc signed, not Developer ID signed or notarized. If Gatekeeper blocks the installer, open it with Control-click > Open. Administrator approval is required because the helper is installed into `/Library/PrivilegedHelperTools`.

Supported baseline:

- Apple Silicon Mac with macOS 14 or later;
- built-in fans exposed through AppleSMC for fan control;
- fanless Apple Silicon MacBook Air models run monitoring only and show `0 detected` fans.

## Status

This repository is push-ready as an open source developer build, not a notarized end-user release.

- Target: macOS 14+, Apple Silicon.
- UI: SwiftUI one-page desktop app with menu-bar quick controls.
- Monitoring: dynamic AppleSMC `T*` temperature discovery, IORegistry battery temperatures, system thermal state, machine basics, and AppleSMC fan RPM keys.
- Fan control: UI, helper/XPC path, Auto restore, sleep/wake handling, and direct AppleSMC developer fallback are implemented. Real manual writes require the privileged helper because macOS rejects restricted SMC writes from a normal user process on most Apple Silicon Macs.

Apple does not provide public temperature or fan-control APIs for Apple Silicon. CoolBoard does not fake temperature values or fan rows. When macOS does not expose a sensor, the app omits it from the temperature table. When AppleSMC reports zero fans, the app shows `0 detected` and disables fan controls. Apple Silicon MacBook Air models are fanless, so manual fan control is expected to be unavailable there.

## Build and Run

```bash
swift test
./script/build_and_run.sh
```

The run script builds the SwiftPM GUI target, stages `dist/CoolBoard.app`, and launches it as a real macOS app bundle.
It also embeds `CoolBoardHelper` at `Contents/Library/LaunchServices/CoolBoardHelper` for the future signed `SMAppService` installation path.

Useful variants:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
swift run CoolBoardHelper -- --contract
swift run CoolBoardHelper -- list
swift run CoolBoardHelper -- sensors
COOLBOARD_RUN_XPC_SERVICE=1 swift run CoolBoardHelper
```

Manual fan control needs the root helper:

```bash
./script/install_helper.sh
./script/uninstall_helper.sh
```

Restart CoolBoard after installing the helper. The script installs a development LaunchDaemon for `com.coolboard.Helper` in `/Library/LaunchDaemons` and `/Library/PrivilegedHelperTools`; it requires `sudo`.

## Package an Installer

Create a shareable developer installer:

```bash
./script/package_release.sh
```

The installer is written to `dist/release/CoolBoard-macOS-Apple-Silicon.pkg`.

It installs:

- `CoolBoard.app` into `/Applications`;
- `CoolBoardHelper` into `/Library/PrivilegedHelperTools/com.coolboard.Helper`;
- `com.coolboard.Helper.plist` into `/Library/LaunchDaemons`.

The package requires administrator approval during installation because the helper is installed as root. There is no Python script or external downloader required for fan writes; the helper binary is bundled inside the app and copied during package installation. This build is ad-hoc signed when `codesign` is available, but it is not Developer ID signed or notarized. On another Mac, open the package with Control-click > Open if Gatekeeper warns about an unidentified developer.

Remove the helper manually if needed:

```bash
sudo launchctl bootout system /Library/LaunchDaemons/com.coolboard.Helper.plist
sudo rm -f /Library/PrivilegedHelperTools/com.coolboard.Helper
sudo rm -f /Library/LaunchDaemons/com.coolboard.Helper.plist
```

## Safety Model

CoolBoard starts in Auto mode and asks macOS to keep fan control automatic unless a user explicitly requests manual control. Manual preset clicks apply immediately, clamp RPM to the hardware fan range, and try to restore Auto on app startup, shutdown, sleep, wake, or failed writes.

For production distribution, the helper/XPC path should be signed and installed with `SMAppService`. For local GitHub developer builds, `script/install_helper.sh` installs a root LaunchDaemon. If the helper is unavailable, the app attempts a direct AppleSMC fallback and reports the actual helper/SMC error when macOS rejects the write.

## UX Model

The main window is a one-page control surface in the spirit of Macs Fan Control: active preset at the top, a primary fan-control table on the left, and a compact temperature-sensor table on the right. The fan table is driven by AppleSMC `FNum` and detected fan snapshots. Each detected fan row exposes Auto and Manual controls, with 10/20/40/60/80/100% presets mapped to RPM. The temperature table shows detected Celsius readings only, with the count in the section header. The menu-bar icon opens a compact quick-control view with one global percentage block for all detected fans, compact per-fan status rows, and an `Open Full View` action.

When AppleSMC reports `FNum=0`, CoolBoard shows no fan rows and disables manual controls. When fan keys are exposed, writes use the detected `F0*`/`F1*` SMC keys with hardware min/max bounds.

Helper contract:

- install through `SMAppService`;
- expose a narrow XPC interface for fan mode changes only;
- clamp requested RPM to hardware min/max;
- restore Auto on app quit, helper failure, or rejected writes;
- ship outside the Mac App Store because SMC fan control depends on private mechanisms.

The helper has the same private write path and can be inspected from the command line:

```bash
swift run CoolBoardHelper -- set 0 4200
swift run CoolBoardHelper -- auto 0
swift run CoolBoardHelper -- sensors
```

The app talks to `com.coolboard.Helper` through an `NSXPCConnection` with privileged-helper options. Without the helper, monitoring still works, but manual mode can be rejected by AppleSMC. If macOS rejects the write, the UI shows the helper and direct-SMC errors and monitoring continues.

## Compatibility Reports

Apple does not publish a stable Apple Silicon sensor/fan map, so model reports are useful. If CoolBoard works, shows missing sensors, or detects no fans on a machine that should have fans, open a [compatibility report](https://github.com/Rafinelio/CoolBoard/issues/new/choose) with:

- Mac model and chip family;
- macOS version;
- number of detected fans;
- whether manual presets change RPM;
- a screenshot of the CoolBoard window with any private desktop content cropped out.

## Repository Layout

```text
Sources/CoolBoard/       SwiftUI macOS app
Sources/CoolBoardCore/   Models, formatting, hardware service protocols, SMC reads
Sources/CoolBoardHelper/ Privileged-helper scaffold and contract output
Tests/CoolBoardCoreTests Unit and integration-style tests with mock hardware
docs/architecture.md     Hardware/helper architecture notes
script/build_and_run.sh  One-command local build and launch
script/install_helper.sh Development LaunchDaemon install for privileged fan writes
script/package_release.sh Developer PKG installer packaging
```

## References

- Apple SMAppService: https://developer.apple.com/documentation/servicemanagement/smappservice
- Apple IOKit: https://developer.apple.com/documentation/iokit
- Apple Hardened Runtime: https://developer.apple.com/documentation/xcode/configuring-the-hardened-runtime
- Apple Silicon SMC fan research: https://github.com/agoodkind/macos-smc-fan
- iSMC sensor architecture reference: https://github.com/dkorunic/iSMC
- Macs Fan Control supported models: https://crystalidea.com/macs-fan-control/supported-models

## License

MIT
