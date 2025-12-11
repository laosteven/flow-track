/*
 * Simple IMU Test Program
 * Use this to verify your Arduino Nano 33 BLE Sense Rev2 IMU is working
 * 
 * This program doesn't use BLE - just prints sensor data to Serial Monitor
 * Good for initial hardware testing
 */

#include <Arduino_BMI270_BMM150.h>

void setup() {
  Serial.begin(115200);
  while (!Serial);
  
  Serial.println("IMU Test Program");
  Serial.println("================");
  
  if (!IMU.begin()) {
    Serial.println("Failed to initialize IMU!");
    Serial.println("Possible causes:");
    Serial.println("- Wrong board selected (must be Nano 33 BLE)");
    Serial.println("- Damaged IMU chip");
    Serial.println("- Old firmware version");
    while (1) {
      delay(1000);
    }
  }
  
  Serial.println("✓ IMU initialized successfully!");
  Serial.println("");
  Serial.println("Accelerometer and Gyroscope Test");
  Serial.println("================================");
  Serial.println("Move the board around to see sensor readings");
  Serial.println("");
}

void loop() {
  float ax, ay, az;
  float gx, gy, gz;
  
  if (IMU.accelerationAvailable()) {
    IMU.readAcceleration(ax, ay, az);
  }
  
  if (IMU.gyroscopeAvailable()) {
    IMU.readGyroscope(gx, gy, gz);
  }
  
  // Print in CSV format for easy plotting
  Serial.print("Accel(g): ");
  Serial.print(ax, 3); Serial.print(", ");
  Serial.print(ay, 3); Serial.print(", ");
  Serial.print(az, 3);
  
  Serial.print("  |  Gyro(deg/s): ");
  Serial.print(gx, 2); Serial.print(", ");
  Serial.print(gy, 2); Serial.print(", ");
  Serial.print(gz, 2);
  
  // Calculate and print magnitude
  float mag = sqrt(ax*ax + ay*ay + az*az);
  Serial.print("  |  Mag: ");
  Serial.println(mag, 3);
  
  delay(100); // 10Hz - easy to read
}
