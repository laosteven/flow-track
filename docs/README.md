# Flow Track Documentation

Welcome to the Flow Track documentation! This folder contains detailed technical documentation for developers and advanced users.

## 📖 Documentation Index

### Getting Started
- **[Main README](../README.md)** - Project overview and quick start
- **[Getting Started Guide](../GETTING_STARTED.md)** - Detailed setup and installation instructions

### Technical Documentation
- **[Architecture](ARCHITECTURE.md)** - System architecture and technical design
- **[Features](FEATURES.md)** - Comprehensive feature documentation and specifications
- **[Testing Guide](TESTING.md)** - Testing procedures and validation
- **[Versioning](VERSIONING.md)** - Version management and release process

### Project Information
- **[Changelog](../CHANGELOG.md)** - Version history and release notes
- **[Hardware README](../hardware/README.md)** - Hardware designs and mounting instructions

## 📚 Original User Guide

Below is the original user-focused documentation for understanding metrics and usage.

---

## Table of Contents

1. [Quick Start Guide](#quick-start-guide)
2. [Understanding the Metrics](#understanding-the-metrics)
3. [Bluetooth Connection Guide](#bluetooth-connection-guide)
4. [Troubleshooting](#troubleshooting)
5. [Training Tips](#training-tips)
6. [Technical Reference](#technical-reference)

## Quick Start Guide

### First Time Setup

1. **Flash Arduino Firmware**
   - Install Arduino IDE
   - Install required libraries (ArduinoBLE, Arduino_BMI270_BMM150)
   - Upload firmware from `/firmware/nano33ble_rev2/imu_tracker.ino`

2. **Mount to Paddle**
   - Follow instructions in `/hardware/README.md`
   - Position ~30cm below hand grip
   - Ensure secure attachment with velcro

3. **Install Mobile App**
   - Build app from `/dragon_paddle_app`
   - Enable Bluetooth permissions
   - Grant location permissions (required for BLE scanning on Android)

4. **Connect and Start**
   - Power on Arduino (LED should blink 3 times)
   - Open app and tap Bluetooth icon
   - Select "DragonPaddleIMU" from list
   - Start paddling!

## Understanding the Metrics

### Stroke Rate (SPM)

**What it is:** Number of paddle strokes per minute

**How it's calculated:**
- System detects each stroke when acceleration exceeds threshold
- Calculates rate from last 10 strokes
- Updates in real-time during paddling

**Typical Ranges:**
- **20-40 SPM:** Warm-up, technique practice
- **40-60 SPM:** Standard training pace
- **60-80 SPM:** Race pace
- **80+ SPM:** Sprint, high-intensity bursts

**Color Indicators:**
- 🔵 Blue (<40): Warm-up pace
- 🟢 Green (40-60): Training pace
- 🟠 Orange (60-80): Race pace
- 🔴 Red (80+): Sprint pace

### Consistency Score

**What it is:** Measure of how uniform your strokes are (0-100%)

**How it's calculated:**
- Analyzes variation in stroke power (acceleration magnitude)
- Lower variation = higher consistency
- Based on last 20 strokes

**What it means:**
- **80-100%:** Excellent - very consistent technique
- **60-80%:** Good - minor variations
- **<60%:** Needs work - significant stroke-to-stroke differences

**Why it matters:**
- Consistent strokes = efficient energy use
- Helps maintain boat speed
- Indicates good technique and timing
- Important for synchronization with team

### Total Strokes

Simple counter of all strokes detected in current session.

**Use for:**
- Tracking workout volume
- Setting practice goals (e.g., "500 strokes today")
- Comparing sessions over time

### Average Power

**What it is:** Mean acceleration magnitude across all strokes

**Measured in:** m/s² (not watts - this is a proxy for power)

**Interpretation:**
- Higher values indicate more forceful strokes
- Compare within your own sessions (absolute values vary by mounting)
- Track improvement over time
- Balance power with consistency for best results

## Bluetooth Connection Guide

### Connecting

1. **Scan for Devices**
   - Ensure Arduino is powered on
   - Tap Bluetooth icon in app
   - Wait for "DragonPaddleIMU" to appear

2. **Troubleshooting Connection**
   - If device doesn't appear:
     - Check Arduino LED is on
     - Verify Bluetooth is enabled on phone
     - Try airplane mode on/off
     - Restart app
   - If connection fails:
     - Move phone closer to Arduino
     - Check battery level
     - Restart both devices

3. **Connection Range**
   - Typical range: 5-10 meters
   - Keep phone within ~5m during practice
   - Avoid obstacles between phone and Arduino

### During Practice

- Connection should remain stable
- If disconnected, app will show "Disconnected" status
- Data collection pauses during disconnection
- Reconnect by tapping Bluetooth icon

### Disconnecting

- Tap Bluetooth icon when done
- Or simply close app
- Arduino enters advertising mode again
- Safe to power off Arduino after disconnect

## Troubleshooting

### Arduino Issues

**LED blinks rapidly (fast):**
- IMU initialization failed
- Re-upload firmware
- Check for hardware damage

**LED blinks slowly:**
- BLE initialization failed
- Reset Arduino
- Check board package is correct

**No LED activity:**
- Check power connection
- Verify battery is charged
- Try different USB cable

**Inconsistent readings:**
- Tighten mounting straps
- Check for loose connections
- Ensure IMU isn't damaged

### App Issues

**Can't find device:**
- Enable Bluetooth and location services
- Grant all requested permissions
- Ensure Arduino is advertising (check LED)
- Try restarting app

**Connection drops frequently:**
- Check battery level on Arduino
- Reduce distance to phone
- Close other BLE apps
- Restart phone's Bluetooth

**Metrics seem wrong:**
- Reset statistics with refresh button
- Check Arduino mounting is secure
- Verify paddle orientation is correct
- Try re-connecting

**App crashes:**
- Update to latest Flutter version
- Check for OS updates
- Clear app cache
- Reinstall app

## Training Tips

### Using the Metrics Effectively

1. **Establish Baseline**
   - Do several practice sessions to establish your normal metrics
   - Note your typical stroke rate and consistency at different intensities
   - Track in training log

2. **Set Goals**
   - Stroke rate goals: "Maintain 55 SPM for 5 minutes"
   - Consistency goals: "Achieve 85%+ consistency"
   - Volume goals: "Complete 500 strokes per session"

3. **Interval Training**
   - Use stroke rate to pace intervals
   - Monitor consistency during high-intensity sets
   - Reset stats between sets

4. **Technique Work**
   - Focus on consistency over stroke rate
   - Try to maintain high consistency at different rates
   - Watch motion graph for irregular patterns

### Team Training

**For Coaches:**
- Multiple paddlers can use the system simultaneously
- Compare metrics between team members
- Identify who needs technique coaching
- Set team-wide consistency goals

**For Paddlers:**
- Match stroke rate with stroke seat
- Aim for team-wide consistency
- Use as feedback for synchronization
- Compare personal bests with teammates

### Best Practices

1. **Start of Session**
   - Power on Arduino before getting on water
   - Connect to app and verify data streaming
   - Reset stats at start of practice

2. **During Practice**
   - Glance at metrics between sets
   - Don't obsess over real-time numbers
   - Focus on feel, use data for confirmation

3. **After Practice**
   - Note final metrics in training log
   - Identify areas for improvement
   - Compare to previous sessions

4. **Regular Maintenance**
   - Check mounting before each use
   - Charge battery after every session
   - Update firmware when available

## Technical Reference

### BLE Protocol Details

**Service UUID:** `180A` (Device Information Service)

**Characteristics:**

1. **Accelerometer (`2A37`)**
   - Format: 12 bytes (3 × 4-byte floats)
   - Byte order: Little-endian
   - Units: g (gravitational units, ±4g range)
   - Update rate: ~50Hz
   - Structure: [X, Y, Z]

2. **Gyroscope (`2A38`)**
   - Format: 12 bytes (3 × 4-byte floats)
   - Byte order: Little-endian
   - Units: degrees/second (±2000 dps range)
   - Update rate: ~50Hz
   - Structure: [X, Y, Z]

### Data Processing Pipeline

```
Arduino:
  IMU → Read sensors (50Hz)
      → Detect strokes (threshold-based)
      → Convert to bytes
      → BLE notify

Flutter App:
  BLE receive → Parse bytes to floats
              → StrokeAnalyzer processes
              → Calculate metrics
              → Update UI (60Hz)
              → Store history
```

### Stroke Detection Algorithm

```
For each accelerometer reading:
  1. Calculate magnitude = sqrt(x² + y² + z²)
  2. If magnitude > threshold AND not in stroke:
       - Check minimum time since last stroke
       - If sufficient time passed:
           - Mark as stroke
           - Increment counter
           - Record timestamp and power
  3. If magnitude < threshold * 0.5:
       - Reset stroke detection state
```

**Tunable Parameters:**
- Threshold: 15.0 (default, can adjust for sensitivity)
- Minimum interval: 300ms (prevents double-counting)
- Hysteresis factor: 0.5 (for reset)

### Performance Characteristics

- **Latency:** <100ms end-to-end (sensor → display)
- **Battery:** 4-6 hours typical (with 1000mAh battery)
- **Memory:** ~50KB RAM usage on Arduino
- **Data rate:** ~1.2 KB/s over BLE
- **Accuracy:** ±0.06 g (accelerometer), ±0.1 dps (gyroscope)

### File Format (Future Feature)

For data export functionality (planned):

```json
{
  "session": {
    "date": "2025-01-15T10:30:00Z",
    "duration": 3600,
    "device": "DragonPaddleIMU-ABC123"
  },
  "summary": {
    "totalStrokes": 1250,
    "avgStrokeRate": 52.3,
    "avgConsistency": 87.5,
    "avgPower": 18.7
  },
  "data": [
    {
      "time": 0.0,
      "accel": [0.1, 9.8, 0.0],
      "gyro": [0.0, 0.0, 0.0]
    }
  ]
}
```

## Additional Resources

- **Arduino Documentation:** https://docs.arduino.cc/hardware/nano-33-ble-sense-rev2
- **Flutter BLE Guide:** https://pub.dev/packages/flutter_reactive_ble
- **FL Chart Documentation:** https://pub.dev/packages/fl_chart
- **Dragon Boat Training Resources:** (Add team-specific resources)

## Contributing

Have suggestions for improving the documentation? Please open an issue or pull request!
