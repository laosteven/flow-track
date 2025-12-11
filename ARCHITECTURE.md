# System Architecture

This document describes the architecture of the Dragon Paddle Tracker system.

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Dragon Paddle Tracker System                  │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────┐         ┌──────────────────┐         ┌──────────────────┐
│                  │         │                  │         │                  │
│  Arduino Nano    │◄───BLE─►│  Flutter App     │◄───UI──►│  Paddler         │
│  33 BLE          │         │  (Phone)         │         │                  │
│                  │         │                  │         │                  │
└──────────────────┘         └──────────────────┘         └──────────────────┘
      │                              │
      │                              │
   ┌──▼──┐                      ┌───▼────┐
   │ IMU │                      │ Storage│
   └─────┘                      └────────┘
```

## Component Architecture

### 1. Hardware Layer (Arduino)

```
Arduino Nano 33 BLE Sense Rev2
├── BMI270 (Accelerometer + Gyroscope)
├── ArduinoBLE (Bluetooth Stack)
└── Firmware Logic
    ├── IMU Data Collection (50Hz)
    ├── Stroke Detection Algorithm
    ├── BLE Service Management
    └── Power Management
```

**Responsibilities:**
- Read IMU data at 50Hz
- Detect paddle strokes in real-time
- Package data for BLE transmission
- Manage BLE connections
- Visual feedback via LED

**Key Files:**
- `firmware/nano33ble_rev2/imu_tracker.ino` - Main firmware
- `firmware/nano33ble_rev2/test_imu_simple.ino` - Test program

### 2. Communication Layer (BLE)

```
BLE Protocol (Bluetooth Low Energy 5.0)
├── Service UUID: 180A
├── Characteristics:
│   ├── Accelerometer (2A37) - 12 bytes, 50Hz
│   └── Gyroscope (2A38) - 12 bytes, 50Hz
└── Connection Management
```

**Data Format:**
```
Accelerometer/Gyroscope Characteristic (12 bytes):
┌──────────────────────────────────────────────────────────┐
│  X (float32)  │  Y (float32)  │  Z (float32)            │
│  4 bytes      │  4 bytes      │  4 bytes                │
│  Little Endian│  Little Endian│  Little Endian          │
└──────────────────────────────────────────────────────────┘
```

### 3. Mobile App Layer (Flutter)

```
Flutter Application Architecture
├── Presentation Layer (UI)
│   ├── Screens
│   │   └── HomeScreen - Main interface
│   └── Widgets
│       ├── StrokeRateCard - Big number display
│       ├── ConsistencyIndicator - Visual meter
│       ├── MotionGraph - Real-time chart
│       └── StatsCard - Individual metrics
│
├── Business Logic Layer
│   ├── Services
│   │   ├── BleService - BLE communication
│   │   ├── StrokeAnalyzer - Metrics calculation
│   │   └── StorageService - Data persistence
│   └── Models
│       └── SensorData - Data structures
│
└── Platform Layer
    ├── flutter_reactive_ble - BLE plugin
    └── fl_chart - Charting library
```

## Data Flow

### Real-Time Data Pipeline

```
1. SENSOR READING (Arduino)
   IMU.readAcceleration() → [ax, ay, az]
   IMU.readGyroscope() → [gx, gy, gz]
   Rate: 50Hz (every 20ms)
   
   ↓

2. LOCAL PROCESSING (Arduino)
   - Calculate magnitude: sqrt(ax² + ay² + az²)
   - Stroke detection: magnitude > threshold
   - LED feedback on stroke
   
   ↓

3. BLE TRANSMISSION (Arduino → Phone)
   - Convert floats to bytes (little-endian)
   - Update BLE characteristics
   - Notify connected device
   Latency: <20ms
   
   ↓

4. BLE RECEPTION (Phone)
   - Receive BLE notification
   - Parse bytes back to floats
   - Create SensorData objects
   Latency: <30ms
   
   ↓

5. ANALYSIS (StrokeAnalyzer)
   - Add to history buffer (500 samples)
   - Detect strokes (threshold + timing)
   - Calculate metrics:
     * Stroke rate (from last 10 strokes)
     * Consistency (coefficient of variation)
     * Average power (mean magnitude)
   Update rate: Real-time
   
   ↓

6. UI UPDATE (Flutter)
   - Update state via setState()
   - Rebuild widgets
   - Render charts (fl_chart)
   - Display metrics
   Refresh rate: 60fps
   
   ↓

7. VISUAL FEEDBACK (User)
   - Big numbers for stroke rate
   - Color indicators for consistency
   - Live motion graphs
   - Total stroke count
```

### Connection Flow

```
User Action: Tap "Scan"
   ↓
BleService.startScan()
   ↓
flutter_reactive_ble scans for devices
   ↓
Arduino advertises as "DragonPaddleIMU"
   ↓
Device discovered
   ↓
User Action: Tap "Connect"
   ↓
BleService.connect(deviceId)
   ↓
BLE connection established
   ↓
Subscribe to characteristics (2A37, 2A38)
   ↓
Arduino starts notifying with data
   ↓
Data flows to StrokeAnalyzer
   ↓
UI displays live metrics
```

## Algorithms

### Stroke Detection Algorithm

**Purpose:** Detect individual paddle strokes from accelerometer data

**Method:** Threshold-based detection with hysteresis

**Pseudocode:**
```
CONSTANTS:
  THRESHOLD = 15.0          # Acceleration magnitude threshold (m/s²)
  MIN_INTERVAL = 300ms      # Minimum time between strokes
  HYSTERESIS = 0.5          # Reset factor

STATE:
  isInStroke = false
  lastStrokeTime = 0
  
PROCESS(accel_data):
  magnitude = sqrt(x² + y² + z²)
  current_time = now()
  
  IF magnitude > THRESHOLD AND NOT isInStroke:
    IF current_time - lastStrokeTime > MIN_INTERVAL:
      # New stroke detected
      isInStroke = true
      lastStrokeTime = current_time
      totalStrokes++
      record_stroke_power(magnitude)
      
  ELSE IF magnitude < THRESHOLD * HYSTERESIS AND isInStroke:
    # Reset for next stroke
    isInStroke = false
```

**Rationale:**
- Threshold prevents noise/vibration from triggering false strokes
- Minimum interval prevents double-counting single strokes
- Hysteresis (0.5x threshold) ensures clean reset between strokes
- Simple and computationally efficient for embedded system

### Stroke Rate Calculation

**Purpose:** Calculate strokes per minute in real-time

**Method:** Time-windowed rate calculation

**Formula:**
```
strokeRate = (numStrokes - 1) / timeSpan * 60

Where:
  numStrokes = number of recent strokes (last 10)
  timeSpan = time between first and last stroke (seconds)
```

**Example:**
```
Stroke timestamps: [0.0, 1.2, 2.3, 3.5, 4.6, 5.8, 7.0, 8.1, 9.3, 10.5]
numStrokes = 10
timeSpan = 10.5 - 0.0 = 10.5 seconds
strokeRate = (10 - 1) / 10.5 * 60 = 51.4 SPM
```

### Consistency Calculation

**Purpose:** Measure stroke-to-stroke uniformity

**Method:** Coefficient of Variation (inverted)

**Formula:**
```
consistency = (1 - CV) * 100%

Where:
  CV = standardDeviation / mean
  standardDeviation = sqrt(variance)
  variance = sum((x - mean)²) / n
  mean = sum(strokePowers) / n
```

**Interpretation:**
- 100% = Perfect consistency (all strokes identical)
- 80%+ = Excellent (minor variations)
- 60-80% = Good (moderate variations)
- <60% = Needs improvement (large variations)

**Why it works:**
- CV measures relative variability
- Lower CV = more consistent
- Inverted to make higher = better
- Percentage makes it intuitive

## Performance Characteristics

### Latency Budget

```
Sensor Reading:        20ms  (50Hz sampling)
BLE Transmission:      10ms  (typical)
BLE Reception:         10ms  (typical)
Data Processing:       <5ms  (parsing + analysis)
UI Update:            16ms  (60fps)
                     ─────
Total End-to-End:    ~60ms  (acceptable for real-time)
```

### Throughput

```
Data per reading:      24 bytes (12 accel + 12 gyro)
Sampling rate:         50 Hz
Bandwidth:            1,200 bytes/sec = ~10 kbps
BLE overhead:         ~2x (headers, acknowledgments)
Total BLE usage:      ~20 kbps (well within BLE 1 Mbps capacity)
```

### Battery Life (Estimated)

```
Arduino Power Consumption:
  - Active (BLE + IMU):    ~25mA @ 3.7V = ~93mW
  - Sleep mode:            ~5µA (not implemented)

With 1000mAh battery:
  - Continuous operation:  ~40 hours (theoretical)
  - Realistic usage:       4-6 hours (BLE overhead, variations)
  - With sleep mode:       Days to weeks (future enhancement)
```

### Memory Usage

```
Arduino (256KB Flash, 64KB RAM):
  - Firmware code:         ~50KB Flash
  - BLE stack:            ~100KB Flash  
  - Runtime variables:     ~5KB RAM
  - BLE buffers:          ~10KB RAM
  Total available:        ~35KB Flash, ~49KB RAM remaining

Flutter App (varies by platform):
  - App size:             ~15MB (with dependencies)
  - Runtime memory:       ~50MB typical
  - History buffer:       ~50KB (500 samples × 100 bytes)
```

## Security Considerations

### Current Implementation

- **No pairing required** - Open BLE connection
- **No encryption** - Data transmitted in clear
- **No authentication** - Any device can connect
- **Local data only** - No cloud storage

### Rationale

For a personal training device:
- Open connection allows quick pairing
- Motion data is not sensitive
- Local storage maintains privacy
- Simple architecture reduces bugs

### Future Enhancements (If Needed)

- BLE pairing for exclusive connection
- Data encryption for privacy
- User authentication for multi-user scenarios
- Optional cloud sync with end-to-end encryption

## Scalability

### Current Limitations

- **Single device** - One Arduino per phone
- **No data persistence** - Data lost on app close
- **Local only** - No sharing between devices

### Future Extensions

**Multi-device support:**
```
Phone
  ├─► Arduino 1 (Stroke seat)
  ├─► Arduino 2 (Your paddle)
  └─► Arduino 3 (Bow seat)
```

**Data persistence:**
```
Add:
  - shared_preferences (simple key-value)
  - hive (NoSQL database)
  - sqflite (SQL database)
```

**Team synchronization:**
```
Optional cloud backend:
  - Firebase for real-time sync
  - REST API for session uploads
  - WebSockets for live team view
```

## Technology Choices

### Why Arduino Nano 33 BLE Sense Rev2?

✅ Built-in IMU (BMI270) - no external sensors needed
✅ BLE 5.0 support - modern, efficient
✅ Small form factor - easy to mount
✅ USB-C - convenient for development
✅ Wide community support

### Why Flutter?

✅ Cross-platform (iOS + Android) from single codebase
✅ Fast development with hot reload
✅ Excellent BLE library (flutter_reactive_ble)
✅ Rich UI components
✅ Good charting library (fl_chart)

### Why flutter_reactive_ble?

✅ Most actively maintained Flutter BLE library
✅ Clean reactive API with streams
✅ Good error handling
✅ Supports both iOS and Android
✅ Works well with BMI270 data rates

### Why fl_chart?

✅ Pure Dart - no native dependencies
✅ Smooth animations
✅ Real-time data streaming support
✅ Customizable appearance
✅ Good performance with live data

## Testing Strategy

### Hardware Testing
- Use `test_imu_simple.ino` to verify IMU
- Check Serial Monitor for data
- Test BLE with nRF Connect app
- Verify LED patterns

### App Testing
- Unit tests for StrokeAnalyzer logic
- Widget tests for UI components
- Integration tests for BLE communication
- Manual testing on real device

### Integration Testing
- End-to-end data flow verification
- Latency measurements
- Battery life testing
- Outdoor durability testing

## Deployment

### Arduino Deployment
1. Upload via Arduino IDE
2. Verify via Serial Monitor
3. Mount to paddle
4. Test connection with app

### App Deployment

**Development:**
```bash
flutter run
```

**Production (Android):**
```bash
flutter build apk --release
```

**Production (iOS):**
```bash
flutter build ios --release
# Then sign and distribute via App Store Connect
```

## Maintenance

### Firmware Updates
- Flash new .ino file via USB
- Users can update themselves
- No OTA (over-the-air) currently

### App Updates
- Distribute via app stores (future)
- Currently: rebuild from source
- Version in pubspec.yaml

### Backward Compatibility
- BLE protocol should remain stable
- New features added as optional
- Graceful degradation for older firmware

## References

- Arduino Nano 33 BLE Docs: https://docs.arduino.cc/hardware/nano-33-ble-sense-rev2
- BMI270 Datasheet: https://www.bosch-sensortec.com/products/motion-sensors/imus/bmi270/
- Flutter BLE: https://pub.dev/packages/flutter_reactive_ble
- FL Chart: https://pub.dev/packages/fl_chart
- BLE Spec: https://www.bluetooth.com/specifications/gatt/
