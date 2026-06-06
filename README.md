# Bedger - Sleep Optimization App

A native iOS app that helps optimize your sleep by tracking your "sleep bank" and providing personalized bedtime recommendations.

## Features

### 🏦 Sleep Bank
- Tracks your sleep debt/credit based on recent nights
- Calculates how much you're ahead or behind your sleep goal
- Visual progress indicator showing your current balance

### 🛏️ Smart Bedtime Recommendations
- Personalized bedtime suggestions based on your sleep bank
- Considers your normal wake time and sleep goal
- Adjusts recommendations when you're in sleep debt

### 📊 Sleep History
- View your recent sleep sessions from HealthKit
- Track sleep duration over time
- Visual representation of your sleep patterns

### ⚙️ Customizable Settings
- Set your personal sleep goal (6-12 hours)
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
- HealthKit data is only read, never written to

## Architecture

- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Local data persistence for user preferences
- **HealthKit**: Sleep data integration
- **MVVM Pattern**: Clean separation of concerns

The app follows iOS design guidelines and provides a clean, intuitive interface for sleep optimization.
