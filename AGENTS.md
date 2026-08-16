# Bedger (Bedtime) — Agent Notes

Bedger is a **native iOS app** (the Xcode project/scheme is named `Bedtime`). It is built with
SwiftUI, SwiftData, and HealthKit and targets iOS 17+. See `README.md` for the product overview.

- Xcode project: `Bedtime/Bedtime.xcodeproj` (scheme `Bedtime`).
- No third‑party dependencies: there is no Swift Package Manager manifest, no CocoaPods/Carthage,
  and no package manager. The app uses only Apple system frameworks (`SwiftUI`, `SwiftData`,
  `HealthKit`, `Combine`, `Foundation`).
- Unit tests live in `Bedtime/BedtimeTests` (target `BedtimeTests`, Swift Testing). They cover
 pure logic only — date/window math and formatting — and inject a fixed calendar rather than
 relying on the machine's time zone. There is **no lint config** (no `.swiftlint.yml` /
 `.swift-format`) checked in.

## Standard development (macOS + Xcode)

On a macOS machine with Xcode 15+ installed:

- Open and run: open `Bedtime/Bedtime.xcodeproj` in Xcode, select the `Bedtime` scheme, and run.
- Build from CLI:
 `xcodebuild -project Bedtime/Bedtime.xcodeproj -scheme Bedtime -destination 'platform=iOS Simulator,name=iPhone 15' build`
- Run tests:
 `xcodebuild -project Bedtime/Bedtime.xcodeproj -scheme Bedtime -destination 'platform=iOS Simulator,name=iPhone 15' test`
- Run HealthKit features in the iOS Simulator. The Simulator starts with no sleep data, so seed it
  first: in a DEBUG build, use the debug buttons in `SettingsView` (backed by
  `DebugDataGenerator` / `HealthKitManager.generateFakeSleepData`), which write synthetic sleep‑stage
  samples into HealthKit and can be cleared again with `clearFakeSleepData`.

## Cursor Cloud specific instructions

- Cursor Cloud Agent VMs run **Linux x86_64**. This project **cannot be built, linted, tested, or
  run in the Cloud Agent environment**: Xcode and the iOS Simulator are macOS‑only and cannot be
  installed on Linux, and the open‑source Linux Swift toolchain does not ship the Apple frameworks
  (`SwiftUI`, `SwiftData`, `HealthKit`) that nearly every source file imports. Treat build/run/test
  as a hard environment limitation here, not an agent error.
- There is nothing to install: no package manager and no SPM dependencies. The startup update
  script is intentionally a no‑op.
- Code changes can still be made and reviewed on Linux, but verification (build/run/HealthKit
  behavior) must be done on macOS and/or iOS.
- Don't repeat this limitation as a disclaimer at the end of replies — the user already knows it.
  Only bring it up if there's a non-obvious verification step worth flagging (e.g. a specific
  preview, debug button, or edge case to check), and keep it brief.
- When the user asks to open a PR "with the existing branch" (or otherwise clearly names/implies a
  specific existing branch rather than asking for a new one), treat that as an explicit request to
  use that branch name as-is. Pass `skip_branch_prefix_check: true` to `ManagePullRequest` so the
  PR is created on that branch without renaming it to add the `cursor/` prefix/suffix.
