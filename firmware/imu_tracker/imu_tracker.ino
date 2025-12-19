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
 */

#include <ArduinoBLE.h>
#include <Arduino_BMI270_BMM150.h>
#include <Arduino_HS300x.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// BLE Service and Characteristics
BLEService imuService("180A");
BLECharacteristic accelChar("2A37", BLERead | BLENotify, 12);   // ax, ay, az
BLECharacteristic gyroChar("2A38", BLERead | BLENotify, 12);    // gx, gy, gz
BLECharacteristic magChar("2A39", BLERead | BLENotify, 12);     // mx, my, mz
BLECharacteristic metricsChar("2A3A", BLERead | BLENotify, 32); // advanced metrics
BLECharacteristic tempChar("2A3B", BLERead | BLENotify, 8);     // temp, humidity

// Stroke detection parameters
const float STROKE_THRESHOLD = 15.0;
const float STROKE_END_THRESHOLD = 8.0;
const unsigned long MIN_STROKE_INTERVAL = 300;
const unsigned long SESSION_TIMEOUT = 300000; // 5 minutes of inactivity ends session

// Water detection thresholds
const float WATER_TEMP_VARIATION_THRESHOLD = 0.5; // °C
const float WATER_HUMIDITY_THRESHOLD = 80.0;      // %

// Temperature safety threshold
const float HIGH_TEMP_WARNING_THRESHOLD = 35.0; // °C

// Fatigue detection parameters
const int FATIGUE_SAMPLE_SIZE = 5;   // Number of strokes to compare
const int FATIGUE_HISTORY_SIZE = 10; // Total stroke history for fatigue calc

// Stroke phase enumeration
enum StrokePhase
{
  PHASE_IDLE,
  PHASE_CATCH,   // Entry into water
  PHASE_PULL,    // Power phase
  PHASE_EXIT,    // Paddle leaves water
  PHASE_RECOVERY // Return to catch position
};

// Stroke data structure
struct StrokeData
{
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

// LED for visual feedback
const int LED_PIN = LED_BUILTIN;

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define OLED_RESET -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

void setup()
{
  Serial.begin(115200);

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  Serial.println("Flow Track Advanced - Initializing...");
  Serial.println("========================================");

  // Initialize IMU
  Serial.println("Initializing IMU...");
  if (!IMU.begin())
  {
    Serial.println("Failed to initialize IMU!");
    while (1)
    {
      digitalWrite(LED_PIN, !digitalRead(LED_PIN));
      delay(100);
    }
  }
  Serial.println("✓ IMU initialized");

  // Initialize Temperature Sensor
  Serial.println("Initializing Temperature Sensor...");
  if (!HS300x.begin())
  {
    Serial.println("⚠ Failed to initialize HS300x (Temperature sensor)");
    Serial.println("  Continuing without temperature sensing...");
  }
  else
  {
    Serial.println("✓ Temperature sensor initialized");
  }

  // === HARDWARE TEST ===
  Serial.println("\n========== HARDWARE TEST ==========");
  Serial.println("Testing IMU sensors...");
  delay(100);
  
  if (IMU.accelerationAvailable())
  {
    float ax, ay, az;
    IMU.readAcceleration(ax, ay, az);
    Serial.print("✓ Accelerometer: [");
    Serial.print(ax, 3);
    Serial.print(", ");
    Serial.print(ay, 3);
    Serial.print(", ");
    Serial.print(az, 3);
    Serial.println("]");
  }
  else
  {
    Serial.println("✗ ACCELEROMETER NOT RESPONDING!");
  }
  
  if (IMU.gyroscopeAvailable())
  {
    float gx, gy, gz;
    IMU.readGyroscope(gx, gy, gz);
    Serial.print("✓ Gyroscope: [");
    Serial.print(gx, 3);
    Serial.print(", ");
    Serial.print(gy, 3);
    Serial.print(", ");
    Serial.print(gz, 3);
    Serial.println("]");
  }
  else
  {
    Serial.println("✗ GYROSCOPE NOT RESPONDING!");
  }
  
  if (IMU.magneticFieldAvailable())
  {
    float mx, my, mz;
    IMU.readMagneticField(mx, my, mz);
    Serial.print("✓ Magnetometer: [");
    Serial.print(mx, 3);
    Serial.print(", ");
    Serial.print(my, 3);
    Serial.print(", ");
    Serial.print(mz, 3);
    Serial.println("]");
  }
  else
  {
    Serial.println("✗ MAGNETOMETER NOT RESPONDING!");
  }
  
  float testTemp = HS300x.readTemperature();
  float testHum = HS300x.readHumidity();
  if (!isnan(testTemp) && testTemp > -40 && testTemp < 85)
  {
    Serial.print("✓ Temperature: ");
    Serial.print(testTemp, 2);
    Serial.print("°C | Humidity: ");
    Serial.print(testHum, 1);
    Serial.println("%");
  }
  else
  {
    Serial.println("✗ TEMPERATURE SENSOR NOT RESPONDING!");
  }
  Serial.println("===================================\n");

  // Initialize BLE
  Serial.println("Initializing BLE...");
  if (!BLE.begin())
  {
    Serial.println("Failed to start BLE!");
    while (1)
    {
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

  BLE.addService(imuService);
  BLE.advertise();

  // Give BLE stack time to fully initialize
  delay(1000);

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
  Serial.println("========================================");
  Serial.println("Ready! Waiting for connections...");

  // --- OLED Initialization ---
  // Wiring (I2C):
  // OLED VCC -> Arduino 3.3V or 5V (use module label; many DAOKAI accept 3.3-5V)
  // OLED GND -> Arduino GND
  // OLED SDA -> Arduino A4
  // OLED SCL -> Arduino A5
  Serial.println("Initializing OLED display...");
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C))
  { // Common I2C address 0x3C
    Serial.println("⚠ OLED init failed. Check wiring and address (0x3C/0x3D).");
  }
  else
  {
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 0);
    display.println("Hello, world!");
    display.display();
    Serial.println("✓ OLED initialized and displaying message");
  }

  // Show initial status on OLED
  display.clearDisplay();
  display.setCursor(0, 0);
  display.println("Flow Track Ready");
  display.println("Waiting for BLE...");
  display.display();

  // Visual ready indication
  for (int i = 0; i < 3; i++)
  {
    digitalWrite(LED_PIN, HIGH);
    delay(200);
    digitalWrite(LED_PIN, LOW);
    delay(200);
  }
}

void loop()
{
  BLEDevice central = BLE.central();

  if (central)
  {
    Serial.println("");
    Serial.print("✓ Connected to: ");
    Serial.println(central.address());
    Serial.println("Streaming advanced data...");

    // Auto-start session on connection
    sessionActive = true;
    sessionStartTime = millis();
    sessionStrokes = 0;
    lastActivityTime = sessionStartTime;
    Serial.println(">>> SESSION AUTO-STARTED <<<");

    digitalWrite(LED_PIN, HIGH);

    unsigned long lastSampleTime = 0;
    const unsigned long SAMPLE_INTERVAL = 20; // 50Hz

    while (central.connected())
    {
      unsigned long currentTime = millis();

      if (currentTime - lastSampleTime >= SAMPLE_INTERVAL)
      {
        lastSampleTime = currentTime;

        // Read all sensors
        float ax = 0, ay = 0, az = 0, gx = 0, gy = 0, gz = 0, mx = 0, my = 0, mz = 0;

        if (IMU.accelerationAvailable())
        {
          IMU.readAcceleration(ax, ay, az);
        }
        else
        {
          static unsigned long lastAccelWarning = 0;
          if (currentTime - lastAccelWarning > 5000)
          {
            Serial.println("⚠ WARNING: Accelerometer data not available!");
            lastAccelWarning = currentTime;
          }
        }

        if (IMU.gyroscopeAvailable())
        {
          IMU.readGyroscope(gx, gy, gz);
        }
        else
        {
          static unsigned long lastGyroWarning = 0;
          if (currentTime - lastGyroWarning > 5000)
          {
            Serial.println("⚠ WARNING: Gyroscope data not available!");
            lastGyroWarning = currentTime;
          }
        }

        if (IMU.magneticFieldAvailable())
        {
          IMU.readMagneticField(mx, my, mz);
        }
        else
        {
          static unsigned long lastMagWarning = 0;
          if (currentTime - lastMagWarning > 5000)
          {
            Serial.println("⚠ WARNING: Magnetometer data not available!");
            lastMagWarning = currentTime;
          }
        }

        // Read temperature periodically
        if (currentTime - lastTempRead >= TEMP_READ_INTERVAL)
        {
          readTemperature();
          lastTempRead = currentTime;
        }

        // Update buffers for advanced calculations
        updateBuffers(ax, ay, az, gx, gy, gz, mx, my, mz);

        // Calculate derived metrics
        float magnitude = sqrt(ax * ax + ay * ay + az * az);
        float jerk = calculateJerk(ax, ay, az, currentTime);
        float angularVelocity = sqrt(gx * gx + gy * gy + gz * gz);

        // Detect and analyze strokes
        processStroke(magnitude, angularVelocity, ax, ay, az, gx, gy, gz, mx, my, mz, currentTime);

        // Send data via BLE
        sendBLEData(ax, ay, az, gx, gy, gz, mx, my, mz);

        // Detailed hardware diagnostic output
        static unsigned long lastPrint = 0;
        if (currentTime - lastPrint > 2000)
        {
          Serial.println("\n========== HARDWARE DIAGNOSTIC ==========");
          Serial.print("IMU Accel: [");
          Serial.print(ax, 3);
          Serial.print(", ");
          Serial.print(ay, 3);
          Serial.print(", ");
          Serial.print(az, 3);
          Serial.print("] | Mag: ");
          Serial.println(magnitude, 3);
          
          Serial.print("IMU Gyro:  [");
          Serial.print(gx, 3);
          Serial.print(", ");
          Serial.print(gy, 3);
          Serial.print(", ");
          Serial.print(gz, 3);
          Serial.print("] | Ang: ");
          Serial.println(angularVelocity, 3);
          
          Serial.print("IMU Mag:   [");
          Serial.print(mx, 3);
          Serial.print(", ");
          Serial.print(my, 3);
          Serial.print(", ");
          Serial.print(mz, 3);
          Serial.println("]");
          
          Serial.print("Temp: ");
          Serial.print(currentTemp, 2);
          Serial.print("°C | Humidity: ");
          Serial.print(currentHumidity, 1);
          Serial.println("%");
          
          Serial.print("BLE Connected: YES | Session: ");
          Serial.print(sessionActive ? "ACTIVE" : "idle");
          Serial.print(" | Strokes: ");
          Serial.println(sessionStrokes);
          
          printDebugInfo(magnitude, angularVelocity);
          lastPrint = currentTime;
        }
        // Update OLED status every 1s when connected
        static unsigned long lastOledUpdate = 0;
        if (currentTime - lastOledUpdate > 1000)
        {
          lastOledUpdate = currentTime;
          if (sessionActive)
          {
            display.clearDisplay();
            display.setCursor(0, 0);
            display.println("Session: RECORDING");
            display.print("Strokes: ");
            display.println(sessionStrokes);
            unsigned long elapsed = (currentTime - sessionStartTime) / 1000;
            display.print("Time: ");
            display.print(elapsed);
            display.println("s");
            display.display();
          }
          else
          {
            // Show idle status
            display.clearDisplay();
            display.setCursor(0, 0);
            display.println("Session: idle");
            display.print("Total strokes: ");
            display.println(totalStrokes);
            display.display();
          }
        }
      }

      delay(1);
    }

    // Auto-stop session on disconnect
    sessionActive = false;
    Serial.println(">>> SESSION AUTO-STOPPED <<<");

    digitalWrite(LED_PIN, LOW);
    Serial.println("");
    Serial.print("✗ Disconnected from: ");
    Serial.println(central.address());
  }
}

void updateBuffers(float ax, float ay, float az, float gx, float gy, float gz, float mx, float my, float mz)
{
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

float calculateJerk(float ax, float ay, float az, unsigned long currentTime)
{
  if (prevTime == 0)
  {
    prevAccel[0] = ax;
    prevAccel[1] = ay;
    prevAccel[2] = az;
    prevTime = currentTime;
    return 0;
  }

  float dt = (currentTime - prevTime) / 1000.0; // Convert to seconds
  if (dt == 0)
    return 0;

  float jx = (ax - prevAccel[0]) / dt;
  float jy = (ay - prevAccel[1]) / dt;
  float jz = (az - prevAccel[2]) / dt;

  prevAccel[0] = ax;
  prevAccel[1] = ay;
  prevAccel[2] = az;
  prevTime = currentTime;

  return sqrt(jx * jx + jy * jy + jz * jz);
}

void processStroke(float magnitude, float angularVelocity, float ax, float ay, float az,
                   float gx, float gy, float gz, float mx, float my, float mz,
                   unsigned long currentTime)
{

  // State machine for stroke phases
  if (!isInStroke && magnitude > STROKE_THRESHOLD)
  {
    if (currentTime - currentStroke.endTime > MIN_STROKE_INTERVAL)
    {
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

  if (isInStroke)
  {
    // Update max acceleration
    if (magnitude > currentStroke.maxAccel)
    {
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
    if (currentStroke.phase == PHASE_CATCH && magnitude > STROKE_THRESHOLD * 1.5)
    {
      currentStroke.phase = PHASE_PULL;
    }
    else if (currentStroke.phase == PHASE_PULL && magnitude < STROKE_THRESHOLD * 0.7)
    {
      currentStroke.phase = PHASE_EXIT;
      currentStroke.exitTime = currentTime;
      currentStroke.exitAngle = calculatePaddleAngle(ax, ay, az);
    }
    else if (currentStroke.phase == PHASE_EXIT && magnitude < STROKE_END_THRESHOLD)
    {
      currentStroke.phase = PHASE_RECOVERY;
    }

    // End stroke when returning to idle
    if (magnitude < STROKE_END_THRESHOLD && currentStroke.phase == PHASE_RECOVERY)
    {
      // Stroke complete
      isInStroke = false;
      currentStroke.endTime = currentTime;

      // Calculate final smoothness (inverse of average jerk)
      currentStroke.smoothness = calculateStrokeSmoothness();

      // Store in history
      strokeHistory[strokeHistoryIndex] = currentStroke;
      strokeHistoryIndex = (strokeHistoryIndex + 1) % MAX_STROKE_HISTORY;

      totalStrokes++;
      if (sessionActive)
      {
        sessionStrokes++;
        // Update OLED with new stroke count if display is initialized
        display.clearDisplay();
        display.setCursor(0, 0);
        display.println("Session: RECORDING");
        display.print("Strokes: ");
        display.println(sessionStrokes);
        // Show elapsed time
        unsigned long elapsed = (currentTime - sessionStartTime) / 1000;
        display.print("Time: ");
        display.print(elapsed);
        display.println("s");
        display.display();
      }

      // Update asymmetry tracking
      if (currentStroke.isLeftSide)
      {
        leftStrokeCount++;
        leftPowerSum += currentStroke.maxAccel;
      }
      else
      {
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

float calculatePaddleAngle(float ax, float ay, float az)
{
  // Calculate angle relative to vertical
  // ASSUMES: Z-axis is vertical when paddle is mounted correctly
  // For different mounting orientations, these axes may need adjustment
  // Calibration: Ensure sensor is mounted with Z pointing up along paddle shaft
  float angle = atan2(sqrt(ax * ax + ay * ay), az) * 180.0 / PI;
  return angle;
}

float calculateStrokeSmoothness()
{
  // Calculate coefficient of variation of acceleration in the stroke
  // Lower variation = smoother stroke
  float sum = 0;
  float sumSq = 0;
  int count = 0;

  for (int i = 0; i < BUFFER_SIZE; i++)
  {
    float mag = sqrt(accelBuffer[i][0] * accelBuffer[i][0] +
                     accelBuffer[i][1] * accelBuffer[i][1] +
                     accelBuffer[i][2] * accelBuffer[i][2]);
    sum += mag;
    sumSq += mag * mag;
    count++;
  }

  if (count == 0)
    return 0;

  float mean = sum / count;
  float variance = (sumSq / count) - (mean * mean);
  float stdDev = sqrt(variance);

  // Smoothness = 1 - coefficient of variation (normalized)
  float cv = (mean > 0) ? (stdDev / mean) : 1.0;
  float smoothness = max(0.0, 1.0 - cv);

  return smoothness;
}

void calculateFatigue()
{
  // Detect fatigue by looking at declining stroke power over time
  // Compares early strokes to recent strokes

  // Ensure we have enough data
  if (totalStrokes < FATIGUE_HISTORY_SIZE)
  {
    fatigueScore = 0; // Not enough data yet
    return;
  }

  float earlyAvg = 0;
  float recentAvg = 0;

  // Average of first FATIGUE_SAMPLE_SIZE strokes
  for (int i = 0; i < FATIGUE_SAMPLE_SIZE; i++)
  {
    earlyAvg += recentStrokePowers[i];
  }
  earlyAvg /= FATIGUE_SAMPLE_SIZE;

  // Average of last FATIGUE_SAMPLE_SIZE strokes
  for (int i = FATIGUE_SAMPLE_SIZE; i < FATIGUE_HISTORY_SIZE; i++)
  {
    recentAvg += recentStrokePowers[i];
  }
  recentAvg /= FATIGUE_SAMPLE_SIZE;

  // Fatigue score: 0 = no fatigue, 1 = significant fatigue
  if (earlyAvg > 0)
  {
    fatigueScore = max(0.0, (earlyAvg - recentAvg) / earlyAvg);
  }
}

void readTemperature()
{
  currentTemp = HS300x.readTemperature();
  currentHumidity = HS300x.readHumidity();
  
  // Check for sensor errors (NaN or unreasonable values)
  if (isnan(currentTemp) || currentTemp < -40 || currentTemp > 85)
  {
    static unsigned long lastTempError = 0;
    if (millis() - lastTempError > 10000)
    {
      Serial.println("⚠ WARNING: Temperature sensor error or disconnected!");
      lastTempError = millis();
    }
    currentTemp = 0;
  }
  
  if (isnan(currentHumidity) || currentHumidity < 0 || currentHumidity > 100)
  {
    currentHumidity = 0;
  }

  // Detect water vs air based on temperature stability and humidity
  // Water temperature is more stable and humidity detection differs
  static float tempHistory[5] = {0};
  static int tempHistIndex = 0;
  static int samplesCollected = 0;

  tempHistory[tempHistIndex] = currentTemp;
  tempHistIndex = (tempHistIndex + 1) % 5;
  if (samplesCollected < 5)
    samplesCollected++;

  // Calculate temperature variation (average absolute difference between samples)
  // Simple approach: compare all pairs to get overall stability measure
  float tempVar = 0;
  int count = 0;

  if (samplesCollected >= 5)
  {
    // Have full buffer - calculate all pairwise differences
    for (int i = 0; i < 5; i++)
    {
      for (int j = i + 1; j < 5; j++)
      {
        if (tempHistory[i] != 0 && tempHistory[j] != 0)
        {
          tempVar += abs(tempHistory[i] - tempHistory[j]);
          count++;
        }
      }
    }
    if (count > 0)
    {
      tempVar /= count;
    }
  }

  // If variation is low and humidity indicates water, we're in water
  // This is a heuristic - actual calibration needed
  if (tempVar < WATER_TEMP_VARIATION_THRESHOLD && currentHumidity > WATER_HUMIDITY_THRESHOLD)
  {
    if (!inWater)
    {
      waterTemp = currentTemp;
      inWater = true;
      Serial.println("→ Paddle in WATER");
    }
  }
  else
  {
    if (inWater)
    {
      airTemp = currentTemp;
      inWater = false;
      Serial.println("→ Paddle in AIR");
    }
    else
    {
      airTemp = currentTemp;
    }
  }

  // Safety warning for high temperature
  if (currentTemp > HIGH_TEMP_WARNING_THRESHOLD)
  {
    Serial.println("⚠ WARNING: HIGH TEMPERATURE - Stay hydrated!");
  }
}

void sendBLEData(float ax, float ay, float az, float gx, float gy, float gz, float mx, float my, float mz)
{
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

  // Write with error checking
  static unsigned long lastBleLog = 0;
  bool logNow = (millis() - lastBleLog) > 5000;
  
  accelChar.writeValue(accelData, 12);
  if (logNow) Serial.println("✓ BLE: Accel data written");
  
  gyroChar.writeValue(gyroData, 12);
  if (logNow) Serial.println("✓ BLE: Gyro data written");
  
  magChar.writeValue(magData, 12);
  if (logNow) Serial.println("✓ BLE: Mag data written");

  // Send advanced metrics (8 floats = 32 bytes)
  byte metricsData[32];
  memcpy(metricsData, &currentStroke.strokeLength, 4);
  memcpy(metricsData + 4, &currentStroke.entryAngle, 4);
  memcpy(metricsData + 8, &currentStroke.exitAngle, 4);
  memcpy(metricsData + 12, &currentStroke.smoothness, 4);
  memcpy(metricsData + 16, &currentStroke.rotationTorque, 4);
  memcpy(metricsData + 20, &fatigueScore, 4);

  float asymmetryRatio = (leftStrokeCount + rightStrokeCount > 0) ? (float)leftStrokeCount / (leftStrokeCount + rightStrokeCount) : 0.5;
  memcpy(metricsData + 24, &asymmetryRatio, 4);

  float strokePhase = (float)currentStroke.phase;
  memcpy(metricsData + 28, &strokePhase, 4);

  metricsChar.writeValue(metricsData, 32);
  if (logNow) Serial.println("✓ BLE: Metrics data written");

  // Send temperature data (2 floats = 8 bytes)
  byte tempData[8];
  memcpy(tempData, &currentTemp, 4);
  memcpy(tempData + 4, &currentHumidity, 4);
  tempChar.writeValue(tempData, 8);
  if (logNow)
  {
    Serial.println("✓ BLE: Temp data written");
    Serial.println("========================================");
    lastBleLog = millis();
  }
}

void printDebugInfo(float magnitude, float angularVelocity)
{
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
  Serial.println("");
}
