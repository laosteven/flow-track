import 'dart:typed_data';
import 'dart:math' as math;

/// Model for accelerometer data
class AccelerometerData {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  AccelerometerData({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  /// Parse accelerometer data from BLE bytes
  static AccelerometerData fromBytes(Uint8List bytes) {
    final buffer = bytes.buffer;
    final x = buffer.asByteData().getFloat32(0, Endian.little);
    final y = buffer.asByteData().getFloat32(4, Endian.little);
    final z = buffer.asByteData().getFloat32(8, Endian.little);
    
    return AccelerometerData(
      x: x,
      y: y,
      z: z,
      timestamp: DateTime.now(),
    );
  }

  /// Calculate magnitude of acceleration
  double get magnitude => math.sqrt(x * x + y * y + z * z);

  @override
  String toString() => 'Accel(x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, z: ${z.toStringAsFixed(2)})';
}

/// Model for gyroscope data
class GyroscopeData {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  GyroscopeData({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  /// Parse gyroscope data from BLE bytes
  static GyroscopeData fromBytes(Uint8List bytes) {
    final buffer = bytes.buffer;
    final x = buffer.asByteData().getFloat32(0, Endian.little);
    final y = buffer.asByteData().getFloat32(4, Endian.little);
    final z = buffer.asByteData().getFloat32(8, Endian.little);
    
    return GyroscopeData(
      x: x,
      y: y,
      z: z,
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() => 'Gyro(x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, z: ${z.toStringAsFixed(2)})';
}

/// Model for magnetometer data
class MagnetometerData {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  MagnetometerData({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  /// Parse magnetometer data from BLE bytes
  static MagnetometerData fromBytes(Uint8List bytes) {
    final buffer = bytes.buffer;
    final x = buffer.asByteData().getFloat32(0, Endian.little);
    final y = buffer.asByteData().getFloat32(4, Endian.little);
    final z = buffer.asByteData().getFloat32(8, Endian.little);
    
    return MagnetometerData(
      x: x,
      y: y,
      z: z,
      timestamp: DateTime.now(),
    );
  }

  /// Calculate magnitude of magnetic field
  double get magnitude => math.sqrt(x * x + y * y + z * z);

  @override
  String toString() => 'Mag(x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, z: ${z.toStringAsFixed(2)})';
}

/// Model for advanced metrics from firmware
class AdvancedMetrics {
  final double strokeLength;
  final double entryAngle;
  final double exitAngle;
  final double smoothness;
  final double rotationTorque;
  final double fatigueScore;
  final double asymmetryRatio; // 0-1, where 0.5 is balanced
  final int strokePhase; // 0-4: idle, catch, pull, exit, recovery
  final DateTime timestamp;

  AdvancedMetrics({
    required this.strokeLength,
    required this.entryAngle,
    required this.exitAngle,
    required this.smoothness,
    required this.rotationTorque,
    required this.fatigueScore,
    required this.asymmetryRatio,
    required this.strokePhase,
    required this.timestamp,
  });

  /// Parse advanced metrics from BLE bytes (32 bytes = 8 floats)
  static AdvancedMetrics fromBytes(Uint8List bytes) {
    final buffer = bytes.buffer;
    final byteData = buffer.asByteData();
    
    return AdvancedMetrics(
      strokeLength: byteData.getFloat32(0, Endian.little),
      entryAngle: byteData.getFloat32(4, Endian.little),
      exitAngle: byteData.getFloat32(8, Endian.little),
      smoothness: byteData.getFloat32(12, Endian.little),
      rotationTorque: byteData.getFloat32(16, Endian.little),
      fatigueScore: byteData.getFloat32(20, Endian.little),
      asymmetryRatio: byteData.getFloat32(24, Endian.little),
      strokePhase: byteData.getFloat32(28, Endian.little).toInt(),
      timestamp: DateTime.now(),
    );
  }

  factory AdvancedMetrics.empty() {
    return AdvancedMetrics(
      strokeLength: 0,
      entryAngle: 0,
      exitAngle: 0,
      smoothness: 0,
      rotationTorque: 0,
      fatigueScore: 0,
      asymmetryRatio: 0.5,
      strokePhase: 0,
      timestamp: DateTime.now(),
    );
  }

  String get phaseString {
    switch (strokePhase) {
      case 0: return 'Idle';
      case 1: return 'Catch';
      case 2: return 'Pull';
      case 3: return 'Exit';
      case 4: return 'Recovery';
      default: return 'Unknown';
    }
  }

  @override
  String toString() => 'Metrics(length: ${strokeLength.toStringAsFixed(1)}, angle: ${entryAngle.toStringAsFixed(1)}°→${exitAngle.toStringAsFixed(1)}°, smooth: ${smoothness.toStringAsFixed(2)})';
}

/// Model for temperature and humidity data
class TemperatureData {
  final double temperature; // Celsius
  final double humidity; // Percentage
  final DateTime timestamp;

  TemperatureData({
    required this.temperature,
    required this.humidity,
    required this.timestamp,
  });

  /// Parse temperature data from BLE bytes (8 bytes = 2 floats)
  static TemperatureData fromBytes(Uint8List bytes) {
    final buffer = bytes.buffer;
    final byteData = buffer.asByteData();
    
    return TemperatureData(
      temperature: byteData.getFloat32(0, Endian.little),
      humidity: byteData.getFloat32(4, Endian.little),
      timestamp: DateTime.now(),
    );
  }

  factory TemperatureData.empty() {
    return TemperatureData(
      temperature: 0,
      humidity: 0,
      timestamp: DateTime.now(),
    );
  }

  // Temperature safety threshold (can be adjusted based on climate/preference)
  static const double highTempThreshold = 35.0; // °C
  
  // Water detection threshold (can be adjusted for different conditions)
  static const double waterHumidityThreshold = 80.0; // %

  bool get isHighTemp => temperature > highTempThreshold;
  bool get isInWater => humidity > waterHumidityThreshold;

  @override
  String toString() => 'Temp(${temperature.toStringAsFixed(1)}°C, ${humidity.toStringAsFixed(1)}%)';
}

/// Model for ML-based stroke classifications
class MLClassifications {
  final double cleanStrokeScore; // 0-1: clean vs messy
  final double rotationQuality; // 0-1: proper vs over-rotation
  final double angleQuality; // 0-1: proper angle
  final double exitQuality; // 0-1: proper exit timing
  final DateTime timestamp;

  MLClassifications({
    required this.cleanStrokeScore,
    required this.rotationQuality,
    required this.angleQuality,
    required this.exitQuality,
    required this.timestamp,
  });

  /// Parse ML classifications from BLE bytes (16 bytes = 4 floats)
  static MLClassifications fromBytes(Uint8List bytes) {
    final buffer = bytes.buffer;
    final byteData = buffer.asByteData();
    
    return MLClassifications(
      cleanStrokeScore: byteData.getFloat32(0, Endian.little),
      rotationQuality: byteData.getFloat32(4, Endian.little),
      angleQuality: byteData.getFloat32(8, Endian.little),
      exitQuality: byteData.getFloat32(12, Endian.little),
      timestamp: DateTime.now(),
    );
  }

  factory MLClassifications.empty() {
    return MLClassifications(
      cleanStrokeScore: 0,
      rotationQuality: 0,
      angleQuality: 0,
      exitQuality: 0,
      timestamp: DateTime.now(),
    );
  }

  double get overallQuality => (cleanStrokeScore + rotationQuality + angleQuality + exitQuality) / 4.0;

  String get qualityDescription {
    if (overallQuality > 0.8) return 'Excellent';
    if (overallQuality > 0.6) return 'Good';
    if (overallQuality > 0.4) return 'Fair';
    return 'Needs Work';
  }

  @override
  String toString() => 'ML(clean: ${cleanStrokeScore.toStringAsFixed(2)}, rotation: ${rotationQuality.toStringAsFixed(2)}, angle: ${angleQuality.toStringAsFixed(2)}, exit: ${exitQuality.toStringAsFixed(2)})';
}

/// Model for 3D trajectory point
class TrajectoryPoint {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  TrajectoryPoint({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });
}

/// Model for paddle stroke statistics
class StrokeStatistics {
  final double strokeRate; // strokes per minute
  final double consistency; // 0-100%
  final int totalStrokes;
  final double averagePower;
  final DateTime lastUpdate;

  StrokeStatistics({
    required this.strokeRate,
    required this.consistency,
    required this.totalStrokes,
    required this.averagePower,
    required this.lastUpdate,
  });

  factory StrokeStatistics.empty() {
    return StrokeStatistics(
      strokeRate: 0,
      consistency: 0,
      totalStrokes: 0,
      averagePower: 0,
      lastUpdate: DateTime.now(),
    );
  }
}
