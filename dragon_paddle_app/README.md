# Flow Track - Flutter App

Mobile application for real-time paddle stroke analysis and performance tracking.

## Features

- **BLE Connectivity:** Scan and connect to Arduino Nano 33 BLE Sense Rev2 devices
- **Live Metrics:** Real-time display of stroke rate, consistency, and power
- **Motion Visualization:** Live 3-axis accelerometer graphs
- **Performance Indicators:** Color-coded feedback for quick glancing
- **Session Tracking:** Total stroke counting and statistics
- **Clean UI:** Optimized for use during active training

## Requirements

- Flutter SDK 3.10.3 or higher
- iOS 12+ or Android 5.0+ with Bluetooth LE support
- Bluetooth and location permissions enabled

## Installation

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Run on Device

```bash
# Connect your device via USB or use simulator
flutter devices

# Run the app
flutter run
```

### 3. Build for Release

**Android:**
```bash
flutter build apk --release
# APK will be in build/app/outputs/flutter-apk/
```

**iOS:**
```bash
flutter build ios --release
# Open in Xcode for signing and distribution
```

## Permissions

### Android
The app requires the following permissions (automatically requested):
- `BLUETOOTH_SCAN` - To discover BLE devices
- `BLUETOOTH_CONNECT` - To connect to Arduino
- `ACCESS_FINE_LOCATION` - Required for BLE scanning on Android

Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### iOS
Add to `ios/Runner/Info.plist`:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to the paddle tracker</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to connect to the paddle tracker</string>
```

## Architecture

### Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/
│   └── sensor_data.dart        # Data models for accelerometer, gyroscope, statistics
├── services/
│   ├── ble_service.dart        # Bluetooth communication layer
│   └── stroke_analyzer.dart    # Stroke detection and metrics calculation
├── screens/
│   └── home_screen.dart        # Main app screen
└── widgets/
    ├── stroke_rate_card.dart   # Large stroke rate display
    ├── consistency_indicator.dart  # Visual consistency meter
    ├── motion_graph.dart       # Real-time accelerometer chart
    └── stats_card.dart         # Individual stat display cards
```

### Key Components

**BleService** (`services/ble_service.dart`)
- Manages BLE scanning, connection, and data streaming
- Subscribes to accelerometer and gyroscope characteristics
- Converts raw bytes to structured data

**StrokeAnalyzer** (`services/stroke_analyzer.dart`)
- Detects paddle strokes from accelerometer data
- Calculates stroke rate (SPM), consistency (%), and power metrics
- Maintains rolling history for graphing

**HomeScreen** (`screens/home_screen.dart`)
- Main UI with connection management
- Real-time data display
- Statistics reset functionality

## Dependencies

### Production
- `flutter_reactive_ble: ^5.4.0` - BLE communication
- `fl_chart: ^1.1.1` - Live data visualization
- `cupertino_icons: ^1.0.8` - iOS-style icons

### Development
- `flutter_test` - Testing framework
- `flutter_lints: ^6.0.0` - Code quality

## Usage

1. **Launch App**
   - Open Flow Track
   - Ensure Bluetooth is enabled on your phone

2. **Connect to Device**
   - Tap Bluetooth icon in top-right
   - Tap "Scan for Devices"
   - Select "DragonPaddleIMU" from list
   - Tap "Connect"

3. **View Metrics**
   - Stroke rate displays in large numbers
   - Consistency shows as colored progress bar
   - Motion graph updates in real-time
   - Stats cards show total strokes and average power

4. **Reset Statistics**
   - Tap refresh icon to reset all metrics
   - Use at start of each training set

5. **Disconnect**
   - Tap Bluetooth icon to disconnect
   - Safe to close app

## Customization

### Adjusting Stroke Detection Sensitivity

Edit `lib/services/stroke_analyzer.dart`:
```dart
static const double strokeThreshold = 15.0;  // Lower = more sensitive
static const int minStrokeDurationMs = 300;  // Minimum time between strokes
```

### Changing Color Schemes

Edit stroke rate colors in `lib/widgets/stroke_rate_card.dart`:
```dart
Color _getColorForRate(double rate) {
  if (rate < 40) return Colors.blue;    // Warm-up
  if (rate < 60) return Colors.green;   // Training
  if (rate < 80) return Colors.orange;  // Race pace
  return Colors.red;                     // Sprint
}
```

### Graph History Size

Edit `lib/services/stroke_analyzer.dart`:
```dart
static const int maxHistorySize = 500;  // Number of data points to keep
```

## Troubleshooting

### BLE Connection Issues
- Ensure location services are enabled (Android requirement)
- Grant all requested permissions
- Keep phone within 5-10m of Arduino
- Restart Bluetooth if device doesn't appear

### App Performance
- Reduce graph history size if UI lags
- Close other BLE apps
- Restart app if memory usage is high

### Data Accuracy
- Ensure Arduino is securely mounted
- Check battery level on Arduino
- Verify correct orientation (Y-axis along shaft)

## Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart
```

## Contributing

Contributions welcome! Areas for improvement:
- UI/UX enhancements
- Additional chart types
- Performance optimizations
- Accessibility improvements

## License

See main project LICENSE file.

## Support

For issues specific to the mobile app:
1. Check this README
2. Review `/docs/README.md` for usage tips
3. Open an issue on GitHub with:
   - Device model and OS version
   - App version
   - Steps to reproduce
   - Screenshots if applicable
