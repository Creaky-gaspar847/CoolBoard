# Changelog

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
