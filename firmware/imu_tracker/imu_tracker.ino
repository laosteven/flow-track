/*
 * Dragon Paddle Tracker - Arduino Firmware
 * For Arduino Nano 33 BLE Sense Rev2
 * 
 * Reads IMU data (accelerometer + gyroscope) and streams via BLE
 * Calculates basic stroke statistics on-device
 * 
 * Hardware: Arduino Nano 33 BLE Sense Rev2 with BMI270/BMM150 IMU
 * BLE Service UUID: 180A
 * Accel Characteristic: 2A37
 * Gyro Characteristic: 2A38
 */

#include <ArduinoBLE.h>
#include <Arduino_BMI270_BMM150.h>

// BLE Service and Characteristics UUIDs
BLEService imuService("180A");           // Custom IMU service
BLECharacteristic accelChar("2A37", BLERead | BLENotify, 12); // 3 floats * 4 bytes
BLECharacteristic gyroChar("2A38", BLERead | BLENotify, 12);  // 3 floats * 4 bytes

// Stroke detection parameters
const float STROKE_THRESHOLD = 15.0;  // Magnitude threshold for stroke detection
const unsigned long MIN_STROKE_INTERVAL = 300; // Minimum milliseconds between strokes

bool isInStroke = false;
unsigned long lastStrokeTime = 0;
int totalStrokes = 0;

// LED for visual feedback
const int LED_PIN = LED_BUILTIN;

void setup() {
  Serial.begin(115200);
  
  // Initialize LED
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  
  // Wait for serial connection (optional, comment out for standalone operation)
  // while (!Serial);

  Serial.println("Dragon Paddle Tracker - Initializing...");
  Serial.println("========================================");
  
  // Initialize IMU
  Serial.println("Initializing IMU...");
  if (!IMU.begin()) {
    Serial.println("Failed to initialize IMU!");
    // Blink LED rapidly to indicate error
    while (1) {
      digitalWrite(LED_PIN, !digitalRead(LED_PIN));
      delay(100);
    }
  }
  Serial.println("✓ IMU initialized successfully");

  // Start BLE
  Serial.println("Initializing BLE...");
  if (!BLE.begin()) {
    Serial.println("Failed to start BLE!");
    while (1) {
      digitalWrite(LED_PIN, !digitalRead(LED_PIN));
      delay(200);
    }
  }
  Serial.println("✓ BLE initialized successfully");

  // Configure BLE
  BLE.setLocalName("DragonPaddleIMU");
  BLE.setAdvertisedService(imuService);

  imuService.addCharacteristic(accelChar);
  imuService.addCharacteristic(gyroChar);
  BLE.addService(imuService);

  BLE.advertise();
  Serial.println("✓ BLE advertising started");
  Serial.println("========================================");
  Serial.println("Ready! Waiting for connections...");
  Serial.println("Device Name: DragonPaddleIMU");
  Serial.println("========================================");
  
  // Blink LED to show ready state
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
    Serial.println("Streaming IMU data...");
    
    digitalWrite(LED_PIN, HIGH); // LED on when connected
    
    unsigned long lastSampleTime = 0;
    const unsigned long SAMPLE_INTERVAL = 20; // 20ms = 50Hz

    while (central.connected()) {
      unsigned long currentTime = millis();
      
      // Sample at 50Hz
      if (currentTime - lastSampleTime >= SAMPLE_INTERVAL) {
        lastSampleTime = currentTime;
        
        float ax, ay, az;
        float gx, gy, gz;

        if (IMU.accelerationAvailable() && IMU.gyroscopeAvailable()) {
          IMU.readAcceleration(ax, ay, az);
          IMU.readGyroscope(gx, gy, gz);

          // Detect strokes based on acceleration magnitude
          float magnitude = sqrt(ax*ax + ay*ay + az*az);
          detectStroke(magnitude);

          // Convert floats to bytes (little-endian)
          byte accelData[12];
          byte gyroData[12];

          memcpy(accelData, &ax, 4);
          memcpy(accelData + 4, &ay, 4);
          memcpy(accelData + 8, &az, 4);

          memcpy(gyroData, &gx, 4);
          memcpy(gyroData + 4, &gy, 4);
          memcpy(gyroData + 8, &gz, 4);

          // Update BLE characteristics
          accelChar.writeValue(accelData, 12);
          gyroChar.writeValue(gyroData, 12);

          // Print to Serial for debugging (reduce frequency to avoid overwhelming)
          static unsigned long lastPrint = 0;
          if (currentTime - lastPrint > 1000) { // Print once per second
            Serial.print("Accel: [");
            Serial.print(ax, 2); Serial.print(", ");
            Serial.print(ay, 2); Serial.print(", ");
            Serial.print(az, 2); Serial.print("] ");
            
            Serial.print("Gyro: [");
            Serial.print(gx, 2); Serial.print(", ");
            Serial.print(gy, 2); Serial.print(", ");
            Serial.print(gz, 2); Serial.print("] ");
            
            Serial.print("Mag: ");
            Serial.print(magnitude, 2);
            Serial.print(" | Strokes: ");
            Serial.println(totalStrokes);
            
            lastPrint = currentTime;
          }
        }
      }
      
      // Small delay to prevent busy-waiting
      delay(1);
    }

    digitalWrite(LED_PIN, LOW); // LED off when disconnected
    Serial.println("");
    Serial.print("✗ Disconnected from: ");
    Serial.println(central.address());
    Serial.println("Waiting for new connection...");
  }
}

// Stroke detection function
void detectStroke(float magnitude) {
  unsigned long currentTime = millis();
  
  // Check if magnitude exceeds threshold
  if (magnitude > STROKE_THRESHOLD && !isInStroke) {
    // Check minimum interval since last stroke
    if (currentTime - lastStrokeTime > MIN_STROKE_INTERVAL) {
      isInStroke = true;
      lastStrokeTime = currentTime;
      totalStrokes++;
      
      // Note: LED stays solid when connected, no flash needed
      // to avoid blocking with delay()
      
      Serial.print("STROKE detected! Total: ");
      Serial.println(totalStrokes);
    }
  } 
  // Reset stroke detection when magnitude drops
  else if (magnitude < STROKE_THRESHOLD * 0.5 && isInStroke) {
    isInStroke = false;
  }
}
