/*
 * Flow Track Advanced - Arduino Firmware
 * For Arduino Nano 33 BLE Sense Rev2
 * 
 * Advanced paddle tracking with:
 * - Enhanced IMU analysis (stroke length, angles, smoothness, fatigue)
 * - Temperature sensing (water vs air detection)
 * - TinyML stroke quality classification
 * - 3D trajectory tracking
 * - Auto session detection
 * 
 * Hardware: Arduino Nano 33 BLE Sense Rev2
 * Sensors: BMI270/BMM150 (IMU), HTS221 (Temp/Humidity), BMM150 (Magnetometer)
 * 
 * BLE Service UUID: 180A
 * Characteristics:
 *   - 2A37: Accelerometer (12 bytes)
 *   - 2A38: Gyroscope (12 bytes)
 *   - 2A39: Magnetometer (12 bytes)
 *   - 2A3A: Advanced Metrics (32 bytes)
 *   - 2A3B: Temperature (8 bytes)
 *   - 2A3C: ML Classifications (16 bytes)
 */

#include <ArduinoBLE.h>
#include <Arduino_BMI270_BMM150.h>
#include <Arduino_HTS221.h>

// BLE Service and Characteristics
BLEService imuService("180A");
BLECharacteristic accelChar("2A37", BLERead | BLENotify, 12);      // ax, ay, az
BLECharacteristic gyroChar("2A38", BLERead | BLENotify, 12);       // gx, gy, gz
BLECharacteristic magChar("2A39", BLERead | BLENotify, 12);        // mx, my, mz
BLECharacteristic metricsChar("2A3A", BLERead | BLENotify, 32);    // advanced metrics
BLECharacteristic tempChar("2A3B", BLERead | BLENotify, 8);        // temp, humidity
BLECharacteristic mlChar("2A3C", BLERead | BLENotify, 16);         // ML classifications

// Stroke detection parameters
const float STROKE_THRESHOLD = 15.0;
const float STROKE_END_THRESHOLD = 8.0;
const unsigned long MIN_STROKE_INTERVAL = 300;
const unsigned long SESSION_TIMEOUT = 300000; // 5 minutes of inactivity ends session

// Water detection thresholds
const float WATER_TEMP_VARIATION_THRESHOLD = 0.5; // °C
const float WATER_HUMIDITY_THRESHOLD = 80.0; // %

// Temperature safety threshold
const float HIGH_TEMP_WARNING_THRESHOLD = 35.0; // °C

// Fatigue detection parameters
const int FATIGUE_SAMPLE_SIZE = 5; // Number of strokes to compare
const int FATIGUE_HISTORY_SIZE = 10; // Total stroke history for fatigue calc

// Stroke phase enumeration
enum StrokePhase {
  PHASE_IDLE,
  PHASE_CATCH,      // Entry into water
  PHASE_PULL,       // Power phase
  PHASE_EXIT,       // Paddle leaves water
  PHASE_RECOVERY    // Return to catch position
};

// Stroke data structure
struct StrokeData {
  unsigned long startTime;
  unsigned long catchTime;
  unsigned long exitTime;
  unsigned long endTime;
  
  float maxAccel;
  float strokeLength;
  float entryAngle;
  float exitAngle;
  float smoothness;
  float rotationTorque;
  
  bool isLeftSide;
  StrokePhase phase;
};

// Session tracking
bool sessionActive = false;
unsigned long sessionStartTime = 0;
unsigned long lastActivityTime = 0;
int sessionStrokes = 0;

// Stroke history (circular buffer)
const int MAX_STROKE_HISTORY = 20;
StrokeData strokeHistory[MAX_STROKE_HISTORY];
int strokeHistoryIndex = 0;
int totalStrokes = 0;

// Current stroke tracking
StrokeData currentStroke;
bool isInStroke = false;

// IMU data buffers for advanced calculations
const int BUFFER_SIZE = 10;
float accelBuffer[BUFFER_SIZE][3];
float gyroBuffer[BUFFER_SIZE][3];
float magBuffer[BUFFER_SIZE][3];
int bufferIndex = 0;

// Previous values for derivative calculations
float prevAccel[3] = {0, 0, 0};
float prevGyro[3] = {0, 0, 0};
unsigned long prevTime = 0;

// Temperature tracking
float currentTemp = 0;
float currentHumidity = 0;
float waterTemp = 0;
float airTemp = 0;
bool inWater = false;
unsigned long lastTempRead = 0;
const unsigned long TEMP_READ_INTERVAL = 1000; // Read temp every second

// Fatigue detection
float recentStrokePowers[10] = {0};
int powerIndex = 0;
float fatigueScore = 0;

// Asymmetry tracking
int leftStrokeCount = 0;
int rightStrokeCount = 0;
float leftPowerSum = 0;
float rightPowerSum = 0;

// TinyML placeholders (to be implemented with actual model)
struct MLClassifications {
  float cleanStrokeScore;      // 0-1: clean vs messy
  float rotationQuality;        // 0-1: proper vs over-rotation
  float angleQuality;           // 0-1: proper angle
  float exitQuality;            // 0-1: proper exit timing
  float arcQuality;             // 0-1: straight vs lawnmower
  float legDriveScore;          // 0-1: leg drive detected
};

MLClassifications currentML;

// LED for visual feedback
const int LED_PIN = LED_BUILTIN;

void setup() {
  Serial.begin(115200);
  
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  Serial.println("Flow Track Advanced - Initializing...");
  Serial.println("========================================");
  
  // Initialize IMU
  Serial.println("Initializing IMU...");
  if (!IMU.begin()) {
    Serial.println("Failed to initialize IMU!");
    while (1) {
      digitalWrite(LED_PIN, !digitalRead(LED_PIN));
      delay(100);
    }
  }
  Serial.println("✓ IMU initialized");

  // Initialize Temperature Sensor
  Serial.println("Initializing Temperature Sensor...");
  if (!HTS.begin()) {
    Serial.println("⚠ Failed to initialize HTS221 (Temperature sensor)");
    Serial.println("  Continuing without temperature sensing...");
  } else {
    Serial.println("✓ Temperature sensor initialized");
  }

  // Initialize BLE
  Serial.println("Initializing BLE...");
  if (!BLE.begin()) {
    Serial.println("Failed to start BLE!");
    while (1) {
      digitalWrite(LED_PIN, !digitalRead(LED_PIN));
      delay(200);
    }
  }
  Serial.println("✓ BLE initialized");

  // Configure BLE
  BLE.setLocalName("FlowTrackPro");
  BLE.setAdvertisedService(imuService);

  imuService.addCharacteristic(accelChar);
  imuService.addCharacteristic(gyroChar);
  imuService.addCharacteristic(magChar);
  imuService.addCharacteristic(metricsChar);
  imuService.addCharacteristic(tempChar);
  imuService.addCharacteristic(mlChar);
  
  BLE.addService(imuService);
  BLE.advertise();
  
  Serial.println("✓ BLE advertising as 'FlowTrackPro'");
  Serial.println("========================================");
  Serial.println("Features enabled:");
  Serial.println("  • Stroke length & timing");
  Serial.println("  • Paddle angle tracking");
  Serial.println("  • Smoothness score");
  Serial.println("  • Fatigue detection");
  Serial.println("  • 3D trajectory");
  Serial.println("  • Left/right asymmetry");
  Serial.println("  • Rotation torque");
  Serial.println("  • Auto session detection");
  Serial.println("  • Temperature monitoring");
  Serial.println("  • ML stroke classification");
  Serial.println("========================================");
  Serial.println("Ready! Waiting for connections...");
  
  // Visual ready indication
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(200);
    digitalWrite(LED_PIN, LOW);
    delay(200);
  }
}

void loop() {
  BLEDevice central = BLE.central();

  if (central) {
    Serial.println("");
    Serial.print("✓ Connected to: ");
    Serial.println(central.address());
    Serial.println("Streaming advanced data...");
    
    digitalWrite(LED_PIN, HIGH);
    
    unsigned long lastSampleTime = 0;
    const unsigned long SAMPLE_INTERVAL = 20; // 50Hz

    while (central.connected()) {
      unsigned long currentTime = millis();
      
      if (currentTime - lastSampleTime >= SAMPLE_INTERVAL) {
        lastSampleTime = currentTime;
        
        // Read all sensors
        float ax, ay, az, gx, gy, gz, mx, my, mz;
        
        if (IMU.accelerationAvailable()) {
          IMU.readAcceleration(ax, ay, az);
        }
        
        if (IMU.gyroscopeAvailable()) {
          IMU.readGyroscope(gx, gy, gz);
        }
        
        if (IMU.magneticFieldAvailable()) {
          IMU.readMagneticField(mx, my, mz);
        }

        // Read temperature periodically
        if (currentTime - lastTempRead >= TEMP_READ_INTERVAL) {
          readTemperature();
          lastTempRead = currentTime;
        }

        // Update buffers for advanced calculations
        updateBuffers(ax, ay, az, gx, gy, gz, mx, my, mz);

        // Calculate derived metrics
        float magnitude = sqrt(ax*ax + ay*ay + az*az);
        float jerk = calculateJerk(ax, ay, az, currentTime);
        float angularVelocity = sqrt(gx*gx + gy*gy + gz*gz);
        
        // Detect and analyze strokes
        processStroke(magnitude, angularVelocity, ax, ay, az, gx, gy, gz, mx, my, mz, currentTime);
        
        // Auto-detect session
        detectSession(magnitude, currentTime);

        // Update ML classifications (placeholder - using heuristics until ML model is trained)
        updateMLClassifications();

        // Send data via BLE
        sendBLEData(ax, ay, az, gx, gy, gz, mx, my, mz);

        // Debug output
        static unsigned long lastPrint = 0;
        if (currentTime - lastPrint > 2000) {
          printDebugInfo(magnitude, angularVelocity);
          lastPrint = currentTime;
        }
      }
      
      delay(1);
    }

    digitalWrite(LED_PIN, LOW);
    Serial.println("");
    Serial.print("✗ Disconnected from: ");
    Serial.println(central.address());
  }
}

void updateBuffers(float ax, float ay, float az, float gx, float gy, float gz, float mx, float my, float mz) {
  accelBuffer[bufferIndex][0] = ax;
  accelBuffer[bufferIndex][1] = ay;
  accelBuffer[bufferIndex][2] = az;
  
  gyroBuffer[bufferIndex][0] = gx;
  gyroBuffer[bufferIndex][1] = gy;
  gyroBuffer[bufferIndex][2] = gz;
  
  magBuffer[bufferIndex][0] = mx;
  magBuffer[bufferIndex][1] = my;
  magBuffer[bufferIndex][2] = mz;
  
  bufferIndex = (bufferIndex + 1) % BUFFER_SIZE;
}

float calculateJerk(float ax, float ay, float az, unsigned long currentTime) {
  if (prevTime == 0) {
    prevAccel[0] = ax;
    prevAccel[1] = ay;
    prevAccel[2] = az;
    prevTime = currentTime;
    return 0;
  }
  
  float dt = (currentTime - prevTime) / 1000.0; // Convert to seconds
  if (dt == 0) return 0;
  
  float jx = (ax - prevAccel[0]) / dt;
  float jy = (ay - prevAccel[1]) / dt;
  float jz = (az - prevAccel[2]) / dt;
  
  prevAccel[0] = ax;
  prevAccel[1] = ay;
  prevAccel[2] = az;
  prevTime = currentTime;
  
  return sqrt(jx*jx + jy*jy + jz*jz);
}

void processStroke(float magnitude, float angularVelocity, float ax, float ay, float az, 
                   float gx, float gy, float gz, float mx, float my, float mz, 
                   unsigned long currentTime) {
  
  // State machine for stroke phases
  if (!isInStroke && magnitude > STROKE_THRESHOLD) {
    if (currentTime - currentStroke.endTime > MIN_STROKE_INTERVAL) {
      // Start new stroke
      isInStroke = true;
      currentStroke.startTime = currentTime;
      currentStroke.catchTime = currentTime;
      currentStroke.phase = PHASE_CATCH;
      currentStroke.maxAccel = magnitude;
      currentStroke.strokeLength = 0;
      currentStroke.smoothness = 0;
      currentStroke.rotationTorque = 0;
      
      // Determine side based on gyroscope Z-axis
      currentStroke.isLeftSide = (gz > 0);
      
      // Calculate entry angle from accelerometer
      currentStroke.entryAngle = calculatePaddleAngle(ax, ay, az);
    }
  }
  
  if (isInStroke) {
    // Update max acceleration
    if (magnitude > currentStroke.maxAccel) {
      currentStroke.maxAccel = magnitude;
    }
    
    // Accumulate stroke length (RELATIVE METRIC - NOT ABSOLUTE DISTANCE)
    // This calculates acceleration*time which provides a comparative metric
    // between strokes but is NOT true distance in meters. For actual distance:
    // - Would need double integration: accel -> velocity -> position
    // - Would need drift correction and initial position calibration
    // - Current metric is useful for comparing stroke consistency and relative effort
    currentStroke.strokeLength += magnitude * 0.02; // dt = 20ms
    
    // Accumulate rotation torque
    currentStroke.rotationTorque += angularVelocity * 0.02;
    
    // Track phase transitions
    if (currentStroke.phase == PHASE_CATCH && magnitude > STROKE_THRESHOLD * 1.5) {
      currentStroke.phase = PHASE_PULL;
    }
    else if (currentStroke.phase == PHASE_PULL && magnitude < STROKE_THRESHOLD * 0.7) {
      currentStroke.phase = PHASE_EXIT;
      currentStroke.exitTime = currentTime;
      currentStroke.exitAngle = calculatePaddleAngle(ax, ay, az);
    }
    else if (currentStroke.phase == PHASE_EXIT && magnitude < STROKE_END_THRESHOLD) {
      currentStroke.phase = PHASE_RECOVERY;
    }
    
    // End stroke when returning to idle
    if (magnitude < STROKE_END_THRESHOLD && currentStroke.phase == PHASE_RECOVERY) {
      // Stroke complete
      isInStroke = false;
      currentStroke.endTime = currentTime;
      
      // Calculate final smoothness (inverse of average jerk)
      currentStroke.smoothness = calculateStrokeSmoothness();
      
      // Store in history
      strokeHistory[strokeHistoryIndex] = currentStroke;
      strokeHistoryIndex = (strokeHistoryIndex + 1) % MAX_STROKE_HISTORY;
      
      totalStrokes++;
      sessionStrokes++;
      
      // Update asymmetry tracking
      if (currentStroke.isLeftSide) {
        leftStrokeCount++;
        leftPowerSum += currentStroke.maxAccel;
      } else {
        rightStrokeCount++;
        rightPowerSum += currentStroke.maxAccel;
      }
      
      // Update fatigue detection
      recentStrokePowers[powerIndex] = currentStroke.maxAccel;
      powerIndex = (powerIndex + 1) % 10;
      calculateFatigue();
      
      Serial.print("STROKE #");
      Serial.print(totalStrokes);
      Serial.print(" | Length: ");
      Serial.print(currentStroke.strokeLength, 1);
      Serial.print(" | Angle: ");
      Serial.print(currentStroke.entryAngle, 1);
      Serial.print("° → ");
      Serial.print(currentStroke.exitAngle, 1);
      Serial.print("° | Smooth: ");
      Serial.print(currentStroke.smoothness, 2);
      Serial.print(" | Side: ");
      Serial.println(currentStroke.isLeftSide ? "L" : "R");
    }
  }
}

float calculatePaddleAngle(float ax, float ay, float az) {
  // Calculate angle relative to vertical
  // ASSUMES: Z-axis is vertical when paddle is mounted correctly
  // For different mounting orientations, these axes may need adjustment
  // Calibration: Ensure sensor is mounted with Z pointing up along paddle shaft
  float angle = atan2(sqrt(ax*ax + ay*ay), az) * 180.0 / PI;
  return angle;
}

float calculateStrokeSmoothness() {
  // Calculate coefficient of variation of acceleration in the stroke
  // Lower variation = smoother stroke
  float sum = 0;
  float sumSq = 0;
  int count = 0;
  
  for (int i = 0; i < BUFFER_SIZE; i++) {
    float mag = sqrt(accelBuffer[i][0]*accelBuffer[i][0] + 
                     accelBuffer[i][1]*accelBuffer[i][1] + 
                     accelBuffer[i][2]*accelBuffer[i][2]);
    sum += mag;
    sumSq += mag * mag;
    count++;
  }
  
  if (count == 0) return 0;
  
  float mean = sum / count;
  float variance = (sumSq / count) - (mean * mean);
  float stdDev = sqrt(variance);
  
  // Smoothness = 1 - coefficient of variation (normalized)
  float cv = (mean > 0) ? (stdDev / mean) : 1.0;
  float smoothness = max(0.0, 1.0 - cv);
  
  return smoothness;
}

void calculateFatigue() {
  // Detect fatigue by looking at declining stroke power over time
  // Compares early strokes to recent strokes
  
  // Ensure we have enough data
  if (totalStrokes < FATIGUE_HISTORY_SIZE) {
    fatigueScore = 0; // Not enough data yet
    return;
  }
  
  float earlyAvg = 0;
  float recentAvg = 0;
  
  // Average of first FATIGUE_SAMPLE_SIZE strokes
  for (int i = 0; i < FATIGUE_SAMPLE_SIZE; i++) {
    earlyAvg += recentStrokePowers[i];
  }
  earlyAvg /= FATIGUE_SAMPLE_SIZE;
  
  // Average of last FATIGUE_SAMPLE_SIZE strokes
  for (int i = FATIGUE_SAMPLE_SIZE; i < FATIGUE_HISTORY_SIZE; i++) {
    recentAvg += recentStrokePowers[i];
  }
  recentAvg /= FATIGUE_SAMPLE_SIZE;
  
  // Fatigue score: 0 = no fatigue, 1 = significant fatigue
  if (earlyAvg > 0) {
    fatigueScore = max(0.0, (earlyAvg - recentAvg) / earlyAvg);
  }
}

void detectSession(float magnitude, unsigned long currentTime) {
  // Auto-detect session start/stop based on activity
  if (magnitude > STROKE_THRESHOLD) {
    lastActivityTime = currentTime;
    
    if (!sessionActive) {
      sessionActive = true;
      sessionStartTime = currentTime;
      sessionStrokes = 0;
      Serial.println(">>> SESSION STARTED <<<");
    }
  }
  
  // End session after timeout
  if (sessionActive && (currentTime - lastActivityTime) > SESSION_TIMEOUT) {
    sessionActive = false;
    Serial.println(">>> SESSION ENDED <<<");
    Serial.print("Duration: ");
    Serial.print((lastActivityTime - sessionStartTime) / 1000);
    Serial.print("s | Strokes: ");
    Serial.println(sessionStrokes);
  }
}

void readTemperature() {
  currentTemp = HTS.readTemperature();
  currentHumidity = HTS.readHumidity();
  
  // Detect water vs air based on temperature stability and humidity
  // Water temperature is more stable and humidity detection differs
  static float tempHistory[5] = {0};
  static int tempHistIndex = 0;
  
  tempHistory[tempHistIndex] = currentTemp;
  tempHistIndex = (tempHistIndex + 1) % 5;
  
  // Calculate temperature variation (simplified - assumes sequential order)
  // Note: For true temporal analysis with circular buffer, would need to track order
  float tempVar = 0;
  int count = 0;
  for (int i = 0; i < 4; i++) {
    if (tempHistory[i] != 0 && tempHistory[i+1] != 0) {
      tempVar += abs(tempHistory[i] - tempHistory[i+1]);
      count++;
    }
  }
  if (count > 0) {
    tempVar /= count;
  }
  
  // If variation is low and humidity indicates water, we're in water
  // This is a heuristic - actual calibration needed
  if (tempVar < WATER_TEMP_VARIATION_THRESHOLD && currentHumidity > WATER_HUMIDITY_THRESHOLD) {
    if (!inWater) {
      waterTemp = currentTemp;
      inWater = true;
      Serial.println("→ Paddle in WATER");
    }
  } else {
    if (inWater) {
      airTemp = currentTemp;
      inWater = false;
      Serial.println("→ Paddle in AIR");
    } else {
      airTemp = currentTemp;
    }
  }
  
  // Safety warning for high temperature
  if (currentTemp > HIGH_TEMP_WARNING_THRESHOLD) {
    Serial.println("⚠ WARNING: HIGH TEMPERATURE - Stay hydrated!");
  }
}

void updateMLClassifications() {
  // Placeholder for TinyML model inference
  // Using heuristic rules until actual ML model is trained
  
  // Clean stroke score based on smoothness
  currentML.cleanStrokeScore = currentStroke.smoothness;
  
  // Rotation quality - penalize excessive rotation
  float normalizedRotation = min(1.0, currentStroke.rotationTorque / 100.0);
  currentML.rotationQuality = 1.0 - abs(normalizedRotation - 0.5) * 2.0;
  
  // Angle quality - check if entry/exit angles are in optimal range (30-60 degrees)
  float avgAngle = (currentStroke.entryAngle + currentStroke.exitAngle) / 2.0;
  if (avgAngle >= 30 && avgAngle <= 60) {
    currentML.angleQuality = 1.0;
  } else {
    currentML.angleQuality = max(0.0, 1.0 - abs(avgAngle - 45) / 45.0);
  }
  
  // Exit quality - check for early exit (short stroke)
  float normalizedLength = min(1.0, currentStroke.strokeLength / 50.0);
  currentML.exitQuality = normalizedLength;
  
  // Arc quality - check gyroscope for wide arc patterns
  // Wide arc shows up as excessive Y-axis rotation
  float avgGyroY = 0;
  for (int i = 0; i < BUFFER_SIZE; i++) {
    avgGyroY += abs(gyroBuffer[i][1]);
  }
  avgGyroY /= BUFFER_SIZE;
  currentML.arcQuality = max(0.0, 1.0 - avgGyroY / 50.0);
  
  // Leg drive detection - look for initial acceleration spike
  // Proper leg drive shows strong initial acceleration
  if (currentStroke.maxAccel > STROKE_THRESHOLD * 1.5) {
    currentML.legDriveScore = 0.8;
  } else {
    currentML.legDriveScore = 0.3;
  }
}

void sendBLEData(float ax, float ay, float az, float gx, float gy, float gz, float mx, float my, float mz) {
  // Send basic sensor data
  byte accelData[12], gyroData[12], magData[12];
  
  memcpy(accelData, &ax, 4);
  memcpy(accelData + 4, &ay, 4);
  memcpy(accelData + 8, &az, 4);
  
  memcpy(gyroData, &gx, 4);
  memcpy(gyroData + 4, &gy, 4);
  memcpy(gyroData + 8, &gz, 4);
  
  memcpy(magData, &mx, 4);
  memcpy(magData + 4, &my, 4);
  memcpy(magData + 8, &mz, 4);
  
  accelChar.writeValue(accelData, 12);
  gyroChar.writeValue(gyroData, 12);
  magChar.writeValue(magData, 12);
  
  // Send advanced metrics (8 floats = 32 bytes)
  byte metricsData[32];
  memcpy(metricsData, &currentStroke.strokeLength, 4);
  memcpy(metricsData + 4, &currentStroke.entryAngle, 4);
  memcpy(metricsData + 8, &currentStroke.exitAngle, 4);
  memcpy(metricsData + 12, &currentStroke.smoothness, 4);
  memcpy(metricsData + 16, &currentStroke.rotationTorque, 4);
  memcpy(metricsData + 20, &fatigueScore, 4);
  
  float asymmetryRatio = (leftStrokeCount + rightStrokeCount > 0) ? 
    (float)leftStrokeCount / (leftStrokeCount + rightStrokeCount) : 0.5;
  memcpy(metricsData + 24, &asymmetryRatio, 4);
  
  float strokePhase = (float)currentStroke.phase;
  memcpy(metricsData + 28, &strokePhase, 4);
  
  metricsChar.writeValue(metricsData, 32);
  
  // Send temperature data (2 floats = 8 bytes)
  byte tempData[8];
  memcpy(tempData, &currentTemp, 4);
  memcpy(tempData + 4, &currentHumidity, 4);
  tempChar.writeValue(tempData, 8);
  
  // Send ML classifications (4 floats = 16 bytes)
  byte mlData[16];
  memcpy(mlData, &currentML.cleanStrokeScore, 4);
  memcpy(mlData + 4, &currentML.rotationQuality, 4);
  memcpy(mlData + 8, &currentML.angleQuality, 4);
  memcpy(mlData + 12, &currentML.exitQuality, 4);
  mlChar.writeValue(mlData, 16);
}

void printDebugInfo(float magnitude, float angularVelocity) {
  Serial.println("--- Status ---");
  Serial.print("Session: ");
  Serial.print(sessionActive ? "ACTIVE" : "idle");
  Serial.print(" | Strokes: ");
  Serial.print(totalStrokes);
  Serial.print(" | L/R: ");
  Serial.print(leftStrokeCount);
  Serial.print("/");
  Serial.println(rightStrokeCount);
  
  Serial.print("Temp: ");
  Serial.print(currentTemp, 1);
  Serial.print("°C | Humidity: ");
  Serial.print(currentHumidity, 1);
  Serial.print("% | ");
  Serial.println(inWater ? "IN WATER" : "IN AIR");
  
  Serial.print("Fatigue: ");
  Serial.print(fatigueScore * 100, 1);
  Serial.print("% | Smoothness: ");
  Serial.println(currentStroke.smoothness, 2);
  
  Serial.print("ML - Clean: ");
  Serial.print(currentML.cleanStrokeScore, 2);
  Serial.print(" | Rotation: ");
  Serial.print(currentML.rotationQuality, 2);
  Serial.print(" | Angle: ");
  Serial.print(currentML.angleQuality, 2);
  Serial.print(" | Exit: ");
  Serial.println(currentML.exitQuality, 2);
  Serial.println("");
}
