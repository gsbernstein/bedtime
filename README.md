# Bedger - Sleep Optimization App

A native iOS app that helps optimize your sleep by tracking your "sleep bank" and providing personalized bedtime recommendations.

## Features

### 🏦 Sleep Bank
- Tracks your sleep debt/credit based on recent nights
- Calculates how much you're ahead or behind your sleep goal
- Visual progress indicator showing your current balance
- Tap the goal on the sleep balance card to adjust it without opening settings

### 💡 Sleep Insights
- Highlights the lookback windows where you're ahead, and where you're behind
- Offers to switch the sleep bank to the window that needs catching up
- When you're caught up across the whole two-week window, offers to raise your
  nightly goal to one your recent average already clears

### 🛏️ Smart Bedtime Recommendations
- Personalized bedtime suggestions based on your sleep bank
- Considers your normal wake time and sleep goal
- Adjusts recommendations when you're in sleep debt
- Tap the wake time on the recommendation card to adjust it without opening settings

### 📊 Sleep History
- View your recent sleep sessions from HealthKit
- Track sleep duration over time
- Visual representation of your sleep patterns

### 🧹 Duplicate Data Cleanup
- Detects when a source (e.g. Oura) has re-synced a night it already wrote, leaving two
  overlapping sets of samples for the same stretch of sleep
- A small warning button appears next to the affected source's row; tapping it opens a
  cleanup sheet
- The sheet shows the overlapping entries on a timeline and a histogram of when they were
  added to HealthKit, with a divider you can drag to preview exactly which entries would be
  kept vs. deleted
- Apple only lets an app delete HealthKit samples it wrote itself, so for real duplicates
  (which always come from the other source, e.g. Oura) Bedger can't delete them directly —
  the sheet instead points you at exactly what to remove and offers a shortcut into the
  Health app to finish it there. Bedger only deletes directly in the rare case where it's
  the source of the duplicate samples itself

### ⚙️ Customizable Settings
- Set your personal sleep goal (6-12 hours, in 15 minute steps)
- Configure your preferred wake time
- Adjust the sleep bank calculation period (3-14 days)

## How It Works

1. **HealthKit Integration**: The app reads your sleep data from the Health app
2. **Sleep Bank Calculation**: Compares your actual sleep to your goal over a configurable period
3. **Smart Recommendations**: Suggests bedtime based on your sleep debt/credit and wake time
4. **Visual Feedback**: Clear indicators of your sleep status and progress

## Requirements

- iOS 17.0+
- HealthKit access
- Sleep data recorded in the Health app

## Setup

1. Open the project in Xcode
2. Build and run on a device (HealthKit requires a physical device)
3. Grant HealthKit permissions when prompted
4. Configure your sleep goal and wake time in settings

## Interactive: Midpoint + 6h grouping

Sleep sessions are assigned to a calendar day using a "midpoint + 6 hours" rule (see
`SleepSession.dateForGrouping`). An interactive visualization of this rule lives in
[`docs/index.html`](docs/index.html) and is published via GitHub Pages (enable Pages →
"GitHub Actions" in repo settings to host it).

## Privacy

- All data stays on your device
- No data is sent to external servers
- HealthKit data is effectively read-only: the duplicate cleanup feature can request write
  access, but HealthKit only lets an app delete samples it wrote itself, so it can't
  actually delete another source's data (e.g. Oura's) — only guide you to remove it via the
  Health app. Bedger never writes new sleep data outside of debug builds

## Architecture

- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Local data persistence for user preferences
- **HealthKit**: Sleep data integration
- **MVVM Pattern**: Clean separation of concerns

The app follows iOS design guidelines and provides a clean, intuitive interface for sleep optimization.
