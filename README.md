# 🐉 Flow Track Pro

A complete advanced paddle tracking system for dragon boat athletes, featuring real-time motion analysis, AI-powered stroke quality assessment, and comprehensive performance metrics.

## 🎯 Overview

Flow Track Pro helps dragon boat paddlers improve their technique through real-time feedback on stroke mechanics, environmental conditions, and AI-based technique analysis. The system consists of:

1. **Advanced Arduino Firmware** - Runs on Arduino Nano 33 BLE Sense Rev2 attached to paddle
2. **Flutter Mobile App** - Displays live data and comprehensive performance metrics on paddlers' phones
3. **Hardware Mounting** - 3D printable designs for secure paddle attachment

## ✨ Features

### 🏃 Real-Time Basic Metrics
- **Stroke Rate** - Live strokes per minute (SPM) with big, easy-to-read numbers
- **Consistency** - Visual indicator showing stroke power consistency (0-100%)
- **Total Strokes** - Running count of paddle strokes
- **Average Power** - Power metrics based on acceleration magnitude

### 📊 Advanced IMU Metrics
- **Stroke Length** - Calculated distance traveled per stroke
- **Paddle Angle Tracking** - Entry and exit angles for optimal technique
- **Smoothness Score** - Measures stroke fluidity and technique quality
- **Fatigue Detection** - Monitors declining performance over time
- **Asymmetry Analysis** - Tracks left vs right stroke balance
- **Rotation Torque** - Measures paddle rotation during strokes
- **Stroke Phase Detection** - Identifies Catch, Pull, Exit, and Recovery phases
- **Catch Timing** - Precise timing of stroke entry
- **Recovery Phase** - Monitors time between strokes

### 🌡️ Environmental Monitoring
- **Temperature Sensing** - Real-time temperature and humidity tracking
- **Water vs Air Detection** - Automatically detects when paddle is in water
- **Heat Safety Warnings** - Alerts when temperature exceeds safe levels (>35°C)

### 🤖 AI-Powered Stroke Analysis
- **Clean Stroke Detection** - Identifies proper vs messy stroke technique
- **Over-Rotation Detection** - Warns about excessive paddle rotation
- **Paddle Angle Quality** - Validates optimal angle range (30-60°)
- **Early Exit Detection** - Identifies premature stroke termination
- **Lawnmower Stroke Detection** - Detects wide arc patterns
- **Overall Quality Score** - Comprehensive AI-based technique rating

### 📈 Visualization
- **3D Trajectory Plotting** - Visualizes paddle motion in 3D space (2D projections)
- **Live Motion Graphs** - Real-time 3-axis accelerometer visualization
- **Magnetometer Data** - Compass orientation tracking

### 🔄 Session Management
- **Auto Session Detection** - Automatically starts/stops tracking based on activity
- **Session Timeout** - Ends session after 5 minutes of inactivity
- **Session Recording** - Save and review past training sessions

### 📱 User Experience
- Clean, intuitive interface optimized for glancing at during practice
- Color-coded indicators (green = good, orange = okay, red = needs improvement)
- Easy reset and reconnection controls
- Local data storage (each paddler owns their data)
- Keep-screen-awake mode for continuous monitoring

## 🚀 Getting Started

### Hardware Requirements

1. **Arduino Nano 33 BLE Sense Rev2** - Main processor with:
   - BMI270 6-axis IMU (accelerometer + gyroscope)
   - BMM150 3-axis magnetometer
   - HTS221 temperature & humidity sensor
   - BLE 5.0 connectivity
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
   - App will scan for "FlowTrackPro" devices
   - Tap "Connect" on your device

2. **Start Paddling**
   - Once connected, all metrics update automatically in real-time
   - Session auto-starts when paddling is detected
   - Stroke rate shows in large numbers at the top
   - Consistency bar shows stroke uniformity
   - Motion graph displays real-time acceleration patterns

3. **Monitor Advanced Metrics**
   - **Advanced Metrics Card** shows stroke length, angles, smoothness, torque, fatigue, and L/R balance
   - **Temperature Card** displays current temperature, humidity, and heat warnings
   - **AI Stroke Analysis** provides real-time feedback on technique quality
   - **3D Trajectory** visualizes your paddle motion path

4. **Reset Statistics**
   - Tap the refresh icon to reset stroke count and statistics
   - Useful for starting new training sets

5. **Session Recording**
   - Tap the rowing icon to start/stop recording sessions
   - Sessions auto-save for later review

6. **Disconnect**
   - Tap the Bluetooth icon when finished
   - Arduino enters low-power mode when disconnected

## 🔧 Technical Details

### BLE Protocol

**Service UUID:** `180A`
- **Accelerometer Characteristic:** `2A37` (12 bytes: 3 floats, little-endian)
- **Gyroscope Characteristic:** `2A38` (12 bytes: 3 floats, little-endian)
- **Magnetometer Characteristic:** `2A39` (12 bytes: 3 floats, little-endian)
- **Advanced Metrics Characteristic:** `2A3A` (32 bytes: 8 floats)
  - Stroke length, entry angle, exit angle, smoothness, rotation torque, fatigue score, asymmetry ratio, stroke phase
- **Temperature Characteristic:** `2A3B` (8 bytes: 2 floats)
  - Temperature (°C), Humidity (%)
- **ML Classifications Characteristic:** `2A3C` (16 bytes: 4 floats)
  - Clean stroke score, rotation quality, angle quality, exit quality

### Stroke Detection Algorithm

The system uses an advanced state machine for stroke detection:
- Acceleration magnitude threshold (15.0 default)
- Minimum inter-stroke interval (300ms)
- Hysteresis to prevent false detections

### Performance

- **Sampling Rate:** 50Hz (20ms between samples)
- **BLE Latency:** <50ms typical
- **BLE Characteristics:** 6 total (accelerometer, gyroscope, magnetometer, advanced metrics, temperature, ML classifications)
- **Battery Life:** 4-6 hours with 1000mAh battery (estimated)
- **Stroke Phases:** 5 states (Idle, Catch, Pull, Exit, Recovery)
- **Session Auto-Stop:** 5 minutes of inactivity

## 📁 Project Structure

```
flow-track/
├── firmware/
│   └── imu_tracker/
│       ├── imu_tracker.ino          # Advanced Arduino firmware
│       └── imu_tracker_basic.ino    # Basic version backup
├── dragon_paddle_app/
│   ├── lib/
│   │   ├── main.dart                # App entry point
│   │   ├── models/
│   │   │   └── sensor_data.dart     # Data models (7 classes)
│   │   ├── services/
│   │   │   ├── ble_service.dart     # BLE communication (6 characteristics)
│   │   │   ├── stroke_analyzer.dart # Stroke detection
│   │   │   ├── session_service.dart # Session recording
│   │   │   └── storage_service.dart # Data persistence
│   │   ├── screens/
│   │   │   ├── home_screen.dart     # Main UI screen
│   │   │   ├── session_list_screen.dart
│   │   │   └── session_review_screen.dart
│   │   └── widgets/
│   │       ├── stroke_rate_card.dart
│   │       ├── consistency_indicator.dart
│   │       ├── motion_graph.dart
│   │       ├── stats_card.dart
│   │       ├── advanced_metrics_card.dart    # NEW
│   │       ├── temperature_card.dart         # NEW
│   │       ├── ml_quality_card.dart          # NEW
│   │       └── trajectory_widget.dart        # NEW
│   └── pubspec.yaml                 # Flutter dependencies
├── hardware/
│   └── README.md                     # Hardware mounting info
└── docs/
    └── README.md                     # Additional documentation
```

## 🤖 AI/ML Features

### Current Implementation
The firmware includes a **heuristic-based** stroke classification system that provides:
- Clean stroke detection based on smoothness scores
- Over-rotation detection from gyroscope data
- Paddle angle quality assessment (optimal: 30-60°)
- Early exit detection based on stroke length
- Lawnmower stroke detection from arc patterns

### Future TinyML Integration
The system is designed to support **TensorFlow Lite** models for more advanced classification:
- Train custom models on labeled stroke data
- Deploy models to Arduino using Arduino_TensorFlowLite library
- Real-time on-device inference at 50Hz
- Potential features: leg drive detection, water entry quality, power phase optimization

## 🔮 Completed Features

- [x] ✅ Stroke length calculation
- [x] ✅ Stroke timing consistency
- [x] ✅ Paddle angle entry/exit tracking
- [x] ✅ Smoothness score
- [x] ✅ Fatigue detection
- [x] ✅ 3D trajectory plotting (2D projections)
- [x] ✅ Asymmetry detection (left vs right)
- [x] ✅ Catch timing
- [x] ✅ Recovery phase timing
- [x] ✅ Rotation torque calculation
- [x] ✅ Auto-detect session start/stop
- [x] ✅ Temperature monitoring
- [x] ✅ Water vs air detection
- [x] ✅ Heat safety warnings
- [x] ✅ AI stroke quality classification (heuristic-based)

## 🔮 Future Enhancements

- [ ] Train and deploy TensorFlow Lite models for true ML-based classification
- [ ] Multi-paddler synchronization for team coordination
- [ ] Post-practice analysis mode with historical data review
- [ ] Export functionality for sharing session data (CSV, GPX)
- [ ] Enhanced 3D trajectory visualization with three_dart/flutter_cube
- [ ] Optional OLED display on paddle for instant feedback
- [ ] Cloud sync for cross-device access (optional)
- [ ] Coach dashboard for monitoring team performance
- [ ] Voice feedback for hands-free coaching
- [ ] Integration with heart rate monitors

## 🤝 Contributing

Contributions are welcome! Areas for improvement:
- Training TinyML models on real stroke data
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
