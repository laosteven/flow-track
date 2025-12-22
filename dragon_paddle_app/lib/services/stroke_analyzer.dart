import 'dart:collection';
import 'dart:async';
import 'dart:math' as math;
import '../models/sensor_data.dart';

/// Service to analyze paddle strokes and calculate statistics
class StrokeAnalyzer {
  final Queue<AccelerometerData> _accelHistory = Queue();
  final Queue<double> _strokeTimestamps = Queue();
  final StreamController<Map<String, dynamic>> _strokeController =
      StreamController.broadcast();

  static const int maxHistorySize = 500; // Keep last 10 seconds at 50Hz
  static const double strokeThreshold =
      1.0; // Magnitude threshold for stroke detection
  static const int minStrokeDurationMs =
      350; // Increased refractory time to avoid double-counting
  static const double emaAlpha = 0.12; // Slightly slower EMA smoothing
  static const int dynamicWindow = 30; // larger window for more stable stats
  static const double dynamicK = 1.6; // higher multiplier => less sensitive
  static const double minThresholdFloor =
      0.8; // raised floor to reduce noise triggers

  // Distance tracking parameters
  static const double averageStrokeLength =
      2.5; // meters per stroke (configurable)

  bool _isInStroke = false;
  DateTime? _lastStrokeTime;
  DateTime? _sessionStartTime;
  DateTime? _lastDataTime;
  int _totalStrokes = 0;
  double _baselineEma = 0.0;

  final Queue<double> _strokePowers = Queue();
  static const int maxStrokePowerHistory = 20;
  final List<double> _recentAdjusted = List.filled(
    dynamicWindow,
    0.0,
    growable: false,
  );
  int _recentIndex = 0;
  int _recentCount = 0;

  /// Process new accelerometer data
  void processAccelerometerData(AccelerometerData data) {
    // Initialize session start time on first data point
    _sessionStartTime ??= data.timestamp;
    _lastDataTime = data.timestamp;
    // Compute magnitude and apply simple baseline removal using EMA
    final mag = data.magnitude;
    if (_baselineEma == 0.0) _baselineEma = mag;
    _baselineEma = emaAlpha * mag + (1 - emaAlpha) * _baselineEma;

    // Create a derived data point with baseline-removed magnitude in a new object
    final adjusted = AccelerometerData(
      x: data.x,
      y: data.y,
      z:
          data.z -
          _baselineEma, // note: we only need magnitude, but store adjusted z to keep structure
      timestamp: data.timestamp,
    );

    _accelHistory.add(adjusted);

    // Keep only recent history
    while (_accelHistory.length > maxHistorySize) {
      _accelHistory.removeFirst();
    }

    // Detect strokes based on adjusted magnitude
    // use signed adjusted magnitude and focus on positive peaks (forward stroke)
    final adjustedMagSigned = mag - _baselineEma;
    final adjustedMag = adjustedMagSigned > 0 ? adjustedMagSigned : 0.0;
    // store in recent buffer for dynamic stats
    _recentAdjusted[_recentIndex] = adjustedMag;
    _recentIndex = (_recentIndex + 1) % dynamicWindow;
    if (_recentCount < dynamicWindow) _recentCount++;

    // compute dynamic threshold (mean + k*std)
    double dynamicThreshold = strokeThreshold;
    if (_recentCount > 2) {
      final slice = _recentAdjusted.sublist(0, _recentCount);
      final mean = slice.reduce((a, b) => a + b) / slice.length;
      final variance =
          slice.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
          slice.length;
      final stdDev = math.sqrt(variance);
      dynamicThreshold = (mean + dynamicK * stdDev).clamp(
        minThresholdFloor,
        double.infinity,
      );
    }

    // derivative (rate of change) check
    double derivative = 0.0;
    if (_recentCount >= 2) {
      final prevIndex = (_recentIndex - 2) % dynamicWindow;
      final prev = _recentAdjusted[(prevIndex + dynamicWindow) % dynamicWindow];
      derivative = adjustedMag - prev;
    }

    // Trigger either by crossing dynamic threshold OR a strong derivative spike
    final bool triggerByThreshold = adjustedMag > dynamicThreshold;
    // derivative must be a positive spike and reasonably large relative to threshold
    final bool triggerByDerivative = derivative > (dynamicThreshold * 0.8);

    _detectStrokeWithMagnitude(
      adjustedMag,
      eventTime: data.timestamp,
      overrideTrigger: triggerByThreshold || triggerByDerivative,
    );
  }

  /// Detect stroke based on acceleration threshold
  void _detectStrokeWithMagnitude(
    double magnitude, {
    required DateTime eventTime,
    bool overrideTrigger = false,
  }) {
    final now = eventTime;

    // Simple hysteresis: enter stroke when above threshold, exit when below half threshold
    if ((magnitude > strokeThreshold || overrideTrigger) && !_isInStroke) {
      if (_lastStrokeTime == null ||
          now.difference(_lastStrokeTime!).inMilliseconds >
              minStrokeDurationMs) {
        _isInStroke = true;
        _lastStrokeTime = now;
        _totalStrokes++;

        _strokeTimestamps.add(now.millisecondsSinceEpoch / 1000.0);
        while (_strokeTimestamps.length > 30) {
          _strokeTimestamps.removeFirst();
        }
        // Record stroke power using the raw magnitude (before baseline removal)
        _strokePowers.add(magnitude);
        while (_strokePowers.length > maxStrokePowerHistory) {
          _strokePowers.removeFirst();
        }

        // Emit stroke event for listeners (timestamp in ISO, power)
        try {
          _strokeController.add({
            'timestamp': now.toIso8601String(),
            'power': magnitude,
          });
        } catch (_) {}
      }
    } else if (magnitude < strokeThreshold * 0.5 && _isInStroke) {
      _isInStroke = false;
    }
  }

  /// Stream of stroke events. Each event is a map with `timestamp` (ISO string) and `power` (double).
  Stream<Map<String, dynamic>> get onStroke => _strokeController.stream;

  void dispose() {
    _strokeController.close();
  }

  /// Calculate stroke rate (strokes per minute)
  double getStrokeRate() {
    if (_strokeTimestamps.length < 2) return 0.0;

    // Calculate rate from recent strokes
    final recentStrokes = _strokeTimestamps.length > 10
        ? _strokeTimestamps.toList().sublist(_strokeTimestamps.length - 10)
        : _strokeTimestamps.toList();

    if (recentStrokes.length < 2) return 0.0;

    final timeDiff = recentStrokes.last - recentStrokes.first;
    if (timeDiff == 0) return 0.0;

    final rate = (recentStrokes.length - 1) / timeDiff * 60.0;
    return rate;
  }

  /// Calculate stroke consistency (0-100%)
  double getConsistency() {
    if (_strokePowers.length < 3) return 100.0;

    // Calculate coefficient of variation
    final powers = _strokePowers.toList();
    final mean = powers.reduce((a, b) => a + b) / powers.length;

    if (mean == 0) return 100.0;

    final variance =
        powers.map((p) => (p - mean) * (p - mean)).reduce((a, b) => a + b) /
        powers.length;
    final stdDev = math.sqrt(variance);

    // Convert to consistency percentage (lower variation = higher consistency)
    final cv = stdDev / mean;
    final consistency = (1.0 - cv.clamp(0.0, 1.0)) * 100.0;

    return consistency.clamp(0.0, 100.0);
  }

  /// Get total stroke count
  int getTotalStrokes() => _totalStrokes;

  /// Get average stroke power
  double getAveragePower() {
    if (_strokePowers.isEmpty) return 0.0;
    return _strokePowers.reduce((a, b) => a + b) / _strokePowers.length;
  }

  /// Get total distance paddled in meters
  /// Estimated from stroke count * average stroke length
  double getDistance() {
    return _totalStrokes * averageStrokeLength;
  }

  /// Get current speed in meters per second
  /// Returns 0 if no recent strokes or session just started
  double getSpeed() {
    if (_totalStrokes < 2 || _sessionStartTime == null || _lastDataTime == null) return 0.0;

    final distance = getDistance();
    // Use actual data time span, not DateTime.now() (important for reviewing recorded sessions)
    final elapsed = _lastDataTime!.difference(_sessionStartTime!).inMilliseconds / 1000.0;

    if (elapsed <= 0) return 0.0;

    return distance / elapsed;
  }

  /// Get split time for 500 meters in minutes
  /// Returns 0 if speed is 0 or invalid
  double getSplit500m() {
    final speed = getSpeed();
    if (speed <= 0) return 0.0;

    // Time to cover 500m at current speed: 500m / speed(m/s) = seconds
    // Convert to minutes
    return (500.0 / speed) / 60.0;
  }

  /// Get recent acceleration history for graphing
  List<AccelerometerData> getRecentHistory({int count = 100}) {
    if (_accelHistory.length <= count) {
      return _accelHistory.toList();
    }
    return _accelHistory.toList().sublist(_accelHistory.length - count);
  }

  /// Reset statistics
  void reset() {
    _accelHistory.clear();
    _strokeTimestamps.clear();
    _strokePowers.clear();
    _totalStrokes = 0;
    _isInStroke = false;
    _lastStrokeTime = null;
    _sessionStartTime = null;
    _lastDataTime = null;
  }
}
