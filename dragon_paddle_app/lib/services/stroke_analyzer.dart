import 'dart:collection';
import 'dart:math' as math;
import '../models/sensor_data.dart';

/// Service to analyze paddle strokes and calculate statistics
class StrokeAnalyzer {
  final Queue<AccelerometerData> _accelHistory = Queue();
  final Queue<double> _strokeTimestamps = Queue();
  
  static const int maxHistorySize = 500; // Keep last 10 seconds at 50Hz
  static const double strokeThreshold = 15.0; // Magnitude threshold for stroke detection
  static const int minStrokeDurationMs = 300; // Minimum time between strokes
  
  bool _isInStroke = false;
  DateTime? _lastStrokeTime;
  int _totalStrokes = 0;
  
  final Queue<double> _strokePowers = Queue();
  static const int maxStrokePowerHistory = 20;
  
  /// Process new accelerometer data
  void processAccelerometerData(AccelerometerData data) {
    _accelHistory.add(data);
    
    // Keep only recent history
    while (_accelHistory.length > maxHistorySize) {
      _accelHistory.removeFirst();
    }
    
    // Detect strokes based on acceleration magnitude
    _detectStroke(data);
  }
  
  /// Detect stroke based on acceleration threshold
  void _detectStroke(AccelerometerData data) {
    final magnitude = data.magnitude;
    final now = DateTime.now();
    
    // Check if magnitude exceeds threshold
    if (magnitude > strokeThreshold && !_isInStroke) {
      // Check minimum duration since last stroke
      if (_lastStrokeTime == null || 
          now.difference(_lastStrokeTime!).inMilliseconds > minStrokeDurationMs) {
        _isInStroke = true;
        _lastStrokeTime = now;
        _totalStrokes++;
        
        // Record stroke timestamp for rate calculation
        _strokeTimestamps.add(now.millisecondsSinceEpoch / 1000.0);
        while (_strokeTimestamps.length > 30) { // Keep last 30 strokes
          _strokeTimestamps.removeFirst();
        }
        
        // Record stroke power
        _strokePowers.add(magnitude);
        while (_strokePowers.length > maxStrokePowerHistory) {
          _strokePowers.removeFirst();
        }
      }
    } else if (magnitude < strokeThreshold * 0.5 && _isInStroke) {
      // Reset stroke detection when magnitude drops significantly
      _isInStroke = false;
    }
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
    
    final variance = powers.map((p) => (p - mean) * (p - mean)).reduce((a, b) => a + b) / powers.length;
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
  }
}
