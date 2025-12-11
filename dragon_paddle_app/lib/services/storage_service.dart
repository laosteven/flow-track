import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Service for storing session data locally
/// Note: This is a simple in-memory implementation
/// For production, consider using shared_preferences, hive, or sqflite
class StorageService {
  final List<SessionData> _sessions = [];
  
  /// Save a training session
  void saveSession(SessionData session) {
    _sessions.add(session);
    if (kDebugMode) {
      print('Session saved: ${session.toJson()}');
    }
  }
  
  /// Get all stored sessions
  List<SessionData> getSessions() {
    return List.unmodifiable(_sessions);
  }
  
  /// Get sessions for a specific date
  List<SessionData> getSessionsByDate(DateTime date) {
    return _sessions.where((session) {
      return session.date.year == date.year &&
          session.date.month == date.month &&
          session.date.day == date.day;
    }).toList();
  }
  
  /// Clear all sessions
  void clearSessions() {
    _sessions.clear();
  }
  
  /// Get total strokes across all sessions
  int getTotalStrokes() {
    return _sessions.fold(0, (sum, session) => sum + session.totalStrokes);
  }
}

/// Model for a training session
class SessionData {
  final DateTime date;
  final Duration duration;
  final int totalStrokes;
  final double averageStrokeRate;
  final double averageConsistency;
  final double averagePower;
  
  SessionData({
    required this.date,
    required this.duration,
    required this.totalStrokes,
    required this.averageStrokeRate,
    required this.averageConsistency,
    required this.averagePower,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'duration': duration.inSeconds,
      'totalStrokes': totalStrokes,
      'averageStrokeRate': averageStrokeRate,
      'averageConsistency': averageConsistency,
      'averagePower': averagePower,
    };
  }
  
  factory SessionData.fromJson(Map<String, dynamic> json) {
    return SessionData(
      date: DateTime.parse(json['date']),
      duration: Duration(seconds: json['duration']),
      totalStrokes: json['totalStrokes'],
      averageStrokeRate: json['averageStrokeRate'],
      averageConsistency: json['averageConsistency'],
      averagePower: json['averagePower'],
    );
  }
  
  String toJsonString() => jsonEncode(toJson());
}
