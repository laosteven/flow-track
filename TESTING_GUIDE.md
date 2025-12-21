# Testing Guide for Advanced Features

This guide helps you test and verify the newly implemented advanced features.

## 🔧 Prerequisites

### Hardware Testing
- Arduino Nano 33 BLE Sense Rev2
- USB cable for programming
- Arduino IDE 2.0 or newer
- Required libraries installed:
  - ArduinoBLE
  - Arduino_BMI270_BMM150
  - Arduino_HTS221

### Software Testing
- Flutter SDK 3.10.3 or newer
- iOS/Android device with BLE support
- All dependencies installed (`flutter pub get`)

## 📝 Firmware Testing

### 1. Compile Firmware

```bash
# Open Arduino IDE
# File -> Open -> firmware/imu_tracker/imu_tracker.ino
# Tools -> Board -> Arduino Mbed OS Nano Boards -> Arduino Nano 33 BLE
# Sketch -> Verify/Compile
```

**Expected Result:** Should compile without errors
**File Size:** ~50-80KB (varies with optimization)

### 2. Upload to Device

```bash
# Connect Arduino via USB
# Tools -> Port -> Select your Arduino port
# Sketch -> Upload
```

**Expected Result:** 
- Upload successful
- LED blinks 3 times indicating ready state

### 3. Test Serial Output

```bash
# Open Serial Monitor (Tools -> Serial Monitor)
# Set baud rate to 115200
```

**Expected Output:**
```
Flow Track Advanced - Initializing...
========================================
Initializing IMU...
✓ IMU initialized
Initializing Temperature Sensor...
✓ Temperature sensor initialized
Initializing BLE...
✓ BLE initialized
✓ BLE advertising as 'FlowTrack'
========================================
Features enabled:
  • Stroke length & timing
  • Paddle angle tracking
  • Smoothness score
  • Fatigue detection
  • 3D trajectory
  • Left/right asymmetry
  • Rotation torque
  • Auto session detection
  • Temperature monitoring
  • ML stroke classification
========================================
Ready! Waiting for connections...
```

### 4. Test Sensor Readings (Without BLE Connection)

Move the Arduino and observe Serial Monitor:

**For IMU Data:**
- Should see periodic updates when you move it
- Acceleration values change with motion
- Gyroscope values change with rotation

**For Temperature:**
- Should see temperature/humidity readings
- Hold device in hand -> temperature should rise
- Breathe on sensor -> humidity should increase

## 📱 Flutter App Testing

### 1. Compile Flutter App

```bash
cd dragon_paddle_app
flutter clean
flutter pub get
flutter analyze
```

**Expected Result:** No analysis errors

### 2. Run on Device

```bash
# Connect iOS/Android device
flutter devices  # Verify device detected
flutter run
```

**Expected Result:** App launches successfully

### 3. Test BLE Scanning

1. Tap hamburger menu (top-left)
2. Tap "Scan" (if not connected)
3. Wait for devices to appear

**Expected Result:**
- Should find "FlowTrack" device
- Device appears in list with Bluetooth icon

### 4. Test Connection

1. Tap "Connect" on your device
2. Wait for connection

**Expected Result:**
- Green banner appears: "Connected to FlowTrack"
- Home screen shows all metric cards
- Serial monitor shows: "✓ Connected to: [MAC address]"

## 🧪 Feature Testing Checklist

### Basic Metrics (Pre-existing)
- [ ] Stroke Rate displays and updates
- [ ] Consistency bar shows percentage
- [ ] Total Strokes increments with motion
- [ ] Average Power shows values
- [ ] Motion Graph plots accelerometer data

### Advanced Metrics Card
Test by moving Arduino like a paddle stroke:

- [ ] **Stroke Length** 
  - Should show increasing value during motion
  - Typical range: 10-50 units (relative)
  
- [ ] **Entry → Exit Angle**
  - Should change as you tilt device
  - Range: 0-90 degrees
  
- [ ] **Smoothness**
  - Smooth motion = higher percentage (>70%)
  - Jerky motion = lower percentage (<50%)
  
- [ ] **Rotation Torque**
  - Increases when you rotate device
  - Higher for spinning motions
  
- [ ] **Fatigue**
  - Starts at 0%
  - Increases if you slow down strokes
  
- [ ] **L/R Balance**
  - Should split strokes based on rotation direction
  - Rotate clockwise vs counter-clockwise
  
- [ ] **Stroke Phase**
  - Cycles through: Idle → Catch → Pull → Exit → Recovery
  - Color-coded indicator changes

### Temperature Card
- [ ] Temperature displays current reading
- [ ] Humidity shows percentage
- [ ] Icon shows water drop or air symbol
- [ ] Hold in hand -> temperature rises
- [ ] **Heat Warning Test:**
  - If temp >35°C, red warning banner appears
  - (May need to hold near heat source to trigger)

### ML Quality Card
- [ ] **Overall Quality Score**
  - Shows percentage and description
  - Changes color based on score
  
- [ ] **Clean Stroke Bar**
  - Higher for smooth motions
  - Lower for jerky motions
  
- [ ] **Rotation Quality Bar**
  - Good: moderate rotation
  - Poor: excessive spinning
  
- [ ] **Paddle Angle Bar**
  - Best around 30-60 degree tilt
  - Lower at extreme angles
  
- [ ] **Exit Quality Bar**
  - Higher for longer motions
  - Lower for short quick movements

### 3D Trajectory Widget
- [ ] Two side-by-side projection views appear
- [ ] Points plot as you move device
- [ ] Blue to red color gradient shows progression
- [ ] Up to 100 points displayed
- [ ] Clears when you reset statistics

### Session Auto-Detection
Monitor Serial output while testing:

- [ ] Move device to start strokes
- [ ] Serial shows ">>> SESSION STARTED <<<"
- [ ] Stop moving for 5+ minutes
- [ ] Serial shows ">>> SESSION ENDED <<<"
- [ ] Session summary displays (duration, strokes)

## 🎯 Scenario Testing

### Scenario 1: Simulated Paddle Session

1. **Setup:**
   - Connect app to Arduino
   - Tap reset icon to clear stats
   - Hold Arduino like a paddle

2. **Actions:**
   - Perform 20 "paddle strokes" (forward swings)
   - Try to keep consistent motion
   - Vary some strokes (fast, slow, smooth, jerky)

3. **Verify:**
   - [ ] Stroke count reaches ~20
   - [ ] Stroke rate calculates SPM
   - [ ] Asymmetry shows L/R distribution
   - [ ] Fatigue starts to appear if slowing down
   - [ ] ML scores reflect technique quality
   - [ ] Trajectory shows motion pattern

### Scenario 2: Temperature Monitoring

1. **Setup:**
   - Connect app
   - Note starting temperature

2. **Actions:**
   - Hold device in hand for 1 minute
   - Breathe on sensor
   - Place near ice/cold object

3. **Verify:**
   - [ ] Temperature increases when held
   - [ ] Humidity changes with breath
   - [ ] "IN AIR" indicator shows normally
   - [ ] If temp reaches >35°C, warning appears

### Scenario 3: Technique Analysis

1. **Setup:**
   - Connect app
   - Reset statistics

2. **Actions:**
   - Perform 5 smooth, controlled strokes
   - Perform 5 jerky, irregular strokes
   - Perform 5 with excessive rotation

3. **Verify:**
   - [ ] Smoothness score higher for controlled strokes
   - [ ] Clean stroke score varies appropriately
   - [ ] Over-rotation detected in ML quality
   - [ ] Stroke length shows variation

## 🐛 Troubleshooting

### Issue: Firmware won't compile
**Solutions:**
- Update Arduino IDE to 2.0+
- Install latest board package (Arduino Mbed OS Nano)
- Verify all libraries installed
- Check library versions match

### Issue: "Temperature sensor failed to initialize"
**Note:** This is non-critical
- App will continue without temperature features
- Other features work normally
- Rev2 should have HTS221 - verify board version

### Issue: App can't find device
**Solutions:**
- Ensure Arduino is powered and running
- Check Serial monitor shows "BLE advertising"
- Enable Bluetooth on phone
- Grant location permissions (Android)
- Restart Arduino
- Try "Stop Scan" then scan again

### Issue: Connection drops frequently
**Solutions:**
- Keep phone within 3-5 meters
- Avoid obstacles between devices
- Check battery level
- Reduce BLE interference (other devices)

### Issue: Metrics show zeros or incorrect values
**Solutions:**
- Verify sensor initialization in Serial monitor
- Check if device is actually moving
- Reset statistics
- Reconnect BLE connection

### Issue: Trajectory looks random/erratic
**Expected Behavior:**
- Trajectory uses acceleration for relative motion
- Not GPS-accurate positioning
- Shows motion patterns, not absolute path
- Some noise is normal

## ✅ Success Criteria

Your implementation is working correctly if:

- [x] Firmware compiles and uploads without errors
- [x] All sensors initialize successfully
- [x] BLE advertises as "FlowTrack"
- [x] App connects and shows all cards
- [x] Basic metrics update in real-time
- [x] Advanced metrics respond to motion
- [x] Temperature displays current conditions
- [x] ML quality scores change with technique
- [x] Trajectory plots motion patterns
- [x] Session auto-starts/stops correctly
- [x] No crashes or freezes during use

## 📊 Performance Benchmarks

### Expected Performance:
- **BLE Latency:** <100ms sensor to display
- **Update Rate:** 50Hz (20ms intervals)
- **UI Refresh:** 60fps smooth
- **Battery Life:** 4-6 hours continuous (estimated)
- **Memory Usage:** ~40KB RAM on Arduino
- **App Memory:** ~50-100MB on phone

### To Measure:
1. **Latency:** Move device sharply, observe delay in graph
2. **Rate:** Count updates in Serial monitor (should be ~50/sec)
3. **Battery:** Note start time, check periodically
4. **Memory:** Monitor in Arduino IDE during upload

## 📝 Testing Report Template

```markdown
# Test Report - Flow Track Pro Advanced Features

**Date:** [DATE]
**Tester:** [NAME]
**Hardware:** Arduino Nano 33 BLE Sense Rev2
**App Platform:** iOS/Android [VERSION]

## Results

### Firmware
- [ ] Compiled successfully
- [ ] Uploaded successfully
- [ ] All sensors initialized
- [ ] BLE advertising

### App
- [ ] Compiled and ran
- [ ] Connected to device
- [ ] All UI elements display
- [ ] No crashes

### Features Tested
| Feature | Status | Notes |
|---------|--------|-------|
| Stroke length | ✅/❌ | |
| Paddle angles | ✅/❌ | |
| Smoothness | ✅/❌ | |
| Fatigue detection | ✅/❌ | |
| Asymmetry | ✅/❌ | |
| Temperature | ✅/❌ | |
| ML quality | ✅/❌ | |
| Trajectory | ✅/❌ | |
| Auto session | ✅/❌ | |

### Issues Found
1. [Description]
2. [Description]

### Overall Assessment
[PASS/FAIL] - [Comments]
```

## 🎓 Next Steps After Testing

1. **If all tests pass:**
   - Deploy to production use
   - Gather real-world data
   - Calibrate thresholds for your paddling style
   - Consider training TinyML models with collected data

2. **If issues found:**
   - Document issues clearly
   - Check troubleshooting section
   - Review code for the failing feature
   - Open GitHub issue with details

3. **For ML Enhancement:**
   - Collect labeled stroke data
   - Train TensorFlow Lite models
   - Replace heuristics with trained models
   - See ADVANCED_FEATURES.md for ML roadmap

---

Good luck with testing! 🚀
