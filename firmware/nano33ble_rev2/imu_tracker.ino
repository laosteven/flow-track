#include <ArduinoBLE.h>
#include <Arduino_BMI270_BMM150.h>

// BLE Service and Characteristics UUIDs
BLEService imuService("180A");           // Custom IMU service
BLECharacteristic accelChar("2A37", BLERead | BLENotify, 12); // 3 floats * 4 bytes
BLECharacteristic gyroChar("2A38", BLERead | BLENotify, 12);  // 3 floats * 4 bytes

void setup() {
  Serial.begin(115200);
  while (!Serial);

  Serial.println("Initializing IMU...");
  if (!IMU.begin()) {
    Serial.println("Failed to initialize IMU!");
    while (1);
  }

  Serial.println("IMU initialized.");

  // Start BLE
  if (!BLE.begin()) {
    Serial.println("Failed to start BLE!");
    while (1);
  }

  BLE.setLocalName("DragonPaddleIMU");
  BLE.setAdvertisedService(imuService);

  imuService.addCharacteristic(accelChar);
  imuService.addCharacteristic(gyroChar);
  BLE.addService(imuService);

  BLE.advertise();
  Serial.println("BLE device active, waiting for connections...");
}

void loop() {
  BLEDevice central = BLE.central(); // wait for a BLE central

  if (central) {
    Serial.print("Connected to central: ");
    Serial.println(central.address());

    while (central.connected()) {
      float ax, ay, az;
      float gx, gy, gz;

      if (IMU.accelerationAvailable() && IMU.gyroscopeAvailable()) {
        IMU.readAcceleration(ax, ay, az);
        IMU.readGyroscope(gx, gy, gz);

        // Convert floats to bytes
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

        // Optional: print to Serial
        Serial.print("A:");
        Serial.print(ax); Serial.print(",");
        Serial.print(ay); Serial.print(",");
        Serial.print(az);

        Serial.print("  G:");
        Serial.print(gx); Serial.print(",");
        Serial.print(gy); Serial.print(",");
        Serial.println(gz);
      }

      delay(20); // ~50Hz
    }

    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }
}
