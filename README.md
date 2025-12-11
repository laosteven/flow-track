# 🐉 Flow Track

A complete paddle tracking system for dragon boat athletes, featuring real-time motion analysis and performance metrics.

## 🎯 Overview

The Flow Track helps dragon boat paddlers improve their technique through real-time feedback on stroke rate, consistency, and motion patterns. The system consists of:

1. **Arduino Firmware** - Runs on Arduino Nano 33 BLE Sense Rev2 attached to paddle
2. **Flutter Mobile App** - Displays live data and performance metrics on paddlers' phones
3. **Hardware Mounting** - 3D printable designs for secure paddle attachment

## ✨ Features

### Real-Time Metrics
- **Stroke Rate** - Live strokes per minute (SPM) with big, easy-to-read numbers
- **Consistency** - Visual indicator showing stroke power consistency (0-100%)
- **Total Strokes** - Running count of paddle strokes
- **Average Power** - Power metrics based on acceleration magnitude

### Motion Tracking
- Live 3-axis accelerometer graphs showing motion patterns
- Gyroscope data for rotation tracking
- Visual feedback with color-coded performance indicators

### Bluetooth Connectivity
- Low-latency BLE connection
- Automatic device discovery
- Robust connection handling

### User Experience
- Clean, intuitive interface optimized for glancing at during practice
- Color-coded indicators (green = good, orange = okay, red = needs improvement)
- Easy reset and reconnection controls
- Local data storage (each paddler owns their data)

## 🚀 Getting Started

### Hardware Requirements

1. **Arduino Nano 33 BLE Sense Rev2** - Main processor with built-in 9-axis IMU (BMI270/BMM150)
2. **LiPo Battery** (optional) - 3.7V 500-1000mAh for portable operation
3. **Mounting Hardware** - 3D printed paddle mount (STL files in `/hardware`)
4. **Waterproof Case** (optional) - Protect electronics during outdoor practice

### Software Requirements

#### For Arduino Firmware:
- Arduino IDE 2.0 or newer
- Arduino Mbed OS Nano Boards package (for Nano 33 BLE)
- Libraries:
  - ArduinoBLE
  - Arduino_BMI270_BMM150

#### For Flutter App:
- Flutter SDK 3.10.3 or newer
- iOS 12+ or Android 5.0+ device with Bluetooth LE support

### Installation

#### 1. Flash Arduino Firmware

```bash
# Open Arduino IDE
# Install required boards and libraries (see above)
# Open firmware/nano33ble_rev2/imu_tracker.ino
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
   - App will scan for "FlowTrackIMU" devices
   - Tap "Connect" on your device

2. **Start Paddling**
   - Once connected, metrics update automatically
   - Stroke rate shows in large numbers at the top
   - Consistency bar shows stroke uniformity
   - Motion graph displays real-time acceleration patterns

3. **Reset Statistics**
   - Tap the refresh icon to reset stroke count and statistics
   - Useful for starting new training sets

4. **Disconnect**
   - Tap the Bluetooth icon when finished
   - Arduino enters low-power mode when disconnected

## 🔧 Technical Details

### BLE Protocol

**Service UUID:** `180A`
- **Accelerometer Characteristic:** `2A37` (12 bytes: 3 floats, little-endian)
- **Gyroscope Characteristic:** `2A38` (12 bytes: 3 floats, little-endian)

### Stroke Detection Algorithm

The system detects paddle strokes using:
- Acceleration magnitude threshold (15.0 default)
- Minimum inter-stroke interval (300ms)
- Hysteresis to prevent false detections

### Performance

- **Sampling Rate:** 50Hz (20ms between samples)
- **BLE Latency:** <50ms typical
- **Battery Life:** 4-6 hours with 1000mAh battery (estimated)

## 📁 Project Structure

```
flow-track/
├── firmware/
│   └── imu_tracker.ino          # Arduino firmware
├── dragon_paddle_app/
│   ├── lib/
│   │   ├── main.dart                # App entry point
│   │   ├── models/
│   │   │   └── sensor_data.dart     # Data models
│   │   ├── services/
│   │   │   ├── ble_service.dart     # BLE communication
│   │   │   └── stroke_analyzer.dart # Stroke detection
│   │   ├── screens/
│   │   │   └── home_screen.dart     # Main UI screen
│   │   └── widgets/
│   │       ├── stroke_rate_card.dart
│   │       ├── consistency_indicator.dart
│   │       ├── motion_graph.dart
│   │       └── stats_card.dart
│   └── pubspec.yaml                 # Flutter dependencies
├── hardware/
│   └── README.md                     # Hardware mounting info
└── docs/
    └── README.md                     # Additional documentation
```

## 🔮 Future Enhancements

- [ ] Multi-paddler synchronization for team coordination
- [ ] Post-practice analysis mode with historical data review
- [ ] Export functionality for sharing session data
- [ ] 3D trajectory visualization with three_dart
- [ ] Optional OLED display on paddle for instant feedback
- [ ] Advanced stroke analysis (catch angle, recovery time, etc.)
- [ ] Cloud sync for cross-device access (optional)
- [ ] Coach dashboard for monitoring team performance

## 🤝 Contributing

Contributions are welcome! Areas for improvement:
- Better stroke detection algorithms
- Additional performance metrics
- UI/UX enhancements
- Hardware design improvements
- Documentation and tutorials

## 📄 License

This project is open source. Feel free to use, modify, and distribute for personal or team use.

## 🏆 Credits

Built for dragon boat athletes who want to improve their paddling technique through data-driven feedback.

## 📞 Support

For questions, issues, or suggestions:
- Open an issue on GitHub
- Check the `/docs` folder for detailed documentation
- Review the hardware setup guide in `/hardware`
