# Bedger (Bedtime) — Agent Notes

Bedger is a **native iOS app** (the Xcode project/scheme is named `Bedtime`). It is built with
SwiftUI, SwiftData, and HealthKit and targets iOS 17+. See `README.md` for the product overview.

- Xcode project: `Bedtime/Bedtime.xcodeproj` (scheme `Bedtime`).
- No third‑party dependencies: there is no Swift Package Manager manifest, no CocoaPods/Carthage,
  and no package manager. The app uses only Apple system frameworks (`SwiftUI`, `SwiftData`,
  `HealthKit`, `Combine`, `Foundation`).
- There are currently **no test targets** and **no lint config** (no `.swiftlint.yml` /
  `.swift-format`) checked in.

## Standard development (macOS + Xcode)

On a macOS machine with Xcode 15+ installed:

- Open and run: open `Bedtime/Bedtime.xcodeproj` in Xcode, select the `Bedtime` scheme, and run.
- Build from CLI:
  `xcodebuild -project Bedtime/Bedtime.xcodeproj -scheme Bedtime -destination 'platform=iOS Simulator,name=iPhone 15' build`
- Run HealthKit features in the iOS Simulator. The Simulator starts with no sleep data, so add
  sample sleep sessions first via the Simulator's Health app or a dummy‑data debug script that
  writes `HKCategorySample` sleep records.

## Cursor Cloud specific instructions

- Cursor Cloud Agent VMs run **Linux x86_64**. This project **cannot be built, linted, tested, or
  run in the Cloud Agent environment**: Xcode and the iOS Simulator are macOS‑only and cannot be
  installed on Linux, and the open‑source Linux Swift toolchain does not ship the Apple frameworks
  (`SwiftUI`, `SwiftData`, `HealthKit`) that nearly every source file imports. Treat build/run/test
  as a hard environment limitation here, not an agent error.
- There is nothing to install: no package manager and no SPM dependencies. The startup update
  script is intentionally a no‑op.
- Code changes can still be made and reviewed on Linux, but verification (build/run/HealthKit
  behavior) must be done by a human (or macOS CI) on macOS + Xcode using the iOS Simulator.
