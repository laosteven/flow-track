# 🐉 Flow Track

A complete advanced paddle tracking system for dragon boat athletes, featuring real-time motion analysis, AI-powered stroke quality assessment, and comprehensive performance metrics.

## 🎯 Overview

Flow Track helps dragon boat paddlers improve their technique through real-time feedback on stroke mechanics, environmental conditions, and AI-based technique analysis.

## 🚀 Getting Started

### Hardware Requirements

1. **Arduino Nano 33 BLE Sense Rev2** - Main processor with:
   - BMI270 6-axis IMU (accelerometer + gyroscope)
   - BMM150 3-axis magnetometer
   - HTS221 temperature & humidity sensor
   - BLE 5.0 connectivity
2. **LiPo Battery** (optional) - 3.7V 500-1000mAh for portable operation
3. **Mounting Hardware** - 3D printed paddle mount (STL files in `/hardware`)

### Software Requirements

#### For Arduino Firmware:
- Arduino IDE 2.0 or newer
- Arduino Mbed OS Nano Boards package (for Nano 33 BLE)
- Libraries:
  - ArduinoBLE
  - Arduino_BMI270_BMM150
  - Arduino_HTS221

#### For Flutter App:
- Flutter SDK 3.10.3 or newer
- iOS 12+ or Android 5.0+ device with Bluetooth LE support

### Installation

#### 1. Flash Arduino Firmware

```bash
# Open Arduino IDE
# Install required boards and libraries (see above)
# Open firmware/imu_tracker/imu_tracker.ino
# Select Board: Arduino Nano 33 BLE
# Upload to device
```

#### 2. Build Flutter App

```bash
cd dragon_paddle_app

# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Or build for release
flutter build apk      # For Android
flutter build ios      # For iOS
```

## 📱 Using the App

1. **Connect to Paddle**
   - Tap the Bluetooth icon in the top-right
   - App will scan for "FlowTrack" devices
   - Tap "Connect" on your device

2. **Start Paddling**
   - Once connected, all metrics update automatically in real-time
   - Session auto-starts when paddling is detected
   - Stroke rate shows in large numbers at the top
   - Consistency bar shows stroke uniformity
   - Motion graph displays real-time acceleration patterns

## 🏆 Credits

Built for dragon boat athletes who want to improve their paddling technique through data-driven feedback.

## � Documentation

Detailed documentation is available in the [docs/](docs/) folder:

- **[Getting Started Guide](GETTING_STARTED.md)** - Complete setup instructions
- **[Architecture](docs/ARCHITECTURE.md)** - Technical architecture and design decisions
- **[Features](docs/FEATURES.md)** - Detailed feature documentation
- **[Testing Guide](docs/TESTING.md)** - How to test the system
- **[Versioning](docs/VERSIONING.md)** - Version management with GitHub Actions
- **[Changelog](CHANGELOG.md)** - Version history and release notes
