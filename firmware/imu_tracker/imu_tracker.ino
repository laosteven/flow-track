/*
 * Flow Track - Arduino firmware
 * For Arduino Nano 33 BLE Sense Rev2
 *
 * Simple raw sensor streaming:
 * - IMU data (accelerometer, gyroscope, magnetometer)
 * - Temperature and humidity
 * - All processing done on mobile app
 *
 * Hardware: Arduino Nano 33 BLE Sense Rev2
 * Sensors: BMI270/BMM150 (IMU), HS300x (Temp/Humidity)
 *
 * Characteristics:
 *   - 2A37: Accelerometer (12 bytes) - ax, ay, az
 *   - 2A38: Gyroscope (12 bytes) - gx, gy, gz
 *   - 2A39: Magnetometer (12 bytes) - mx, my, mz
 *   - 2A3B: Temperature (8 bytes) - temp, humidity
 */

#include <ArduinoBLE.h>
#include <Arduino_BMI270_BMM150.h>
#include <Arduino_HS300x.h>

// BLE Service and Characteristics
BLEService imuService("180A");
BLECharacteristic accelChar("2A37", BLERead | BLENotify, 12); // ax, ay, az
BLECharacteristic gyroChar("2A38", BLERead | BLENotify, 12);  // gx, gy, gz
BLECharacteristic magChar("2A39", BLERead | BLENotify, 12);   // mx, my, mz
BLECharacteristic tempChar("2A3B", BLERead | BLENotify, 8);   // temp, humidity

// Temperature tracking
float currentTemp = 0;
float currentHumidity = 0;
unsigned long lastTempRead = 0;
const unsigned long TEMP_READ_INTERVAL = 1000;

// LED for visual feedback
const int LED_PIN = LED_BUILTIN;

#define DEVICE_NAME "FlowTrack"

void setup()
{
  Serial.begin(115200);

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  Serial.println("Flow Track - Raw sensor streaming");
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
  Serial.println("Initializing Temperature sensor...");
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

  // Configure BLE with unique name based on MAC address
  String macAddress = BLE.address();
  String uniqueName = String(DEVICE_NAME) + "-" + macAddress.substring(macAddress.length() - 5);
  uniqueName.replace(":", ""); // Remove colon from MAC address suffix
  BLE.setLocalName(uniqueName.c_str());
  BLE.setAdvertisedService(imuService);

  imuService.addCharacteristic(accelChar);
  imuService.addCharacteristic(gyroChar);
  imuService.addCharacteristic(magChar);
  imuService.addCharacteristic(tempChar);

  BLE.addService(imuService);
  BLE.advertise();

  // Give BLE stack time to fully initialize
  delay(1000);

  Serial.print("✓ BLE advertising as '");
  Serial.print(uniqueName);
  Serial.println("'");
  Serial.println("========================================");
  Serial.println("Streaming:");
  Serial.println("  • Raw accelerometer data");
  Serial.println("  • Raw gyroscope data");
  Serial.println("  • Raw magnetometer data");
  Serial.println("  • Temperature & humidity");
  Serial.println("========================================");
  Serial.println("Ready! Waiting for connections...");

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
    Serial.println("Streaming raw sensor data...");

    digitalWrite(LED_PIN, HIGH);

    unsigned long lastSampleTime = 0;
    const unsigned long SAMPLE_INTERVAL = 10; // 100 Hz

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
          currentTemp = HS300x.readTemperature();
          currentHumidity = HS300x.readHumidity();

          // Check for sensor errors
          if (isnan(currentTemp) || currentTemp < -40 || currentTemp > 85)
          {
            currentTemp = 0;
          }
          if (isnan(currentHumidity) || currentHumidity < 0 || currentHumidity > 100)
          {
            currentHumidity = 0;
          }

          lastTempRead = currentTime;
        }

        // Calculate magnitudes for display
        float accelMag = sqrt(ax * ax + ay * ay + az * az);
        float gyroMag = sqrt(gx * gx + gy * gy + gz * gz);

        // Send raw data via BLE
        sendBLEData(ax, ay, az, gx, gy, gz, mx, my, mz);

        // Debug output
        static unsigned long lastPrint = 0;
        if (currentTime - lastPrint > 2000)
        {
          Serial.println("\n=== RAW SENSOR DATA ===");
          Serial.print("Accel: [");
          Serial.print(ax, 3);
          Serial.print(", ");
          Serial.print(ay, 3);
          Serial.print(", ");
          Serial.print(az, 3);
          Serial.print("] | Mag: ");
          Serial.println(accelMag, 3);

          Serial.print("Gyro:  [");
          Serial.print(gx, 3);
          Serial.print(", ");
          Serial.print(gy, 3);
          Serial.print(", ");
          Serial.print(gz, 3);
          Serial.print("] | Mag: ");
          Serial.println(gyroMag, 3);

          Serial.print("Mag:   [");
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
          Serial.println("=======================");

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
  delay(1);
}

void sendBLEData(float ax, float ay, float az, float gx, float gy, float gz, float mx, float my, float mz)
{
  // Send raw sensor data
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

  // Send temperature data (2 floats = 8 bytes)
  byte tempData[8];
  memcpy(tempData, &currentTemp, 4);
  memcpy(tempData + 4, &currentHumidity, 4);
  tempChar.writeValue(tempData, 8);
}
