# Changelog

## v0.1.2 - 2026-06-16

### Known Bugs Fixed

- Fixed a safety issue where sleep/wake could briefly restore Auto and then re-apply the previous manual fan preset during wake or darkwake.
- Pending manual fan writes are now invalidated when sleep or wake starts, so stale writes cannot complete after Auto restore.
- AppleSMC restore state is now remembered locally after Auto fallback attempts, reducing stale manual UI state after recovery.

### Notes

- After sleep or wake, manual fan presets are intentionally not resumed. Apply a preset again after opening the Mac.

## v0.1.1 - 2026-06-14

### Added

- Added `0%` fan presets across the main app and menu-bar quick control.
- Added a static website with direct `.pkg` download link.
- Added a minimal interactive pixel hero with reduced-motion support.

### Changed

- The menu-bar reset button now applies a real `0 RPM` manual target instead of restoring Auto.
- Manual `0 RPM` requests are preserved through the app, helper, and direct AppleSMC fallback paths instead of being clamped to the hardware minimum RPM.

## v0.1.0 - 2026-06-13

Initial public developer release of CoolBoard.

### Added

- Native SwiftUI macOS app for Apple Silicon thermal monitoring.
- Dynamic AppleSMC temperature discovery and IORegistry battery temperature reads.
- Detected fan count from AppleSMC `FNum`; no fake fan rows on fanless Macs.
- Guarded manual fan presets with Auto restore on startup, shutdown, sleep, wake, and write failure.
- Root helper installer path for fan writes outside the Mac App Store.
- Menu-bar quick control with global percentage presets for all detected fans.
- Developer `.pkg` installer that installs the app and helper into system locations.

### Notes

- This build is ad-hoc signed, not Developer ID signed or notarized.
- Manual fan control depends on private AppleSMC behavior and may be rejected on some machines.
- Apple Silicon MacBook Air models are fanless, so fan control is unavailable there.
