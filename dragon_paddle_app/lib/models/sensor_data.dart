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
